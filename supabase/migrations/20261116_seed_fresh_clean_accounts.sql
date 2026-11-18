-- ==============================================================================
-- SEED AKUN ADMIN LIVETIX (STANDAR SUPABASE GOTRUE)
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_admin_id UUID := 'a0000000-0000-0000-0000-000000000001';
  v_admin_email TEXT := 'admin1@gmail.com';
  v_admin_password TEXT := 'admin123';
  v_instance_id UUID;
  v_enc_pw TEXT;
  v_col TEXT;
BEGIN
  SET LOCAL search_path = public, auth, extensions;

  v_enc_pw := extensions.crypt(v_admin_password, extensions.gen_salt('bf'));

  SELECT COALESCE(
    (SELECT instance_id FROM auth.users LIMIT 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ) INTO v_instance_id;

  -- 1. Buat / Perbarui akun Admin di auth.users
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    aud,
    role,
    created_at,
    updated_at
  ) VALUES (
    v_admin_id,
    v_instance_id,
    v_admin_email,
    v_enc_pw,
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'name', 'Admin LiveTix',
      'full_name', 'Admin LiveTix',
      'role', 'Admin',
      'email', v_admin_email,
      'email_verified', true
    ),
    'authenticated',
    'authenticated',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    encrypted_password = EXCLUDED.encrypted_password,
    raw_app_meta_data = EXCLUDED.raw_app_meta_data,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, NOW()),
    updated_at = NOW();

  -- 2. Bersihkan NULL di kolom token auth.users (mencegah GoTrue schema error)
  FOREACH v_col IN ARRAY ARRAY[
    'confirmation_token',
    'recovery_token',
    'email_change',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change',
    'phone_change_token',
    'reauthentication_token'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = v_col
    ) THEN
      EXECUTE format('UPDATE auth.users SET %I = '''' WHERE %I IS NULL', v_col, v_col);
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'is_sso_user'
  ) THEN
    EXECUTE 'UPDATE auth.users SET is_sso_user = FALSE WHERE is_sso_user IS NULL';
  END IF;

  -- 3. Tambahkan ke auth.identities agar GoTrue mengenali login email/password
  IF EXISTS (
    SELECT 1 FROM auth.identities
    WHERE user_id = v_admin_id AND provider = 'email'
  ) THEN
    UPDATE auth.identities
    SET
      identity_data = jsonb_build_object(
        'sub', v_admin_id::text,
        'email', v_admin_email,
        'email_verified', true,
        'phone_verified', false
      ),
      updated_at = NOW()
    WHERE user_id = v_admin_id AND provider = 'email';
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
      v_admin_id,
      jsonb_build_object(
        'sub', v_admin_id::text,
        'email', v_admin_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      v_admin_id::text,
      NOW(),
      NOW(),
      NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;
  END IF;

  -- 4. Buat atau perbarui profil Admin di public.profiles
  INSERT INTO public.profiles (
    id,
    email,
    name,
    full_name,
    role,
    is_verified,
    verification_status,
    approval_status,
    created_at,
    updated_at
  ) VALUES (
    v_admin_id,
    v_admin_email,
    'Admin LiveTix',
    'Admin LiveTix',
    'Admin',
    TRUE,
    'approved',
    'approved',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = 'Admin',
    is_verified = TRUE,
    verification_status = 'approved',
    approval_status = 'approved',
    updated_at = NOW();

  RAISE NOTICE 'Akun Admin LiveTix (admin1@gmail.com / admin123) berhasil dibuat!';

END $$;
