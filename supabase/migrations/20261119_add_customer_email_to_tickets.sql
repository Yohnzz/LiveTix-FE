-- Tambahkan customer_email pada tabel tickets jika belum ada
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS customer_email TEXT;

NOTIFY pgrst, 'reload schema';
