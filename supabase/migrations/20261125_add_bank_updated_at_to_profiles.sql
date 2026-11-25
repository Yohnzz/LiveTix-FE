-- ==============================================================================
-- ADD BANK_UPDATED_AT TO PROFILES
-- Untuk tracking cooldown 7 hari perubahan rekening bank Producer
-- ==============================================================================

ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS bank_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.bank_updated_at IS 'Waktu terakhir produser mengubah rekening bank tujuan (cooldown 7 hari)';
