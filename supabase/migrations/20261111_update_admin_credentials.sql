-- ==============================================================================
-- MIGRATION: UBAH AKUN ADMIN SUPABASE
-- Dari    : asldkalkdaskd@gmail.com (password: igna@123)
-- Menjadi : admin1@gmail.com        (password: admin123)
-- ==============================================================================
-- Script bersifat idempotent dan aman dijalankan di Supabase SQL Editor / CLI.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_old_email TEXT := 'asldkalkdaskd@gmail.com';
  v_new_email TEXT := 'admin1@gmail.com';
  v_new_password TEXT := 'admin123';
  v_old_id UUID;
  v_new_id UUID;
  v_new_has_profile BOOLEAN := FALSE;
  v_target_id UUID;
  v_instance_id UUID;
  v_encrypted_pw TEXT;
  v_identity_exists BOOLEAN := FALSE;
  v_col TEXT;
BEGIN
  SET LOCAL search_path = public, auth, extensions;

  v_encrypted_pw := crypt(v_new_password, gen_salt('bf'));

  SELECT id INTO v_old_id
  FROM auth.users
  WHERE lower(trim(email)) = v_old_email
  LIMIT 1;

  SELECT id INTO v_new_id
  FROM auth.users
  WHERE lower(trim(email)) = v_new_email
  LIMIT 1;

  IF v_new_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_new_id
    ) INTO v_new_has_profile;
  END IF;

  SELECT COALESCE(
    (SELECT instance_id FROM auth.users LIMIT 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ) INTO v_instance_id;

  -- Bila akun baru sudah ada namun hanya sisa akun yatim tanpa baris profile dan akun lama masih ada,
  -- hapus sisa akun yatim agar UUID akun admin lama tetap terjaga saat diganti emailnya.
  IF v_old_id IS NOT NULL AND v_new_id IS NOT NULL AND v_old_id <> v_new_id AND NOT v_new_has_profile THEN
    DELETE FROM auth.identities WHERE user_id = v_new_id;
    DELETE FROM auth.users WHERE id = v_new_id;
    v_new_id := NULL;
  END IF;

  IF v_old_id IS NOT NULL AND v_new_id IS NULL THEN
    -- Ganti email & password akun lama secara langsung agar UUID & relasi tetap terjaga
    v_target_id := v_old_id;

    UPDATE auth.users
    SET
      email = v_new_email,
      encrypted_password = v_encrypted_pw,
      email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
      raw_app_meta_data = COALESCE(
        raw_app_meta_data,
        '{"provider":"email","providers":["email"]}'::jsonb
      ),
      raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
        'name', 'Admin LiveTix',
        'full_name', 'Admin LiveTix',
        'role', 'Admin',
        'email', v_new_email,
        'email_verified', true
      ),
      aud = COALESCE(NULLIF(aud, ''), 'authenticated'),
      role = COALESCE(NULLIF(role, ''), 'authenticated'),
      confirmation_token = '',
      recovery_token = '',
      email_change = '',
      email_change_token_new = '',
      updated_at = NOW()
    WHERE id = v_target_id;

  ELSIF v_old_id IS NOT NULL AND v_new_id IS NOT NULL THEN
    -- Jika kedua email sudah ada dan memiliki profil, pertahankan akun admin1@gmail.com lalu bersihkan akun lama
    v_target_id := v_new_id;

    UPDATE auth.users
    SET
      encrypted_password = v_encrypted_pw,
      email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
      raw_app_meta_data = COALESCE(
        raw_app_meta_data,
        '{"provider":"email","providers":["email"]}'::jsonb
      ),
      raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
        'name', 'Admin LiveTix',
        'full_name', 'Admin LiveTix',
        'role', 'Admin',
        'email', v_new_email,
        'email_verified', true
      ),
      confirmation_token = '',
      recovery_token = '',
      email_change = '',
      email_change_token_new = '',
      updated_at = NOW()
    WHERE id = v_target_id;

    IF v_old_id <> v_new_id THEN
      DELETE FROM auth.identities WHERE user_id = v_old_id;
      DELETE FROM public.profiles WHERE id = v_old_id;
      DELETE FROM auth.users WHERE id = v_old_id;
    END IF;

  ELSIF v_new_id IS NOT NULL THEN
    -- Akun baru sudah ada: sinkronkan password menjadi admin123 dan role Admin
    v_target_id := v_new_id;

    UPDATE auth.users
    SET
      encrypted_password = v_encrypted_pw,
      email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
      raw_app_meta_data = COALESCE(
        raw_app_meta_data,
        '{"provider":"email","providers":["email"]}'::jsonb
      ),
      raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
        'name', 'Admin LiveTix',
        'full_name', 'Admin LiveTix',
        'role', 'Admin',
        'email', v_new_email,
        'email_verified', true
      ),
      confirmation_token = '',
      recovery_token = '',
      email_change = '',
      email_change_token_new = '',
      updated_at = NOW()
    WHERE id = v_target_id;

  ELSE
    -- Jika belum ada akun lama maupun baru, buat akun Admin baru: admin1@gmail.com
    v_target_id := gen_random_uuid();

    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      v_instance_id,
      v_target_id,
      'authenticated',
      'authenticated',
      v_new_email,
      v_encrypted_pw,
      NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'name', 'Admin LiveTix',
        'full_name', 'Admin LiveTix',
        'role', 'Admin',
        'email', v_new_email,
        'email_verified', true
      ),
      NOW(),
      NOW(),
      '',
      '',
      '',
      ''
    );
  END IF;

  -- Sinkronkan auth.identities tanpa mengubah generated column email
  SELECT EXISTS (
    SELECT 1
    FROM auth.identities
    WHERE user_id = v_target_id
      AND provider = 'email'
  ) INTO v_identity_exists;

  IF v_identity_exists THEN
    UPDATE auth.identities
    SET
      provider_id = CASE
        WHEN lower(trim(provider_id)) = v_old_email THEN v_new_email
        ELSE provider_id
      END,
      identity_data = COALESCE(identity_data, '{}'::jsonb) || jsonb_build_object(
        'sub', v_target_id::text,
        'email', v_new_email,
        'email_verified', true,
        'phone_verified', false
      ),
      updated_at = NOW()
    WHERE user_id = v_target_id
      AND provider = 'email';
  ELSE
    INSERT INTO auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      v_target_id,
      jsonb_build_object(
        'sub', v_target_id::text,
        'email', v_new_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      v_target_id::text,
      NOW(),
      NOW(),
      NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;
  END IF;

  -- Bersihkan baris orphan di public.profiles yang masih memakai email lama
  DELETE FROM public.profiles
  WHERE id <> v_target_id
    AND lower(trim(COALESCE(email, ''))) = v_old_email;

  -- Sinkronkan baris public.profiles untuk admin1@gmail.com dengan role Admin
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (v_target_id, v_new_email, 'Admin LiveTix', 'Admin')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = 'Admin';

  -- Perbarui kolom opsional secara aman bila tersedia pada skema public.profiles
  FOREACH v_col IN ARRAY ARRAY[
    'full_name',
    'is_verified',
    'verification_status',
    'approval_status',
    'updated_at'
  ] LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'profiles'
        AND column_name = v_col
    ) THEN
      IF v_col = 'full_name' THEN
        EXECUTE 'UPDATE public.profiles SET full_name = ''Admin LiveTix'' WHERE id = $1' USING v_target_id;
      ELSIF v_col = 'is_verified' THEN
        EXECUTE 'UPDATE public.profiles SET is_verified = TRUE WHERE id = $1' USING v_target_id;
      ELSIF v_col = 'verification_status' THEN
        EXECUTE 'UPDATE public.profiles SET verification_status = ''approved'' WHERE id = $1' USING v_target_id;
      ELSIF v_col = 'approval_status' THEN
        EXECUTE 'UPDATE public.profiles SET approval_status = ''approved'' WHERE id = $1' USING v_target_id;
      ELSIF v_col = 'updated_at' THEN
        EXECUTE 'UPDATE public.profiles SET updated_at = NOW() WHERE id = $1' USING v_target_id;
      END IF;
    END IF;
  END LOOP;
