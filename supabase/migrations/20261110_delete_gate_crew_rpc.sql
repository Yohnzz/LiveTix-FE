-- =================================================================================
-- RPC DELETE GATE CREW ACCOUNT BY ADMIN (SUPABASE)
-- Menghapus akun Gate Crew beserta penugasannya dari concert_gate_crews,
-- public.profiles, auth.identities, dan auth.users.
-- =================================================================================

CREATE OR REPLACE FUNCTION public.delete_gate_crew_account(
  p_user_id UUID DEFAULT NULL,
  p_email TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_clean_email TEXT := lower(trim(COALESCE(p_email, '')));
  v_target_id UUID := p_user_id;
BEGIN
  IF v_target_id IS NULL AND v_clean_email <> '' THEN
    SELECT id INTO v_target_id
    FROM public.profiles
    WHERE lower(email) = v_clean_email
      AND lower(trim(COALESCE(role, ''))) = 'gatecrew'
    LIMIT 1;
  END IF;

  IF v_target_id IS NOT NULL AND v_clean_email = '' THEN
    SELECT lower(email) INTO v_clean_email
    FROM public.profiles
    WHERE id = v_target_id
    LIMIT 1;
  END IF;

  -- Hapus penugasan konser terlebih dahulu
  DELETE FROM public.concert_gate_crews
  WHERE (v_target_id IS NOT NULL AND (crew_id = v_target_id OR crew_user_id = v_target_id))
     OR (v_clean_email <> '' AND lower(COALESCE(crew_email, '')) = v_clean_email);

  -- Hapus profil Gatecrew
  IF v_target_id IS NOT NULL THEN
    DELETE FROM public.profiles
    WHERE id = v_target_id
      AND lower(trim(COALESCE(role, 'gatecrew'))) = 'gatecrew';
  ELSIF v_clean_email <> '' THEN
    DELETE FROM public.profiles
    WHERE lower(email) = v_clean_email
      AND lower(trim(COALESCE(role, 'gatecrew'))) = 'gatecrew';
  END IF;

  -- Hapus identitas & akun auth Supabase jika ada
  IF v_target_id IS NOT NULL THEN
    DELETE FROM auth.identities WHERE user_id = v_target_id;
    DELETE FROM auth.users WHERE id = v_target_id;
  ELSIF v_clean_email <> '' THEN
    DELETE FROM auth.identities
    WHERE user_id IN (
      SELECT id FROM auth.users WHERE lower(email) = v_clean_email
    );
    DELETE FROM auth.users WHERE lower(email) = v_clean_email;
  END IF;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_gate_crew_account(UUID, TEXT) TO anon, authenticated;
