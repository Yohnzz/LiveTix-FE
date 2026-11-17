-- 20261117_add_concert_venue_coordinates.sql
-- Menyimpan lokasi venue hasil Google Maps (koordinat + Place ID) pada konser
-- produser, sekaligus merapatkan RLS concerts agar hanya pemilik konser
-- (atau admin) yang boleh insert/update.

-- 1. Kolom lokasi venue
ALTER TABLE public.concerts
  ADD COLUMN IF NOT EXISTS venue_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS venue_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS venue_place_id TEXT;

COMMENT ON COLUMN public.concerts.venue_latitude IS
  'Latitude venue dari Google Maps (-90 s/d 90).';
COMMENT ON COLUMN public.concerts.venue_longitude IS
  'Longitude venue dari Google Maps (-180 s/d 180).';
COMMENT ON COLUMN public.concerts.venue_place_id IS
  'Google Maps Place ID untuk venue (nullable; null bila pin manual/GPS).';

-- 2. Validasi rentang koordinat. Latitude & longitude harus terisi berpasangan
--    agar tidak ada titik setengah jadi.
ALTER TABLE public.concerts
  DROP CONSTRAINT IF EXISTS concerts_venue_coordinates_check;

ALTER TABLE public.concerts
  ADD CONSTRAINT concerts_venue_coordinates_check CHECK (
    (venue_latitude IS NULL AND venue_longitude IS NULL)
    OR (
      venue_latitude IS NOT NULL
      AND venue_longitude IS NOT NULL
      AND venue_latitude BETWEEN -90 AND 90
      AND venue_longitude BETWEEN -180 AND 180
      AND NOT (venue_latitude = 0 AND venue_longitude = 0)
    )
  );

-- 3. RLS: insert/update konser hanya oleh produser pemilik konser atau admin.
--    Policy lama mengizinkan semua user ber-role produser mengubah konser siapa
--    pun, jadi policy tersebut diganti (bukan sekadar ditambah).
DROP POLICY IF EXISTS "concerts_insert_policy" ON public.concerts;
CREATE POLICY "concerts_insert_policy"
  ON public.concerts FOR INSERT TO authenticated
  WITH CHECK (
    COALESCE(producer_id::text, '') = auth.uid()::text
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "concerts_update_policy" ON public.concerts;
CREATE POLICY "concerts_update_policy"
  ON public.concerts FOR UPDATE TO authenticated
  USING (
    COALESCE(producer_id::text, '') = auth.uid()::text
    OR public.is_admin()
  )
  WITH CHECK (
    COALESCE(producer_id::text, '') = auth.uid()::text
    OR public.is_admin()
  );
