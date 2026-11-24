DROP FUNCTION IF EXISTS public.calculate_promoter_balance(UUID);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(TEXT);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(VARCHAR);

CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(p_producer_id TEXT)
RETURNS TABLE (
    total_sales_gross BIGINT,
    total_producer_portion BIGINT,
    total_withdrawn BIGINT,
    available_balance BIGINT,
    held_balance BIGINT,
    has_pending_withdrawal BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_producer_gross BIGINT := 0;
    v_total_withdrawn BIGINT := 0;
    v_has_pending BOOLEAN := FALSE;
    v_held_balance BIGINT := 0;
    v_available_balance BIGINT := 0;
    v_producer_uuid UUID;
BEGIN
    -- Cast p_producer_id ke UUID jika format valid
    BEGIN
        v_producer_uuid := p_producer_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_producer_uuid := NULL;
    END;

    -- 1. Hitung total bagian produser dari ledger (tipe KREDIT)
    IF v_producer_uuid IS NOT NULL THEN
        SELECT COALESCE(SUM(jumlah), 0)
        INTO v_total_producer_gross
        FROM public.ledger
        WHERE UPPER(tipe) = 'KREDIT'
          AND wallet_owner_id = v_producer_uuid;
    END IF;

    -- Fallback ke orders jika di ledger belum ada
    IF v_total_producer_gross = 0 THEN
        SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
        INTO v_total_producer_gross
        FROM public.orders o
        JOIN public.concerts c ON c.id = o.concert_id
        WHERE (c.producer_id::TEXT = p_producer_id)
          AND o.payment_status = 'PAID';
    END IF;

    -- 2. Hitung total yang sudah ditarik (status completed)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_withdrawn
    FROM public.withdrawals
    WHERE (producer_id::TEXT = p_producer_id)
      AND status = 'completed';

    -- 3. Cek apakah ada penarikan yang sedang pending / processing
    SELECT EXISTS (
        SELECT 1 
        FROM public.withdrawals 
        WHERE (producer_id::TEXT = p_producer_id)
          AND status IN ('pending', 'processing')
    ) INTO v_has_pending;

    -- 4. Hitung saldo tersedia
    v_available_balance := v_total_producer_gross - v_total_withdrawn;
    IF v_available_balance < 0 THEN
        v_available_balance := 0;
    END IF;

    RETURN QUERY SELECT 
        v_total_producer_gross,
        v_total_producer_gross,
        v_total_withdrawn,
        v_available_balance,
        v_held_balance,
        v_has_pending;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO anon, authenticated, service_role;
