-- Helpers for the schema's tests, included by each test file that runs as the
-- owner role. They are made in pg_temp, so they last for the session.

-- Reports P_LABEL as passed when P_CONDITION is true, and raises otherwise.
CREATE FUNCTION pg_temp.ok(p_label text, p_condition boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_condition IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL  %', p_label;
  END IF;
  RAISE NOTICE 'ok    %', p_label;
END
$$;

-- Runs P_STATEMENT, and reports P_LABEL as passed when it is refused with the
-- key P_KEY; raises when it is refused with another key, or not at all.
CREATE FUNCTION pg_temp.refused(p_label text, p_statement text, p_key text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_statement;
  EXCEPTION
    WHEN SQLSTATE 'AI001' THEN
      IF SQLERRM = p_key THEN
        RAISE NOTICE 'ok    %', p_label;
        RETURN;
      END IF;
      RAISE EXCEPTION 'FAIL  % -- refused with %, not %', p_label, SQLERRM, p_key;
  END;
  RAISE EXCEPTION 'FAIL  % -- not refused; expected %', p_label, p_key;
END
$$;

-- The SHA-256 of a made-up session token named P_NAME.
CREATE FUNCTION pg_temp.t(p_name text) RETURNS bytea
LANGUAGE sql IMMUTABLE AS $$
  SELECT sha256(convert_to('token:' || p_name, 'UTF8'))
$$;

-- A made-up password hash named P_NAME.
CREATE FUNCTION pg_temp.pw(p_name text) RETURNS bytea
LANGUAGE sql IMMUTABLE AS $$
  SELECT sha256(convert_to('password:' || p_name, 'UTF8'))
$$;
