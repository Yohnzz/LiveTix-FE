-- ============================================================
-- LIVE TIX: MASTER MIGRATION CONCERTS, TIERS, CAPACITY & APPROVAL
-- File: 20261107_create_concerts_approval_and_rls.sql
-- ============================================================

-- 0. Reset tabel lama jika sebelumnya terbuat dengan tipe id UUID
DROP TABLE IF EXISTS public.ticket_tiers CASCADE;
DROP TABLE IF EXISTS public.concerts CASCADE;

-- 1. Buat tabel public.concerts (id bertipe TEXT untuk mendukung ID seperti 'featured-1', 'c2', dll)
CREATE TABLE public.concerts (
  id TEXT PRIMARY KEY,
  producer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  producer_name TEXT DEFAULT 'Java Promotor',
  title TEXT NOT NULL,
  subtitle TEXT DEFAULT '',
  date TEXT NOT NULL,
  time TEXT DEFAULT '19:00 WIB',
  venue TEXT NOT NULL,
  venue_address TEXT DEFAULT '',
  price BIGINT NOT NULL DEFAULT 0,
  category TEXT NOT NULL DEFAULT 'Pop',
  tag TEXT DEFAULT 'Festival • 17+',
  description TEXT DEFAULT '',
  total_capacity INT DEFAULT 0,
  banner_image_url TEXT,
  logo_image_url TEXT,
  is_featured BOOLEAN DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'published',
  rejection_reason TEXT,
  cancellation_reason TEXT,
  cancellation_category TEXT,
  cancellation_date TEXT,
  cancellation_attachment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Buat tabel public.ticket_tiers
CREATE TABLE public.ticket_tiers (
  id TEXT PRIMARY KEY,
  concert_id TEXT NOT NULL REFERENCES public.concerts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  price BIGINT NOT NULL DEFAULT 0,
  quota INT DEFAULT 100,
  total_quota INT DEFAULT 100,
  quota_type TEXT DEFAULT 'Kursi',
  sold_count INT DEFAULT 0,
  is_sold_out BOOLEAN DEFAULT FALSE,
  accent_color BIGINT DEFAULT 4290906203,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Index Performa Pencarian & Filter
CREATE INDEX IF NOT EXISTS idx_concerts_status ON public.concerts (status);
CREATE INDEX IF NOT EXISTS idx_concerts_producer ON public.concerts (producer_id);
CREATE INDEX IF NOT EXISTS idx_ticket_tiers_concert ON public.ticket_tiers (concert_id);

-- 4. Row Level Security (RLS)
ALTER TABLE public.concerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_tiers ENABLE ROW LEVEL SECURITY;

-- 4.1 Kebijakan SELECT Konser: Publik membaca yang published, Produser membaca miliknya sendiri, Admin membaca semua
CREATE POLICY "concerts_select_policy"
ON public.concerts FOR SELECT TO public
USING (
  status = 'published'
  OR (auth.uid() IS NOT NULL AND (
    producer_id = auth.uid()
    OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
  ))
);

-- 4.2 Kebijakan INSERT Konser
CREATE POLICY "concerts_insert_policy"
ON public.concerts FOR INSERT TO authenticated
WITH CHECK (
  producer_id = auth.uid()
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
);

-- 4.3 Kebijakan UPDATE Konser
CREATE POLICY "concerts_update_policy"
ON public.concerts FOR UPDATE TO authenticated
USING (
  producer_id = auth.uid()
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
)
WITH CHECK (
  producer_id = auth.uid()
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
);

-- 4.4 Kebijakan DELETE Konser
CREATE POLICY "concerts_delete_policy"
ON public.concerts FOR DELETE TO authenticated
USING (
  producer_id = auth.uid()
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
);

-- 4.5 Kebijakan SELECT Ticket Tiers
CREATE POLICY "ticket_tiers_select_policy"
ON public.ticket_tiers FOR SELECT TO public
USING (
  EXISTS (
    SELECT 1 FROM public.concerts c
    WHERE c.id = ticket_tiers.concert_id
    AND (
      c.status = 'published'
      OR (auth.uid() IS NOT NULL AND (
        c.producer_id = auth.uid()
        OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
      ))
    )
  )
);

-- 4.6 Kebijakan MANAGE Ticket Tiers
CREATE POLICY "ticket_tiers_manage_policy"
ON public.ticket_tiers FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.concerts c
    WHERE c.id = ticket_tiers.concert_id
    AND (
      c.producer_id = auth.uid()
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.concerts c
    WHERE c.id = ticket_tiers.concert_id
    AND (
      c.producer_id = auth.uid()
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
    )
  )
);

-- 5. Seed Data Konser Awal LiveTix (status published)
INSERT INTO public.concerts (id, title, subtitle, date, time, venue, price, category, tag, is_featured, status, total_capacity)
VALUES
  ('featured-1', 'Soundwave Fest 2026', 'Panggung utama, 12 jam nonstop', 'Minggu, 12 Oktober 2026', 'Gerbang 17.00 · Mulai 19.00', 'Stadion Gajayana, Malang', 220000, 'Pop', 'Festival • 17+', TRUE, 'published', 5000),
  ('c2', 'Nadin Amizah', 'Konser Selamat Ulang Tahun & Rayuan Perempuan Gila', 'Selasa, 20 Oktober 2026', 'Gerbang 18.00 · Mulai 19.30', 'Sasana Krida, Malang', 175000, 'Pop', 'Konser Tunggal · Semua Umur', TRUE, 'published', 2500),
  ('c3', 'Feast Live Session', 'Tur Membangun & Menghancurkan Malang', 'Rabu, 28 Oktober 2026', 'Gerbang 17.30 · Mulai 19.00', 'Kayutangan, Malang', 180000, 'Rock', 'Rock Session · 17+', FALSE, 'published', 1500),
  ('c4', 'Hindia: Pulang Tour', 'Konser penutup album Menari Dengan Bayangan', 'Minggu, 15 November 2026', 'Gerbang 18.00 · Mulai 19.30', 'Britama Arena, Jakarta', 250000, 'Indie', 'Tur Solo · 17+', TRUE, 'published', 4000),
  ('c5', 'Reality Club Akustik', 'Sesi live intim dan bincang karya', 'Minggu, 22 November 2026', 'Gerbang 16.30 · Mulai 18.00', 'Amphitheater UB, Malang', 150000, 'Indie', 'Akustik · Semua Umur', FALSE, 'published', 800),
  ('c6', 'Sheila On 7 Reunion', 'Nostalgia lagu-lagu legendaris tanah air', 'Rabu, 2 Desember 2026', 'Gerbang 17.00 · Mulai 19.30', 'GOR Ken Arok, Malang', 200000, 'Pop', 'Reuni Akbar · 17+', TRUE, 'published', 6000),
  ('c7', 'Coldiac Sound of Surabaya', 'Konser penutup tur Jawa Timur', 'Rabu, 18 November 2026', 'Gerbang 18.00 · Mulai 19.30', 'Grand City Hall, Surabaya', 200000, 'Pop', 'Live Concert · 17+', FALSE, 'published', 2000),
  ('c8', 'The Changcuters Rock Party', 'Pesta dansa rock n roll Bandung', 'Sabtu, 5 Desember 2026', 'Gerbang 17.30 · Mulai 19.00', 'Sabuga, Bandung', 150000, 'Rock', 'Rock Party · 17+', FALSE, 'published', 2500),
  ('c9', 'We The Fest Surabaya Showcase', 'Electronic Music Festival 2026', 'Kamis, 10 Desember 2026', 'Gerbang 15.00 · Selesai 23.30', 'Jatim Expo, Surabaya', 350000, 'EDM', 'Electronic Dance · 18+', TRUE, 'published', 8000),
  ('c10', 'Gigs Kampus Malang Indie Night', 'Panggung komunitas band indie lokal Jawa Timur', 'Senin, 2 November 2026', 'Gerbang 18.30 · Mulai 19.30', 'Dome UMM, Malang', 45000, 'Indie', 'Showcase · Semua Umur', FALSE, 'published', 1200),
  ('c11', 'Senja Akustik Braga', 'Pertunjukan musik akustik sore hari', 'Sabtu, 14 November 2026', 'Gerbang 15.30 · Mulai 16.30', 'Taman Budaya, Bandung', 35000, 'Indie', 'Akustik Sore · 13+', FALSE, 'published', 600)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  subtitle = EXCLUDED.subtitle,
  date = EXCLUDED.date,
  time = EXCLUDED.time,
  venue = EXCLUDED.venue,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  tag = EXCLUDED.tag,
  is_featured = EXCLUDED.is_featured,
  status = EXCLUDED.status,
  total_capacity = EXCLUDED.total_capacity;

-- 6. Seed Data Kategori Tiket (Ticket Tiers)
INSERT INTO public.ticket_tiers (id, concert_id, name, description, price, quota, total_quota, is_sold_out)
VALUES
  ('c1-vip', 'featured-1', 'VIP Lounge', 'Tempat duduk VIP eksklusif depan panggung', 750000, 250, 250, FALSE),
  ('c1-fest', 'featured-1', 'Festival', 'Area berdiri di depan panggung', 350000, 2000, 2000, FALSE),
  ('c1-tribun-a', 'featured-1', 'Tribun A', 'Tempat duduk bernomor sisi barat', 220000, 1375, 1375, FALSE),
  ('c1-tribun-b', 'featured-1', 'Tribun B', 'Tempat duduk bernomor sisi timur', 220000, 1375, 1375, FALSE),
  ('n-vip', 'c2', 'VIP Lounge', 'Akses baris terdepan & merchandise eksklusif', 500000, 300, 300, FALSE),
  ('n1', 'c2', 'Festival A', 'Berdiri depan panggung', 250000, 1200, 1200, FALSE),
  ('n2', 'c2', 'Tribun', 'Tempat duduk bebas', 175000, 1000, 1000, FALSE),
  ('f-pit', 'c3', 'Moshpit VIP', 'Akses lingkar panggung utama', 320000, 500, 500, FALSE),
  ('f1', 'c3', 'General Admission', 'Akses seluruh arena', 180000, 1000, 1000, FALSE),
  ('h-vip', 'c4', 'VIP Lounge', 'Kursi VIP bernomor & Meet & Greet', 650000, 400, 400, FALSE),
  ('h-fest', 'c4', 'Festival', 'Area festival berdiri', 350000, 2000, 2000, FALSE),
  ('h-tribun', 'c4', 'Tribun', 'Tribun atas bernomor', 250000, 1600, 1600, FALSE),
  ('rc-vip', 'c5', 'VIP Front Row', 'Duduk baris depan & signed CD', 300000, 200, 200, FALSE),
  ('rc-gen', 'c5', 'General', 'Tempat duduk bebas amphitheater', 150000, 600, 600, FALSE),
  ('so7-vip', 'c6', 'VIP Lounge', 'Kategori VIP tengah panggung', 600000, 800, 800, FALSE),
  ('so7-fest', 'c6', 'Festival', 'Festival berdiri tengah', 275000, 3000, 3000, FALSE),
  ('so7-ta', 'c6', 'Tribun A', 'Tribun barat bernomor', 200000, 1100, 1100, FALSE),
  ('so7-tb', 'c6', 'Tribun B', 'Tribun timur bernomor', 200000, 1100, 1100, FALSE),
  ('cold-vip', 'c7', 'VIP Lounge', 'Akses VIP lounge & seating', 450000, 400, 400, FALSE),
  ('cold-fest', 'c7', 'Festival', 'Area berdiri depan panggung', 200000, 1600, 1600, FALSE),
  ('tc-pit', 'c8', 'Rock Pit', 'Depan panggung dansa', 220000, 700, 700, FALSE),
  ('tc-tribun', 'c8', 'Tribun', 'Tempat duduk santai', 150000, 1800, 1800, FALSE),
  ('wtf-vip', 'c9', 'VIP Lounge', 'VIP deck khusus & free welcome drink', 850000, 1500, 1500, FALSE),
  ('wtf-ga', 'c9', 'General Admission', 'Akses seluruh arena festival', 350000, 6500, 6500, FALSE),
  ('indie-vip', 'c10', 'Front Stage', 'Area berdiri dekat panggung', 75000, 300, 300, FALSE),
  ('indie-reg', 'c10', 'Reguler', 'Tiket masuk reguler komunitas', 45000, 900, 900, FALSE),
  ('senja-vip', 'c11', 'VIP Seating', 'Kursi santai baris depan panggung', 65000, 150, 150, FALSE),
  ('senja-reg', 'c11', 'General Lawn', 'Area rumput terbuka bebas', 35000, 450, 450, FALSE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  quota = EXCLUDED.quota,
  total_quota = EXCLUDED.total_quota,
  is_sold_out = EXCLUDED.is_sold_out;
