-- Accounts, the household's settings, sessions, and sign-in through other
-- providers such as Nextcloud. Included by db/build_schema.sql, with the app
-- role's name as the psql variable app_user.
--
-- The app role has no access to these tables. It calls the functions granted
-- to it below, which run as the owner role; every one that acts for a person
-- takes the SHA-256 of that person's session token. A refusal is raised with
-- SQLSTATE LM001 and a key as its message, such as last_admin; where a
-- constraint refuses, the key is the constraint's name.
--
-- A password reaches the database only as the backend's hash of it, together
-- with the salt and parameters the backend hashed it with, which the backend
-- reads back with password_salt() to hash a password typed at sign-in.


-- Tables -------------------------------------------------------------------

-- Whether P_USERNAME is a username: 1 to 50 lowercase letters, digits, dashes
-- and underscores.
CREATE FUNCTION _username_valid(p_username text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT p_username ~ '^[a-z0-9_-]{1,50}$'
$$;

CREATE TABLE accounts (
  account_id text PRIMARY KEY CHECK (account_id ~ '^[a-z0-9]{8}$'),
  username text NOT NULL
    CONSTRAINT username_taken UNIQUE
    CONSTRAINT username_invalid CHECK (_username_valid(username)),
  display_name text NOT NULL
    CONSTRAINT display_name_invalid CHECK (
      btrim(display_name) <> ''
      AND length(display_name) <= 100
      AND display_name !~ '[[:cntrl:]]'),
  password_salt text,
  password_hash bytea,
  role text NOT NULL DEFAULT 'member'
    CONSTRAINT role_invalid CHECK (role IN ('admin', 'member')),
  active boolean NOT NULL DEFAULT true,
  must_change_password boolean NOT NULL DEFAULT false,
  theme text NOT NULL DEFAULT 'device'
    CONSTRAINT theme_invalid CHECK (theme IN ('device', 'dark', 'light', 'dark-hc', 'light-hc')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT password_invalid CHECK (
    (password_salt IS NULL AND password_hash IS NULL)
    OR (password_salt <> '' AND length(password_hash) > 0)),
  CONSTRAINT password_change_without_password CHECK (
    password_hash IS NOT NULL OR NOT must_change_password)
);

CREATE TABLE providers (
  provider text PRIMARY KEY
);

CREATE TABLE identities (
  provider text NOT NULL CONSTRAINT provider_unknown REFERENCES providers,
  subject text NOT NULL CONSTRAINT subject_invalid CHECK (subject <> ''),
  account_id text NOT NULL REFERENCES accounts ON DELETE CASCADE,
  label text NOT NULL CONSTRAINT label_invalid CHECK (btrim(label) <> ''),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT identity_taken PRIMARY KEY (provider, subject),
  CONSTRAINT already_linked UNIQUE (account_id, provider)
);

CREATE TABLE settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  changed_by text REFERENCES accounts ON DELETE SET NULL,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  token_hash bytea PRIMARY KEY CONSTRAINT token_hash_invalid CHECK (length(token_hash) = 32),
  account_id text NOT NULL REFERENCES accounts ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  idle_timeout interval NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz
);
CREATE INDEX sessions_account_id ON sessions (account_id);


-- Helpers, not granted to the app role -------------------------------------

-- Raises the refusal P_KEY.
CREATE FUNCTION _refuse(p_key text) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  RAISE EXCEPTION USING ERRCODE = 'LM001', MESSAGE = p_key;
END
$$;

-- Refuses any change to an account's id, whoever makes it.
CREATE FUNCTION _account_id_fixed() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.account_id IS DISTINCT FROM OLD.account_id THEN
    PERFORM _refuse('account_id_fixed');
  END IF;
  RETURN NEW;
END
$$;
CREATE TRIGGER account_id_fixed BEFORE UPDATE OF account_id ON accounts
  FOR EACH ROW EXECUTE FUNCTION _account_id_fixed();

-- Returns a new account id: eight lowercase letters and digits, not in use.
CREATE FUNCTION _new_account_id() RETURNS text
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_id text;
BEGIN
  LOOP
    SELECT string_agg(substr('abcdefghijklmnopqrstuvwxyz0123456789', 1 + floor(random() * 36)::int, 1), '')
      INTO v_id FROM generate_series(1, 8);
    EXIT WHEN NOT EXISTS (SELECT 1 FROM accounts a WHERE a.account_id = v_id);
  END LOOP;
  RETURN v_id;
END
$$;

-- Returns the value of the setting P_KEY, refusing a key that was not seeded.
CREATE FUNCTION _setting(p_key text) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_value jsonb;
BEGIN
  SELECT s.value INTO v_value FROM settings s WHERE s.key = p_key;
  IF v_value IS NULL THEN
    PERFORM _refuse('setting_missing');
  END IF;
  RETURN v_value;
END
$$;

-- Whether a session can still be used: not revoked, and past neither its idle
-- timeout nor its expiry.
CREATE FUNCTION _live(p_session sessions) RETURNS boolean
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT p_session.revoked_at IS NULL
    AND now() < p_session.expires_at
    AND now() < p_session.last_used_at + p_session.idle_timeout
$$;

-- Starts a session for an account, after deleting its sessions that can no
-- longer be used.
CREATE FUNCTION _start_session(p_account_id text, p_token_hash bytea, p_idle interval, p_absolute interval)
RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF p_token_hash IS NULL OR length(p_token_hash) <> 32 THEN
    PERFORM _refuse('token_hash_invalid');
  END IF;
  IF p_idle IS NULL OR p_absolute IS NULL OR p_idle <= interval '0' OR p_absolute <= interval '0' THEN
    PERFORM _refuse('session_length_invalid');
  END IF;
  DELETE FROM sessions s WHERE s.account_id = p_account_id AND NOT _live(s);
  INSERT INTO sessions (token_hash, account_id, idle_timeout, expires_at)
    VALUES (p_token_hash, p_account_id, p_idle, now() + p_absolute);
END
$$;

-- Returns the account a session belongs to, refusing a session that cannot be
-- used, an account that is deactivated, and, unless P_PENDING_OK, an account
-- that must change its password first. Marks the session as used now.
CREATE FUNCTION _acting(p_token_hash bytea, p_pending_ok boolean) RETURNS accounts
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_session sessions;
  v_account accounts;
BEGIN
  SELECT * INTO v_session FROM sessions s WHERE s.token_hash = p_token_hash;
  IF NOT FOUND OR NOT _live(v_session) THEN
    PERFORM _refuse('session_invalid');
  END IF;
  SELECT * INTO v_account FROM accounts a WHERE a.account_id = v_session.account_id;
  IF NOT v_account.active THEN
    PERFORM _refuse('deactivated');
  END IF;
  IF v_account.must_change_password AND NOT p_pending_ok THEN
    PERFORM _refuse('password_change_required');
  END IF;
  UPDATE sessions s SET last_used_at = now() WHERE s.token_hash = p_token_hash;
  RETURN v_account;
END
$$;

-- As _acting, and refuses an account that is not an admin.
CREATE FUNCTION _acting_admin(p_token_hash bytea) RETURNS accounts
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  IF v_me.role <> 'admin' THEN
    PERFORM _refuse('not_admin');
  END IF;
  RETURN v_me;
END
$$;

-- Returns the account P_ACCOUNT_ID, refusing an id with no account.
CREATE FUNCTION _account(p_account_id text) RETURNS accounts
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  SELECT * INTO v_account FROM accounts a WHERE a.account_id = p_account_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_account');
  END IF;
  RETURN v_account;
END
$$;

-- Locks the rows of the active admins, and returns how many there are.
CREATE FUNCTION _active_admins_locked() RETURNS bigint
LANGUAGE sql SET search_path = public, pg_temp AS $$
  SELECT count(*) FROM (
    SELECT 1 FROM accounts a WHERE a.role = 'admin' AND a.active FOR UPDATE
  ) AS locked
$$;

-- Revokes every session of an account, except P_EXCEPT when it is given.
CREATE FUNCTION _revoke_sessions(p_account_id text, p_except bytea DEFAULT NULL) RETURNS integer
LANGUAGE sql SET search_path = public, pg_temp AS $$
  WITH revoked AS (
    UPDATE sessions s SET revoked_at = now()
    WHERE s.account_id = p_account_id AND s.revoked_at IS NULL
      AND (p_except IS NULL OR s.token_hash <> p_except)
    RETURNING 1
  )
  SELECT count(*)::integer FROM revoked
$$;

-- Refuses a password that is not given whole: its salt and its hash.
CREATE FUNCTION _password_given(p_salt text, p_hash bytea) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF p_salt IS NULL OR p_hash IS NULL THEN
    PERFORM _refuse('password_invalid');
  END IF;
END
$$;

-- Creates an account, the admin if it is the first. A sign-up (P_SIGN_UP) is
-- refused while self sign-up is closed. The username is checked first, since
-- the display name is the username when none is given.
CREATE FUNCTION _create_account(
  p_username text, p_display_name text, p_salt text, p_hash bytea,
  p_must_change boolean, p_sign_up boolean
) RETURNS accounts
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
  v_first boolean;
  v_constraint text;
  v_column text;
BEGIN
  IF NOT coalesce(_username_valid(p_username), false) THEN
    PERFORM _refuse('username_invalid');
  END IF;
  LOCK TABLE accounts IN SHARE ROW EXCLUSIVE MODE;
  IF p_sign_up AND NOT _setting('allow_auto_signup')::boolean THEN
    PERFORM _refuse('sign_up_closed');
  END IF;
  v_first := NOT EXISTS (SELECT 1 FROM accounts);
  INSERT INTO accounts (account_id, username, display_name, password_salt, password_hash,
                        role, must_change_password)
    VALUES (_new_account_id(), p_username,
            coalesce(nullif(btrim(p_display_name), ''), p_username),
            p_salt, p_hash, CASE WHEN v_first THEN 'admin' ELSE 'member' END, p_must_change)
    RETURNING * INTO v_account;
  RETURN v_account;
EXCEPTION
  WHEN unique_violation OR check_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM _refuse(v_constraint);
  WHEN not_null_violation THEN
    GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
    PERFORM _refuse(v_column || '_invalid');
END
$$;

-- Links an identity of a provider to an account.
CREATE FUNCTION _link(p_account_id text, p_provider text, p_subject text, p_label text) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
  v_column text;
BEGIN
  INSERT INTO identities (provider, subject, account_id, label)
    VALUES (p_provider, p_subject, p_account_id, p_label);
EXCEPTION
  WHEN unique_violation OR check_violation OR foreign_key_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM _refuse(v_constraint);
  WHEN not_null_violation THEN
    GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
    PERFORM _refuse(v_column || '_invalid');
END
$$;

-- Applies a change to the acting account's own row: P_COLUMN set to P_VALUE.
CREATE FUNCTION _set_own(p_account_id text, p_column text, p_value text) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
  v_column text;
BEGIN
  EXECUTE format('UPDATE accounts SET %I = $1 WHERE account_id = $2', p_column)
    USING p_value, p_account_id;
EXCEPTION
  WHEN unique_violation OR check_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM _refuse(v_constraint);
  WHEN not_null_violation THEN
    GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
    PERFORM _refuse(v_column || '_invalid');
END
$$;


-- Signing up and signing in, before there is a session ----------------------

-- Whether people may create their own accounts.
CREATE FUNCTION sign_up_open() RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT _setting('allow_auto_signup')::boolean
$$;
GRANT EXECUTE ON FUNCTION sign_up_open() TO :"app_user";

-- Creates an account with a password, and starts its first session. Returns
-- the account's id.
CREATE FUNCTION sign_up_password(
  p_username text, p_display_name text, p_password_salt text, p_password_hash bytea,
  p_token_hash bytea, p_idle interval, p_absolute interval
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  PERFORM _password_given(p_password_salt, p_password_hash);
  v_account := _create_account(p_username, p_display_name, p_password_salt, p_password_hash, false, true);
  PERFORM _start_session(v_account.account_id, p_token_hash, p_idle, p_absolute);
  RETURN v_account.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION sign_up_password(text, text, text, bytea, bytea, interval, interval) TO :"app_user";

-- Creates an account with no password, linked to an identity a provider has
-- verified, and starts its first session. Returns the account's id.
CREATE FUNCTION sign_up_identity(
  p_provider text, p_subject text, p_label text, p_username text, p_display_name text,
  p_token_hash bytea, p_idle interval, p_absolute interval
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  v_account := _create_account(p_username, p_display_name, NULL, NULL, false, true);
  PERFORM _link(v_account.account_id, p_provider, p_subject, p_label);
  PERFORM _start_session(v_account.account_id, p_token_hash, p_idle, p_absolute);
  RETURN v_account.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION sign_up_identity(text, text, text, text, text, bytea, interval, interval) TO :"app_user";

-- The salt and parameters an account's password was hashed with, or NULL when
-- there is no such account or it has no password.
CREATE FUNCTION password_salt(p_username text) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT a.password_salt FROM accounts a WHERE a.username = p_username
$$;
GRANT EXECUTE ON FUNCTION password_salt(text) TO :"app_user";

-- Signs in with a username and the hash of the password typed, and starts a
-- session. Returns the account's id.
CREATE FUNCTION sign_in_password(
  p_username text, p_password_hash bytea, p_token_hash bytea, p_idle interval, p_absolute interval
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  SELECT * INTO v_account FROM accounts a WHERE a.username = p_username;
  IF NOT FOUND OR v_account.password_hash IS NULL
     OR v_account.password_hash IS DISTINCT FROM p_password_hash THEN
    PERFORM _refuse('wrong_credentials');
  END IF;
  IF NOT v_account.active THEN
    PERFORM _refuse('deactivated');
  END IF;
  PERFORM _start_session(v_account.account_id, p_token_hash, p_idle, p_absolute);
  RETURN v_account.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION sign_in_password(text, bytea, bytea, interval, interval) TO :"app_user";

-- Signs in with an identity a provider has verified, and starts a session.
-- Keeps the identity's label up to date. Returns the account's id.
CREATE FUNCTION sign_in_identity(
  p_provider text, p_subject text, p_label text, p_token_hash bytea, p_idle interval, p_absolute interval
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  SELECT a.* INTO v_account FROM identities i JOIN accounts a USING (account_id)
    WHERE i.provider = p_provider AND i.subject = p_subject;
  IF NOT FOUND THEN
    PERFORM _refuse('no_account');
  END IF;
  IF NOT v_account.active THEN
    PERFORM _refuse('deactivated');
  END IF;
  UPDATE identities i SET last_used_at = now(), label = coalesce(nullif(btrim(p_label), ''), i.label)
    WHERE i.provider = p_provider AND i.subject = p_subject;
  PERFORM _start_session(v_account.account_id, p_token_hash, p_idle, p_absolute);
  RETURN v_account.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION sign_in_identity(text, text, text, bytea, interval, interval) TO :"app_user";


-- One's own session and account ----------------------------------------------

-- Checks a session and returns its account, including one that must change its
-- password first. Marks the session as used now.
CREATE FUNCTION session_check(p_token_hash bytea)
RETURNS TABLE (
  account_id text, username text, display_name text, role text, theme text,
  must_change_password boolean, has_password boolean, identities jsonb
)
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT a.account_id, a.username, a.display_name, a.role, a.theme, a.must_change_password,
         a.password_hash IS NOT NULL,
         coalesce((SELECT jsonb_object_agg(i.provider, i.label) FROM identities i
                   WHERE i.account_id = a.account_id), '{}'::jsonb)
  FROM _acting(p_token_hash, true) AS a
$$;
GRANT EXECUTE ON FUNCTION session_check(bytea) TO :"app_user";

-- Signs out: revokes this session.
CREATE FUNCTION sign_out(p_token_hash bytea) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  UPDATE sessions s SET revoked_at = now() WHERE s.token_hash = p_token_hash AND s.revoked_at IS NULL
$$;
GRANT EXECUTE ON FUNCTION sign_out(bytea) TO :"app_user";

-- Signs out everywhere else: revokes every other session of the account.
-- Returns how many were revoked.
CREATE FUNCTION sign_out_others(p_token_hash bytea) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, true);
  RETURN _revoke_sessions(v_me.account_id, p_token_hash);
END
$$;
GRANT EXECUTE ON FUNCTION sign_out_others(bytea) TO :"app_user";

-- Changes one's own username.
CREATE FUNCTION set_username(p_token_hash bytea, p_username text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _set_own(v_me.account_id, 'username', p_username);
END
$$;
GRANT EXECUTE ON FUNCTION set_username(bytea, text) TO :"app_user";

-- Changes one's own display name.
CREATE FUNCTION set_display_name(p_token_hash bytea, p_display_name text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _set_own(v_me.account_id, 'display_name', btrim(p_display_name));
END
$$;
GRANT EXECUTE ON FUNCTION set_display_name(bytea, text) TO :"app_user";

-- Changes one's own theme.
CREATE FUNCTION set_theme(p_token_hash bytea, p_theme text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _set_own(v_me.account_id, 'theme', p_theme);
END
$$;
GRANT EXECUTE ON FUNCTION set_theme(bytea, text) TO :"app_user";

-- Sets one's own password, and revokes one's other sessions. The current
-- password's hash must match, unless the account has no password yet or must
-- change the one it has.
CREATE FUNCTION set_password(
  p_token_hash bytea, p_current_hash bytea, p_password_salt text, p_password_hash bytea
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_constraint text;
BEGIN
  v_me := _acting(p_token_hash, true);
  IF v_me.password_hash IS NOT NULL AND NOT v_me.must_change_password
     AND v_me.password_hash IS DISTINCT FROM p_current_hash THEN
    PERFORM _refuse('current_password_wrong');
  END IF;
  PERFORM _password_given(p_password_salt, p_password_hash);
  BEGIN
    UPDATE accounts a
      SET password_salt = p_password_salt, password_hash = p_password_hash, must_change_password = false
      WHERE a.account_id = v_me.account_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;
  PERFORM _revoke_sessions(v_me.account_id, p_token_hash);
END
$$;
GRANT EXECUTE ON FUNCTION set_password(bytea, bytea, text, bytea) TO :"app_user";

-- Links one's account to an identity a provider has verified.
CREATE FUNCTION link_identity(p_token_hash bytea, p_provider text, p_subject text, p_label text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _link(v_me.account_id, p_provider, p_subject, p_label);
END
$$;
GRANT EXECUTE ON FUNCTION link_identity(bytea, text, text, text) TO :"app_user";

-- Unlinks one's account from a provider, refusing to remove the account's last
-- way to sign in.
CREATE FUNCTION unlink_identity(p_token_hash bytea, p_provider text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  IF NOT EXISTS (SELECT 1 FROM identities i WHERE i.account_id = v_me.account_id AND i.provider = p_provider) THEN
    PERFORM _refuse('not_linked');
  END IF;
  IF v_me.password_hash IS NULL
     AND (SELECT count(*) FROM identities i WHERE i.account_id = v_me.account_id) <= 1 THEN
    PERFORM _refuse('last_sign_in');
  END IF;
  DELETE FROM identities i WHERE i.account_id = v_me.account_id AND i.provider = p_provider;
END
$$;
GRANT EXECUTE ON FUNCTION unlink_identity(bytea, text) TO :"app_user";

-- Gives up one's own admin role, refusing the only active admin. No function
-- takes the admin role from anyone else.
CREATE FUNCTION give_up_admin(p_token_hash bytea) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting_admin(p_token_hash);
  IF _active_admins_locked() <= 1 THEN
    PERFORM _refuse('last_admin');
  END IF;
  UPDATE accounts a SET role = 'member' WHERE a.account_id = v_me.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION give_up_admin(bytea) TO :"app_user";

-- Deletes one's own account, with its sessions and identities, when P_USERNAME
-- is its username; refuses the only active admin. Returns the account's id, so
-- that the backend can remove its folder.
CREATE FUNCTION delete_own_account(p_token_hash bytea, p_username text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  IF p_username IS DISTINCT FROM v_me.username THEN
    PERFORM _refuse('confirmation_mismatch');
  END IF;
  IF v_me.role = 'admin' AND _active_admins_locked() <= 1 THEN
    PERFORM _refuse('last_admin');
  END IF;
  DELETE FROM accounts a WHERE a.account_id = v_me.account_id;
  RETURN v_me.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION delete_own_account(bytea, text) TO :"app_user";


-- Administration --------------------------------------------------------------

-- Every account, oldest first.
CREATE FUNCTION admin_accounts(p_token_hash bytea)
RETURNS TABLE (
  account_id text, username text, display_name text, role text, active boolean,
  must_change_password boolean, has_password boolean, identities jsonb, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  RETURN QUERY
    SELECT a.account_id, a.username, a.display_name, a.role, a.active, a.must_change_password,
           a.password_hash IS NOT NULL,
           coalesce((SELECT jsonb_object_agg(i.provider, i.label) FROM identities i
                     WHERE i.account_id = a.account_id), '{}'::jsonb),
           a.created_at
    FROM accounts a
    ORDER BY a.created_at, a.username;
END
$$;
GRANT EXECUTE ON FUNCTION admin_accounts(bytea) TO :"app_user";

-- Creates an account with a first password, which must be changed at the
-- first sign-in, whether or not self sign-up is open. Returns the account's id.
CREATE FUNCTION admin_create_account(
  p_token_hash bytea, p_username text, p_display_name text, p_password_salt text, p_password_hash bytea
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_account accounts;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _password_given(p_password_salt, p_password_hash);
  v_account := _create_account(p_username, p_display_name, p_password_salt, p_password_hash, true, false);
  RETURN v_account.account_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_create_account(bytea, text, text, text, bytea) TO :"app_user";

-- Sets a new password for an account, which must be changed at its next
-- sign-in, and revokes its sessions.
CREATE FUNCTION admin_reset_password(
  p_token_hash bytea, p_account_id text, p_password_salt text, p_password_hash bytea
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _account(p_account_id);
  PERFORM _password_given(p_password_salt, p_password_hash);
  BEGIN
    UPDATE accounts a
      SET password_salt = p_password_salt, password_hash = p_password_hash, must_change_password = true
      WHERE a.account_id = p_account_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;
  PERFORM _revoke_sessions(p_account_id);
END
$$;
GRANT EXECUTE ON FUNCTION admin_reset_password(bytea, text, text, bytea) TO :"app_user";

-- Makes an active account an admin.
CREATE FUNCTION admin_make_admin(p_token_hash bytea, p_account_id text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_target accounts;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  v_target := _account(p_account_id);
  IF NOT v_target.active THEN
    PERFORM _refuse('deactivated');
  END IF;
  UPDATE accounts a SET role = 'admin' WHERE a.account_id = p_account_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_make_admin(bytea, text) TO :"app_user";

-- Deactivates or reactivates another member's account. Deactivating revokes
-- its sessions. Refuses one's own account and an admin's.
CREATE FUNCTION admin_set_active(p_token_hash bytea, p_account_id text, p_active boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_target accounts;
BEGIN
  v_me := _acting_admin(p_token_hash);
  v_target := _account(p_account_id);
  IF v_target.account_id = v_me.account_id THEN
    PERFORM _refuse('not_self');
  END IF;
  IF v_target.role = 'admin' THEN
    PERFORM _refuse('admin_account');
  END IF;
  IF p_active IS NULL THEN
    PERFORM _refuse('active_invalid');
  END IF;
  UPDATE accounts a SET active = p_active WHERE a.account_id = p_account_id;
  IF NOT p_active THEN
    PERFORM _revoke_sessions(p_account_id);
  END IF;
END
$$;
GRANT EXECUTE ON FUNCTION admin_set_active(bytea, text, boolean) TO :"app_user";

-- Deletes another member's account, with its sessions and identities. Refuses
-- one's own account and an admin's. Returns the account's id, so that the
-- backend can remove its folder.
CREATE FUNCTION admin_delete_account(p_token_hash bytea, p_account_id text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_target accounts;
BEGIN
  v_me := _acting_admin(p_token_hash);
  v_target := _account(p_account_id);
  IF v_target.account_id = v_me.account_id THEN
    PERFORM _refuse('not_self');
  END IF;
  IF v_target.role = 'admin' THEN
    PERFORM _refuse('admin_account');
  END IF;
  DELETE FROM accounts a WHERE a.account_id = p_account_id;
  RETURN p_account_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_delete_account(bytea, text) TO :"app_user";

-- The household's settings, with who changed each last and when.
CREATE FUNCTION admin_settings(p_token_hash bytea)
RETURNS TABLE (key text, value jsonb, changed_by text, changed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  RETURN QUERY
    SELECT s.key, s.value, a.username, s.changed_at
    FROM settings s
    LEFT JOIN accounts a ON a.account_id = s.changed_by
    ORDER BY s.key;
END
$$;
GRANT EXECUTE ON FUNCTION admin_settings(bytea) TO :"app_user";

-- Changes a setting, recording who changed it. Refuses a key that was not
-- seeded, and a value of a different JSON type than the seeded one.
CREATE FUNCTION admin_set_setting(p_token_hash bytea, p_key text, p_value jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_old jsonb;
BEGIN
  v_me := _acting_admin(p_token_hash);
  SELECT s.value INTO v_old FROM settings s WHERE s.key = p_key FOR UPDATE;
  IF NOT FOUND THEN
    PERFORM _refuse('setting_unknown');
  END IF;
  IF p_value IS NULL OR jsonb_typeof(p_value) <> jsonb_typeof(v_old) THEN
    PERFORM _refuse('setting_invalid');
  END IF;
  UPDATE settings s SET value = p_value, changed_by = v_me.account_id, changed_at = now()
    WHERE s.key = p_key;
END
$$;
GRANT EXECUTE ON FUNCTION admin_set_setting(bytea, text, jsonb) TO :"app_user";