END $$;

-- Perbarui helper public.is_admin() dengan fixed search_path agar mengakui admin1@gmail.com
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND lower(trim(role)) = 'admin'
  )
  OR lower(coalesce(auth.jwt() ->> 'email', '')) IN (
    'admin1@gmail.com',
    'admin@livetix.com',
    'admin@soundwave.com'
  );
$$;

-- Perbarui kebijakan RLS concerts & ticket_tiers bila menggunakan kebijakan awal 20261107
DO $$
BEGIN
  IF to_regclass('public.concerts') IS NOT NULL THEN
    DROP POLICY IF EXISTS "concerts_select_policy" ON public.concerts;
    CREATE POLICY "concerts_select_policy"
    ON public.concerts FOR SELECT TO public
    USING (
      status = 'published'
      OR (auth.uid() IS NOT NULL AND (
        producer_id = auth.uid()
        OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
      ))
    );

    DROP POLICY IF EXISTS "concerts_insert_policy" ON public.concerts;
    CREATE POLICY "concerts_insert_policy"
    ON public.concerts FOR INSERT TO authenticated
    WITH CHECK (
      producer_id = auth.uid()
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
    );

    DROP POLICY IF EXISTS "concerts_update_policy" ON public.concerts;
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

    DROP POLICY IF EXISTS "concerts_delete_policy" ON public.concerts;
    CREATE POLICY "concerts_delete_policy"
    ON public.concerts FOR DELETE TO authenticated
    USING (
      producer_id = auth.uid()
      OR lower(coalesce(auth.jwt() ->> 'email', '')) IN ('admin1@gmail.com', 'admin@livetix.com')
    );
  END IF;

  IF to_regclass('public.ticket_tiers') IS NOT NULL THEN
    DROP POLICY IF EXISTS "ticket_tiers_select_policy" ON public.ticket_tiers;
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

    DROP POLICY IF EXISTS "ticket_tiers_manage_policy" ON public.ticket_tiers;
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
  END IF;
END $$;
