-- Tests of what the app role may reach, as the app role. It may call the
-- functions granted to it and nothing else, and has no access to any table.

DO $$
BEGIN
  PERFORM sign_up_open();
  RAISE NOTICE 'ok    the app role calls a function granted to it';
END
$$;

DO $$
BEGIN
  PERFORM 1 FROM accounts;
  RAISE EXCEPTION 'FAIL  the app role read the accounts table';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'ok    the app role cannot read a table';
END
$$;

DO $$
BEGIN
  PERFORM _setting('allow_auto_signup');
  RAISE EXCEPTION 'FAIL  the app role called a helper';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'ok    the app role cannot call a helper';
END
$$;

DO $$
DECLARE
  v_expected text[] := ARRAY[
    'admin_accounts', 'admin_create_account', 'admin_delete_account', 'admin_make_admin',
    'admin_reset_password', 'admin_set_active', 'admin_set_setting', 'admin_settings',
    'delete_own_account', 'give_up_admin', 'link_identity', 'password_salt', 'session_check',
    'set_display_name', 'set_password', 'set_theme', 'set_username', 'sign_in_identity',
    'sign_in_password', 'sign_out', 'sign_out_others', 'sign_up_identity', 'sign_up_open',
    'sign_up_password', 'unlink_identity'];
  v_granted text[];
BEGIN
  SELECT coalesce(array_agg(p.proname::text), '{}') INTO v_granted
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace AND has_function_privilege(p.oid, 'EXECUTE');
  IF NOT (v_granted @> v_expected AND v_expected @> v_granted)
     OR cardinality(v_granted) <> cardinality(v_expected) THEN
    RAISE EXCEPTION 'FAIL  the app role may call: %', v_granted;
  END IF;
  RAISE NOTICE 'ok    the app role may call exactly the % functions granted to it', cardinality(v_granted);
END
$$;

DO $$
DECLARE
  v_reachable text[];
BEGIN
  SELECT array_agg(c.relname::text) INTO v_reachable
    FROM pg_class c
    WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'm', 'S', 'p')
      AND (has_table_privilege(c.oid, 'SELECT') OR has_table_privilege(c.oid, 'INSERT')
           OR has_table_privilege(c.oid, 'UPDATE') OR has_table_privilege(c.oid, 'DELETE')
           OR has_table_privilege(c.oid, 'TRUNCATE') OR has_table_privilege(c.oid, 'REFERENCES')
           OR has_table_privilege(c.oid, 'TRIGGER'));
  IF v_reachable IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL  the app role has privileges on: %', v_reachable;
  END IF;
  RAISE NOTICE 'ok    the app role has no privilege on any table';
END
$$;

DO $$
DECLARE
  v_public text[];
BEGIN
  SELECT array_agg(p.proname::text) INTO v_public
    FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    WHERE p.pronamespace = 'public'::regnamespace AND a.grantee = 0;
  IF v_public IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL  PUBLIC may call: %', v_public;
  END IF;
  RAISE NOTICE 'ok    PUBLIC may call no function';
END
$$;
