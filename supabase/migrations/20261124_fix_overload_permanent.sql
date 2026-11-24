-- Fix function overloading for calculate_promoter_balance
-- Drop ALL existing overloads of calculate_promoter_balance
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(UUID);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(TEXT);
DROP FUNCTION IF EXISTS public.calculate_promoter_balance(VARCHAR);

-- Recreate only ONE function accepting TEXT (which PostgREST can call unambiguously)
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
BEGIN
    -- 1. Hitung total bagian produser dari tabel ledger (entri KREDIT untuk produser)
    -- Producer ID disimpan di entity_id atau party_id
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_producer_gross
    FROM public.ledger
    WHERE entry_type = 'KREDIT'
      AND entity_id = p_producer_id;

    -- Jika di ledger belum ada, fallback ke kalkulasi langsung dari orders yang PAID
    IF v_total_producer_gross = 0 THEN
        SELECT COALESCE(SUM(COALESCE(o.bagian_produser, o.gross_amount)), 0)
        INTO v_total_producer_gross
        FROM public.orders o
        JOIN public.concerts c ON c.id = o.concert_id
        WHERE c.producer_id = p_producer_id
          AND o.payment_status = 'PAID';
    END IF;

    -- 2. Hitung total yang sudah berhasil dicairkan (WITHDRAWAL completed)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_withdrawn
    FROM public.withdrawals
    WHERE producer_id = p_producer_id
      AND status = 'completed';

    -- 3. Cek apakah ada permohonan penarikan yang masih pending / diproses
    SELECT EXISTS (
        SELECT 1 
        FROM public.withdrawals 
        WHERE producer_id = p_producer_id 
          AND status IN ('pending', 'processing')
    ) INTO v_has_pending;

    -- 4. Hitung saldo tersedia (Tersedia = Total Penjualan Bagian Produser - Total Penarikan)
    v_available_balance := v_total_producer_gross - v_total_withdrawn;
    IF v_available_balance < 0 THEN
        v_available_balance := 0;
    END IF;

    -- Kembalikan tabel 1 baris
    RETURN QUERY SELECT 
        v_total_producer_gross,
        v_total_producer_gross,
        v_total_withdrawn,
        v_available_balance,
        v_held_balance,
        v_has_pending;
END;
$$;

-- Grant permissions to anon and authenticated
GRANT EXECUTE ON FUNCTION public.calculate_promoter_balance(TEXT) TO anon, authenticated, service_role;
