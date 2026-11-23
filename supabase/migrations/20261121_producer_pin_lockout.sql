-- Migration: 20261121_producer_pin_lockout.sql
-- Tambahkan kolom pelacakan kegagalan PIN dan batas waktu penguncian pada profil Produser

ALTER TABLE public.promoter_profiles
  ADD COLUMN IF NOT EXISTS pin_failed_attempts INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMPTZ;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pin_failed_attempts INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMPTZ;
