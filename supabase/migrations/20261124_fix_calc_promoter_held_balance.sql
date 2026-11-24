DROP FUNCTION IF EXISTS public.calculate_promoter_balance(UUID);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(TEXT);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(VARCHAR);

CREATE OR REPLACE FUNCTION public.calculate_promoter_balance(p_producer_id TEXT)
RETURNS TABLE (
    total_sales_gross BIGINT,
    total_sales BIGINT,
    total_producer_portion BIGINT,
    total_withdrawn BIGINT,
    available_balance BIGINT,
    held_balance BIGINT,
    pending_balance BIGINT,
    has_pending_withdrawal BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available_gross BIGINT := 0;
    v_held_gross BIGINT := 0;
    v_total_sales BIGINT := 0;
    v_total_withdrawn BIGINT := 0;
    v_has_pending BOOLEAN := FALSE;
    v_available_balance BIGINT := 0;
BEGIN
    -- 1. Hitung saldo tersedia (Gross dari konser yang SUDAH DIMULAI / SELESAI)
    -- Syarat: COALESCE(starts_at, start_time) <= NOW() ATAU is_completed = true
    SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
    INTO v_available_gross
    FROM public.orders o
    JOIN public.concerts c ON c.id = o.concert_id
    WHERE (c.producer_id::TEXT = p_producer_id)
      AND o.payment_status = 'PAID'
      AND (COALESCE(c.starts_at, c.start_time) <= NOW() OR COALESCE(c.is_completed, false) = true);

    -- 2. Hitung saldo tertahan (Gross dari konser yang BELUM DIMULAI)
    -- Syarat: COALESCE(starts_at, start_time) > NOW() DAN is_completed = false/null
    SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
    INTO v_held_gross
    FROM public.orders o
    JOIN public.concerts c ON c.id = o.concert_id
    WHERE (c.producer_id::TEXT = p_producer_id)
      AND o.payment_status = 'PAID'
      AND (COALESCE(c.starts_at, c.start_time) > NOW() AND COALESCE(c.is_completed, false) = false);

    -- 3. Hitung total yang sudah ditarik oleh produser (status 'completed' atau 'SUCCESS')
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_withdrawn
    FROM public.withdrawals
    WHERE (producer_id::TEXT = p_producer_id)
      AND status IN ('completed', 'SUCCESS');

    -- 4. Cek apakah ada penarikan yang sedang pending / processing
    SELECT EXISTS (
        SELECT 1 
        FROM public.withdrawals 
        WHERE (producer_id::TEXT = p_producer_id)
          AND status IN ('pending', 'processing')
    ) INTO v_has_pending;

    -- 5. Hitung total sales dan net available balance
    v_total_sales := v_available_gross + v_held_gross;
    v_available_balance := v_available_gross - v_total_withdrawn;
    IF v_available_balance < 0 THEN
        v_available_balance := 0;
    END IF;

    RETURN QUERY SELECT 
        v_total_sales,
        v_total_sales,
        v_total_sales,
        v_total_withdrawn,
        v_available_balance,
        v_held_gross,
        v_held_gross,
        v_has_pending;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO anon, authenticated, service_role;
