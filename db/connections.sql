-- Connections to model servers, and the models each one serves. Included by
-- db/build_schema.sql after db/accounts.sql, whose helpers it uses, with the
-- app role's name as the psql variable app_user.
--
-- Connections belong to the household: only an admin changes them, and every
-- signed-in account uses their models. The scheduled refresh, which runs with
-- no session, checks them through the two refresh_ functions, the only ones
-- here that act for no one. A connection's key reaches the database
-- encrypted by the backend with connections.encryption_key, and leaves it only
-- for the backend to decrypt; it is never to be sent to a browser.
--
-- What a model can do and its context window are kept twice: as the server
-- reported them at the last check, and as the admin set them. A value the admin
-- set wins; NULL in both means unknown.


-- Tables -------------------------------------------------------------------

CREATE TABLE connections (
  connection_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL
    CONSTRAINT name_taken UNIQUE
    CONSTRAINT name_invalid CHECK (
      btrim(name) <> '' AND length(name) <= 100 AND name !~ '[[:cntrl:]]'),
  base_url text NOT NULL
    CONSTRAINT base_url_invalid CHECK (
      base_url ~ '^https?://[^[:space:]]+$' AND length(base_url) <= 2000),
  protocol text CONSTRAINT protocol_invalid CHECK (protocol IN ('openai', 'ollama')),
  detected_protocol text
    CONSTRAINT detected_protocol_invalid CHECK (detected_protocol IN ('openai', 'ollama')),
  api_key bytea CONSTRAINT api_key_invalid CHECK (length(api_key) > 0),
  checked_at timestamptz,
  check_error text CONSTRAINT check_error_invalid CHECK (check_error <> '' AND length(check_error) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE models (
  model_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  connection_id bigint NOT NULL REFERENCES connections ON DELETE CASCADE,
  name text NOT NULL CONSTRAINT model_name_invalid CHECK (name <> '' AND length(name) <= 1000),
  present boolean NOT NULL DEFAULT true,
  reported_chat boolean,
  reported_images boolean,
  reported_speech boolean,
  reported_context integer,
  set_chat boolean,
  set_images boolean,
  set_speech boolean,
  set_context integer,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT model_taken UNIQUE (connection_id, name),
  CONSTRAINT context_invalid CHECK (reported_context > 0 AND set_context > 0)
);


-- Helpers, not granted to the app role -------------------------------------

-- Refuses a connection id with no connection.
CREATE FUNCTION _connection_exists(p_connection_id bigint) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM connections c WHERE c.connection_id = p_connection_id) THEN
    PERFORM _refuse('no_such_connection');
  END IF;
END
$$;


-- Using the models -------------------------------------------------------------

-- The models the last checks found, on every connection, with what each can do
-- and its context window: the admin's value where set, the server's otherwise,
-- NULL where neither is known.
CREATE FUNCTION models(p_token_hash bytea)
RETURNS TABLE (
  model_id bigint, name text, connection_id bigint, connection_name text,
  chat boolean, images boolean, speech boolean, context integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting(p_token_hash, false);
  RETURN QUERY
    SELECT m.model_id, m.name, c.connection_id, c.name,
           coalesce(m.set_chat, m.reported_chat), coalesce(m.set_images, m.reported_images),
           coalesce(m.set_speech, m.reported_speech), coalesce(m.set_context, m.reported_context)
    FROM models m JOIN connections c ON c.connection_id = m.connection_id
    WHERE m.present
    ORDER BY c.name, m.name;
END
$$;
GRANT EXECUTE ON FUNCTION models(bytea) TO :"app_user";

-- What the backend needs to send a request to a model: its name on the server,
-- its connection's base URL and protocol, and the connection's key, still
-- encrypted. The protocol is the one the admin chose, or else the one
-- detected. Refuses a model the last check did not find, and one whose
-- protocol is not known yet.
CREATE FUNCTION model_access(p_token_hash bytea, p_model_id bigint)
RETURNS TABLE (model_name text, base_url text, protocol text, api_key bytea)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_model models;
  v_connection connections;
BEGIN
  PERFORM _acting(p_token_hash, false);
  SELECT * INTO v_model FROM models m WHERE m.model_id = p_model_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_model');
  END IF;
  IF NOT v_model.present THEN
    PERFORM _refuse('model_unavailable');
  END IF;
  SELECT * INTO v_connection FROM connections c WHERE c.connection_id = v_model.connection_id;
  IF coalesce(v_connection.protocol, v_connection.detected_protocol) IS NULL THEN
    PERFORM _refuse('protocol_unknown');
  END IF;
  RETURN QUERY
    SELECT v_model.name, v_connection.base_url,
           coalesce(v_connection.protocol, v_connection.detected_protocol), v_connection.api_key;
END
$$;
GRANT EXECUTE ON FUNCTION model_access(bytea, bigint) TO :"app_user";


-- Administration ------------------------------------------------------------------

-- Every connection, by name, with whether it has a key, the result of its last
-- check, and how many models that check found.
CREATE FUNCTION admin_connections(p_token_hash bytea)
RETURNS TABLE (
  connection_id bigint, name text, base_url text, protocol text, detected_protocol text,
  has_key boolean, checked_at timestamptz, check_error text, models_found bigint,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  RETURN QUERY
    SELECT c.connection_id, c.name, c.base_url, c.protocol, c.detected_protocol,
           c.api_key IS NOT NULL, c.checked_at, c.check_error,
           (SELECT count(*) FROM models m WHERE m.connection_id = c.connection_id AND m.present),
           c.created_at
    FROM connections c
    ORDER BY c.name;
END
$$;
GRANT EXECUTE ON FUNCTION admin_connections(bytea) TO :"app_user";

-- Every model of a connection that a check has found, now or before, by name,
-- with what the server reported and what the admin set.
CREATE FUNCTION admin_models(p_token_hash bytea, p_connection_id bigint)
RETURNS TABLE (
  model_id bigint, name text, present boolean,
  reported_chat boolean, reported_images boolean, reported_speech boolean, reported_context integer,
  set_chat boolean, set_images boolean, set_speech boolean, set_context integer,
  first_seen_at timestamptz, last_seen_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _connection_exists(p_connection_id);
  RETURN QUERY
    SELECT m.model_id, m.name, m.present,
           m.reported_chat, m.reported_images, m.reported_speech, m.reported_context,
           m.set_chat, m.set_images, m.set_speech, m.set_context,
           m.first_seen_at, m.last_seen_at
    FROM models m
    WHERE m.connection_id = p_connection_id
    ORDER BY m.name;
END
$$;
GRANT EXECUTE ON FUNCTION admin_models(bytea, bigint) TO :"app_user";

-- What the backend needs to check a connection: its base URL, the protocol the
-- admin chose and the one detected, and its key, still encrypted.
CREATE FUNCTION admin_connection_access(p_token_hash bytea, p_connection_id bigint)
RETURNS TABLE (base_url text, protocol text, detected_protocol text, api_key bytea)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _connection_exists(p_connection_id);
  RETURN QUERY
    SELECT c.base_url, c.protocol, c.detected_protocol, c.api_key
    FROM connections c
    WHERE c.connection_id = p_connection_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_connection_access(bytea, bigint) TO :"app_user";

-- Adds a connection. A protocol of NULL is detected at the check; a key of NULL
-- means the server takes none. Returns the connection's id.
CREATE FUNCTION admin_create_connection(
  p_token_hash bytea, p_name text, p_base_url text, p_protocol text, p_api_key bytea
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id bigint;
  v_constraint text;
  v_column text;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  BEGIN
    INSERT INTO connections (name, base_url, protocol, api_key)
      VALUES (btrim(p_name), p_base_url, p_protocol, p_api_key)
      RETURNING connection_id INTO v_id;
  EXCEPTION
    WHEN unique_violation OR check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
      PERFORM _refuse(v_column || '_invalid');
  END;
  RETURN v_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_create_connection(bytea, text, text, text, bytea) TO :"app_user";

-- Changes a connection's name, base URL and protocol. Its key is changed with
-- admin_set_connection_key.
CREATE FUNCTION admin_update_connection(
  p_token_hash bytea, p_connection_id bigint, p_name text, p_base_url text, p_protocol text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
  v_column text;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _connection_exists(p_connection_id);
  BEGIN
    UPDATE connections c
      SET name = btrim(p_name), base_url = p_base_url, protocol = p_protocol
      WHERE c.connection_id = p_connection_id;
  EXCEPTION
    WHEN unique_violation OR check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
      PERFORM _refuse(v_column || '_invalid');
  END;
END
$$;
GRANT EXECUTE ON FUNCTION admin_update_connection(bytea, bigint, text, text, text) TO :"app_user";

-- Replaces a connection's key, encrypted; NULL removes it.
CREATE FUNCTION admin_set_connection_key(p_token_hash bytea, p_connection_id bigint, p_api_key bytea)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _connection_exists(p_connection_id);
  BEGIN
    UPDATE connections c SET api_key = p_api_key WHERE c.connection_id = p_connection_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;
END
$$;
GRANT EXECUTE ON FUNCTION admin_set_connection_key(bytea, bigint, bytea) TO :"app_user";

-- Removes a connection and its models.
CREATE FUNCTION admin_delete_connection(p_token_hash bytea, p_connection_id bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _connection_exists(p_connection_id);
  DELETE FROM connections c WHERE c.connection_id = p_connection_id;
END
$$;
GRANT EXECUTE ON FUNCTION admin_delete_connection(bytea, bigint) TO :"app_user";

-- Records the result of checking a connection; a helper, not granted to the
-- app role. With P_ERROR NULL the check succeeded: P_DETECTED is the protocol
-- detected, NULL when none was, and P_MODELS is what the server reported, a
-- JSON array of objects with "name", and optionally "chat", "images" and
-- "speech", true or false, and "context", a number of tokens. The models in it
-- are marked found, with what was reported; the connection's other models are
-- marked not found, and keep what the admin set. With P_ERROR given, the check
-- failed, and only the error is recorded.
CREATE FUNCTION _record_check(
  p_connection_id bigint, p_detected text, p_error text, p_models jsonb
) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
BEGIN
  PERFORM _connection_exists(p_connection_id);
  BEGIN
    IF p_error IS NOT NULL THEN
      UPDATE connections c SET checked_at = now(), check_error = p_error
        WHERE c.connection_id = p_connection_id;
      RETURN;
    END IF;
    UPDATE connections c SET checked_at = now(), check_error = NULL, detected_protocol = p_detected
      WHERE c.connection_id = p_connection_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;

  IF p_models IS NULL OR jsonb_typeof(p_models) <> 'array'
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_models) e
                WHERE jsonb_typeof(e) <> 'object'
                   OR jsonb_typeof(e -> 'name') IS DISTINCT FROM 'string'
                   OR e ->> 'name' = '')
     OR (SELECT count(*) <> count(DISTINCT e ->> 'name') FROM jsonb_array_elements(p_models) e) THEN
    PERFORM _refuse('models_invalid');
  END IF;

  BEGIN
    INSERT INTO models AS m (connection_id, name, reported_chat, reported_images, reported_speech,
                             reported_context)
      SELECT p_connection_id, r.name, r.chat, r.images, r.speech, r.context
      FROM jsonb_to_recordset(p_models) AS r(name text, chat boolean, images boolean, speech boolean,
                                             context integer)
    ON CONFLICT ON CONSTRAINT model_taken DO UPDATE
      SET present = true, last_seen_at = now(),
          reported_chat = excluded.reported_chat, reported_images = excluded.reported_images,
          reported_speech = excluded.reported_speech, reported_context = excluded.reported_context;
  EXCEPTION
    WHEN invalid_text_representation OR numeric_value_out_of_range OR datatype_mismatch THEN
      PERFORM _refuse('models_invalid');
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;

  UPDATE models m SET present = false
    WHERE m.connection_id = p_connection_id AND m.present
      AND m.name NOT IN (SELECT e ->> 'name' FROM jsonb_array_elements(p_models) e);
END
$$;

-- Records the result of a check the admin ran, as _record_check does.
CREATE FUNCTION admin_record_check(
  p_token_hash bytea, p_connection_id bigint, p_detected text, p_error text, p_models jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _acting_admin(p_token_hash);
  PERFORM _record_check(p_connection_id, p_detected, p_error, p_models);
END
$$;
GRANT EXECUTE ON FUNCTION admin_record_check(bytea, bigint, text, text, jsonb) TO :"app_user";

-- Sets what a model can do and its context window, as the admin knows them.
-- NULL follows what the server reported.
CREATE FUNCTION admin_set_model(
  p_token_hash bytea, p_model_id bigint,
  p_chat boolean, p_images boolean, p_speech boolean, p_context integer
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
BEGIN
  PERFORM _acting_admin(p_token_hash);
  IF NOT EXISTS (SELECT 1 FROM models m WHERE m.model_id = p_model_id) THEN
    PERFORM _refuse('no_such_model');
  END IF;
  BEGIN
    UPDATE models m
      SET set_chat = p_chat, set_images = p_images, set_speech = p_speech, set_context = p_context
      WHERE m.model_id = p_model_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
  END;
END
$$;
GRANT EXECUTE ON FUNCTION admin_set_model(bytea, bigint, boolean, boolean, boolean, integer) TO :"app_user";


-- The scheduled refresh -----------------------------------------------------------------

-- Every connection, by id, with what the scheduled refresh needs to check it:
-- its base URL, the protocol the admin chose and the one detected, and its
-- key, still encrypted.
CREATE FUNCTION refresh_targets()
RETURNS TABLE (connection_id bigint, base_url text, protocol text, detected_protocol text, api_key bytea)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT c.connection_id, c.base_url, c.protocol, c.detected_protocol, c.api_key
  FROM connections c
  ORDER BY c.connection_id
$$;
GRANT EXECUTE ON FUNCTION refresh_targets() TO :"app_user";

-- Records the result of a check the scheduled refresh ran, as _record_check
-- does.
CREATE FUNCTION refresh_record_check(
  p_connection_id bigint, p_detected text, p_error text, p_models jsonb
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM _record_check(p_connection_id, p_detected, p_error, p_models);
END
$$;
GRANT EXECUTE ON FUNCTION refresh_record_check(bigint, text, text, jsonb) TO :"app_user";
