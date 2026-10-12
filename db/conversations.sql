-- Conversations, their messages, and each person's files. Included by
-- db/build_schema.sql after db/connections.sql, whose tables it refers to, with
-- the app role's name as the psql variable app_user.
--
-- Everything here belongs to one account and is reached only through that
-- account's session: no function shows one person's conversations or files to
-- anyone else, the admin included. Deleting an account deletes its
-- conversations, their messages and the records of its files.
--
-- A conversation's messages form a tree. A user message follows a reply, or
-- nothing when it opens the conversation; a reply follows a user message.
-- Regenerating a reply adds another reply to the same user message, and editing
-- a message adds another user message in the same place, so earlier versions
-- stay. The conversation shows one path, from its first message to its leaf:
-- the newest message added, or the newest below the version the person chose.
-- A reply keeps the names of its model and connection, so that it still says
-- who wrote it after the model is gone.
--
-- A file lives on disk at <storage.root_path>/<account id>/<path>. The database
-- keeps its record, with a path that cannot leave the account's folder.


-- Tables -------------------------------------------------------------------

CREATE TABLE files (
  file_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts ON DELETE CASCADE,
  kind text NOT NULL CONSTRAINT kind_invalid CHECK (kind IN ('image', 'audio', 'transcript', 'export')),
  path text NOT NULL CONSTRAINT path_invalid CHECK (
    path ~ '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$'
    AND path !~ '(^|/)\.{1,2}(/|$)'
    AND length(path) <= 1000),
  name text NOT NULL CONSTRAINT name_invalid CHECK (
    btrim(name) <> '' AND length(name) <= 255 AND name !~ '[[:cntrl:]]'),
  size bigint NOT NULL CONSTRAINT size_invalid CHECK (size >= 0),
  mime_type text NOT NULL CONSTRAINT mime_type_invalid CHECK (
    mime_type ~ '^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$' AND length(mime_type) <= 255),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT path_taken UNIQUE (account_id, path)
);

CREATE TABLE conversations (
  conversation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts ON DELETE CASCADE,
  title text NOT NULL DEFAULT ''
    CONSTRAINT title_invalid CHECK (length(title) <= 200 AND title !~ '[[:cntrl:]]'),
  model_id bigint REFERENCES models ON DELETE SET NULL,
  system_prompt text NOT NULL DEFAULT '',
  output_limit integer CONSTRAINT output_limit_invalid CHECK (output_limit > 0),
  leaf_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX conversations_account_id ON conversations (account_id, updated_at DESC);

CREATE TABLE messages (
  message_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id bigint NOT NULL REFERENCES conversations ON DELETE CASCADE,
  parent_id bigint,
  role text NOT NULL CONSTRAINT role_invalid CHECK (role IN ('user', 'assistant')),
  content text NOT NULL DEFAULT '',
  reasoning text,
  model_id bigint REFERENCES models ON DELETE SET NULL,
  model_name text,
  connection_name text,
  prompt_tokens integer,
  completion_tokens integer,
  state text NOT NULL DEFAULT 'complete'
    CONSTRAINT state_invalid CHECK (state IN ('complete', 'stopped', 'failed')),
  error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT message_in_conversation UNIQUE (conversation_id, message_id),
  CONSTRAINT parent_invalid FOREIGN KEY (conversation_id, parent_id)
    REFERENCES messages (conversation_id, message_id) ON DELETE CASCADE,
  CONSTRAINT tokens_invalid CHECK (prompt_tokens >= 0 AND completion_tokens >= 0),
  CONSTRAINT error_invalid CHECK ((state = 'failed') = (error IS NOT NULL) AND error <> ''),
  CONSTRAINT model_name_invalid CHECK (
    (role = 'user' AND model_name IS NULL)
    OR (role = 'assistant' AND model_name IS NOT NULL AND model_name <> '')),
  CONSTRAINT user_message_invalid CHECK (
    role = 'assistant'
    OR (model_id IS NULL AND connection_name IS NULL AND reasoning IS NULL AND state = 'complete'
        AND prompt_tokens IS NULL AND completion_tokens IS NULL))
);
CREATE INDEX messages_parent ON messages (conversation_id, parent_id);

ALTER TABLE conversations ADD CONSTRAINT leaf_invalid FOREIGN KEY (conversation_id, leaf_id)
  REFERENCES messages (conversation_id, message_id) ON DELETE SET NULL (leaf_id);

CREATE TABLE message_files (
  message_id bigint NOT NULL REFERENCES messages ON DELETE CASCADE,
  file_id bigint NOT NULL REFERENCES files ON DELETE CASCADE,
  position integer NOT NULL,
  PRIMARY KEY (message_id, file_id)
);
CREATE INDEX message_files_file_id ON message_files (file_id);


-- Helpers, not granted to the app role -------------------------------------

-- Returns the conversation P_CONVERSATION_ID of the account P_ACCOUNT_ID,
-- refusing one that does not exist or is someone else's alike.
CREATE FUNCTION _own_conversation(p_account_id text, p_conversation_id bigint) RETURNS conversations
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_conversation conversations;
BEGIN
  SELECT * INTO v_conversation FROM conversations c
    WHERE c.conversation_id = p_conversation_id AND c.account_id = p_account_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_conversation');
  END IF;
  RETURN v_conversation;
END
$$;

-- Returns the file P_FILE_ID of the account P_ACCOUNT_ID, refusing one that
-- does not exist or is someone else's alike.
CREATE FUNCTION _own_file(p_account_id text, p_file_id bigint) RETURNS files
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_file files;
BEGIN
  SELECT * INTO v_file FROM files f WHERE f.file_id = p_file_id AND f.account_id = p_account_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_file');
  END IF;
  RETURN v_file;
END
$$;

-- Refuses a model id with no model, and a model the last check did not find.
-- NULL passes: no model chosen.
CREATE FUNCTION _usable_model(p_model_id bigint) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_present boolean;
BEGIN
  IF p_model_id IS NULL THEN
    RETURN;
  END IF;
  SELECT m.present INTO v_present FROM models m WHERE m.model_id = p_model_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_model');
  END IF;
  IF NOT v_present THEN
    PERFORM _refuse('model_unavailable');
  END IF;
END
$$;

-- Applies a change to a conversation: P_COLUMN set to P_VALUE, and the
-- conversation marked as changed now.
CREATE FUNCTION _set_conversation(p_conversation_id bigint, p_column text, p_value text) RETURNS void
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_constraint text;
  v_column text;
BEGIN
  EXECUTE format('UPDATE conversations SET %I = $1, updated_at = now() WHERE conversation_id = $2', p_column)
    USING p_value, p_conversation_id;
EXCEPTION
  WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
    PERFORM _refuse(v_constraint);
  WHEN not_null_violation THEN
    GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
    PERFORM _refuse(v_column || '_invalid');
END
$$;

-- Adds a message to a conversation, attaches P_FILE_IDS to it in their order,
-- and makes it the conversation's leaf. Returns the message's id.
CREATE FUNCTION _add_message(
  p_conversation_id bigint, p_parent_id bigint, p_role text, p_content text, p_reasoning text,
  p_model_id bigint, p_model_name text, p_connection_name text,
  p_prompt_tokens integer, p_completion_tokens integer, p_state text, p_error text,
  p_file_ids bigint[]
) RETURNS bigint
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_id bigint;
  v_constraint text;
  v_column text;
BEGIN
  IF p_parent_id IS NULL AND p_role = 'assistant'
     OR p_parent_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM messages m
       WHERE m.message_id = p_parent_id AND m.conversation_id = p_conversation_id
         AND m.role = CASE p_role WHEN 'user' THEN 'assistant' ELSE 'user' END) THEN
    PERFORM _refuse('parent_invalid');
  END IF;
  BEGIN
    INSERT INTO messages (conversation_id, parent_id, role, content, reasoning, model_id, model_name,
                          connection_name, prompt_tokens, completion_tokens, state, error)
      VALUES (p_conversation_id, p_parent_id, p_role, p_content, p_reasoning, p_model_id, p_model_name,
              p_connection_name, p_prompt_tokens, p_completion_tokens, p_state, p_error)
      RETURNING message_id INTO v_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
      PERFORM _refuse(v_column || '_invalid');
  END;
  INSERT INTO message_files (message_id, file_id, position)
    SELECT v_id, u.file_id, u.position
    FROM unnest(coalesce(p_file_ids, '{}')) WITH ORDINALITY AS u(file_id, position);
  UPDATE conversations c SET leaf_id = v_id, updated_at = now()
    WHERE c.conversation_id = p_conversation_id;
  RETURN v_id;
END
$$;


-- Conversations -------------------------------------------------------------

-- One's own conversations, the most recently changed first.
CREATE FUNCTION conversations(p_token_hash bytea)
RETURNS TABLE (
  conversation_id bigint, title text, model_id bigint, created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  RETURN QUERY
    SELECT c.conversation_id, c.title, c.model_id, c.created_at, c.updated_at
    FROM conversations c
    WHERE c.account_id = v_me.account_id
    ORDER BY c.updated_at DESC, c.conversation_id DESC;
END
$$;
GRANT EXECUTE ON FUNCTION conversations(bytea) TO :"app_user";

-- One of one's own conversations, with its model and settings.
CREATE FUNCTION conversation(p_token_hash bytea, p_conversation_id bigint)
RETURNS TABLE (
  conversation_id bigint, title text, model_id bigint, model_name text, connection_name text,
  system_prompt text, output_limit integer, leaf_id bigint,
  created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  RETURN QUERY
    SELECT c.conversation_id, c.title, c.model_id, m.name, k.name, c.system_prompt, c.output_limit,
           c.leaf_id, c.created_at, c.updated_at
    FROM conversations c
    LEFT JOIN models m ON m.model_id = c.model_id
    LEFT JOIN connections k ON k.connection_id = m.connection_id
    WHERE c.conversation_id = p_conversation_id;
END
$$;
GRANT EXECUTE ON FUNCTION conversation(bytea, bigint) TO :"app_user";

-- Starts a conversation, with a model or none yet. Returns its id.
CREATE FUNCTION create_conversation(p_token_hash bytea, p_title text, p_model_id bigint) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_id bigint;
  v_constraint text;
  v_column text;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _usable_model(p_model_id);
  BEGIN
    INSERT INTO conversations (account_id, title, model_id)
      VALUES (v_me.account_id, btrim(p_title), p_model_id)
      RETURNING conversation_id INTO v_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
      PERFORM _refuse(v_column || '_invalid');
  END;
  RETURN v_id;
END
$$;
GRANT EXECUTE ON FUNCTION create_conversation(bytea, text, bigint) TO :"app_user";

-- Renames one of one's own conversations.
CREATE FUNCTION rename_conversation(p_token_hash bytea, p_conversation_id bigint, p_title text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  PERFORM _set_conversation(p_conversation_id, 'title', btrim(p_title));
END
$$;
GRANT EXECUTE ON FUNCTION rename_conversation(bytea, bigint, text) TO :"app_user";

-- Switches the model of one of one's own conversations.
CREATE FUNCTION set_conversation_model(p_token_hash bytea, p_conversation_id bigint, p_model_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  PERFORM _usable_model(p_model_id);
  UPDATE conversations c SET model_id = p_model_id, updated_at = now()
    WHERE c.conversation_id = p_conversation_id;
END
$$;
GRANT EXECUTE ON FUNCTION set_conversation_model(bytea, bigint, bigint) TO :"app_user";

-- Sets the system prompt and the output limit of one of one's own
-- conversations. An output limit of NULL leaves it to the server.
CREATE FUNCTION set_conversation_settings(
  p_token_hash bytea, p_conversation_id bigint, p_system_prompt text, p_output_limit integer
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_constraint text;
  v_column text;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  BEGIN
    UPDATE conversations c
      SET system_prompt = p_system_prompt, output_limit = p_output_limit, updated_at = now()
      WHERE c.conversation_id = p_conversation_id;
  EXCEPTION
    WHEN check_violation THEN
      GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
      PERFORM _refuse(v_constraint);
    WHEN not_null_violation THEN
      GET STACKED DIAGNOSTICS v_column = COLUMN_NAME;
      PERFORM _refuse(v_column || '_invalid');
  END;
END
$$;
GRANT EXECUTE ON FUNCTION set_conversation_settings(bytea, bigint, text, integer) TO :"app_user";

-- Deletes one of one's own conversations, with every version of its messages.
-- The files attached to them stay among one's files.
CREATE FUNCTION delete_conversation(p_token_hash bytea, p_conversation_id bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  DELETE FROM conversations c WHERE c.conversation_id = p_conversation_id;
END
$$;
GRANT EXECUTE ON FUNCTION delete_conversation(bytea, bigint) TO :"app_user";


-- Messages ------------------------------------------------------------------

-- The path a conversation shows, from its first message to its leaf. For each
-- message: which version it is among the messages in the same place, counted
-- from 1 in the order they were added, and how many there are; and the files
-- attached to it, in order.
CREATE FUNCTION messages(p_token_hash bytea, p_conversation_id bigint)
RETURNS TABLE (
  message_id bigint, parent_id bigint, role text, content text, reasoning text,
  model_id bigint, model_name text, connection_name text,
  prompt_tokens integer, completion_tokens integer, state text, error text,
  created_at timestamptz, version bigint, versions bigint, files jsonb
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_conversation conversations;
BEGIN
  v_me := _acting(p_token_hash, false);
  v_conversation := _own_conversation(v_me.account_id, p_conversation_id);
  RETURN QUERY
    WITH RECURSIVE path AS (
      SELECT m.*, 0 AS depth FROM messages m WHERE m.message_id = v_conversation.leaf_id
      UNION ALL
      SELECT m.*, path.depth + 1 FROM messages m JOIN path ON m.message_id = path.parent_id
    )
    SELECT p.message_id, p.parent_id, p.role, p.content, p.reasoning, p.model_id, p.model_name,
           p.connection_name, p.prompt_tokens, p.completion_tokens, p.state, p.error, p.created_at,
           (SELECT count(*) FROM messages s
            WHERE s.conversation_id = p.conversation_id AND s.parent_id IS NOT DISTINCT FROM p.parent_id
              AND s.message_id <= p.message_id),
           (SELECT count(*) FROM messages s
            WHERE s.conversation_id = p.conversation_id AND s.parent_id IS NOT DISTINCT FROM p.parent_id),
           (SELECT coalesce(jsonb_agg(jsonb_build_object('file_id', f.file_id, 'kind', f.kind,
                                                         'name', f.name, 'mime_type', f.mime_type)
                                      ORDER BY mf.position), '[]'::jsonb)
            FROM message_files mf JOIN files f ON f.file_id = mf.file_id
            WHERE mf.message_id = p.message_id)
    FROM path p
    ORDER BY p.depth DESC;
END
$$;
GRANT EXECUTE ON FUNCTION messages(bytea, bigint) TO :"app_user";

-- Adds a person's message to one of their own conversations, after the reply
-- P_PARENT_ID, or opening the conversation when it is NULL, with their own
-- files attached in the order given. It needs text, a file, or both. Returns
-- the message's id.
CREATE FUNCTION add_user_message(
  p_token_hash bytea, p_conversation_id bigint, p_parent_id bigint, p_content text, p_file_ids bigint[]
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_file_id bigint;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  IF (SELECT count(*) <> count(DISTINCT u) FROM unnest(p_file_ids) AS u) OR array_position(p_file_ids, NULL) IS NOT NULL THEN
    PERFORM _refuse('files_invalid');
  END IF;
  FOREACH v_file_id IN ARRAY coalesce(p_file_ids, '{}') LOOP
    PERFORM _own_file(v_me.account_id, v_file_id);
  END LOOP;
  IF btrim(coalesce(p_content, '')) = '' AND cardinality(coalesce(p_file_ids, '{}')) = 0 THEN
    PERFORM _refuse('message_empty');
  END IF;
  RETURN _add_message(p_conversation_id, p_parent_id, 'user', coalesce(p_content, ''), NULL,
                      NULL, NULL, NULL, NULL, NULL, 'complete', NULL, p_file_ids);
END
$$;
GRANT EXECUTE ON FUNCTION add_user_message(bytea, bigint, bigint, text, bigint[]) TO :"app_user";

-- Adds a model's reply to one of one's own conversations, after the user
-- message P_PARENT_ID. With P_MODEL_ID given, the reply keeps that model's
-- name and its connection's; with it NULL, as for an imported reply, it keeps
-- P_MODEL_NAME. P_STATE is complete, stopped or failed, and a failed reply
-- carries P_ERROR. Returns the message's id.
CREATE FUNCTION add_reply(
  p_token_hash bytea, p_conversation_id bigint, p_parent_id bigint,
  p_model_id bigint, p_model_name text, p_content text, p_reasoning text,
  p_state text, p_error text, p_prompt_tokens integer, p_completion_tokens integer
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_model_name text := p_model_name;
  v_connection_name text;
BEGIN
  v_me := _acting(p_token_hash, false);
  PERFORM _own_conversation(v_me.account_id, p_conversation_id);
  IF p_model_id IS NOT NULL THEN
    SELECT m.name, k.name INTO v_model_name, v_connection_name
      FROM models m JOIN connections k ON k.connection_id = m.connection_id
      WHERE m.model_id = p_model_id;
    IF NOT FOUND THEN
      PERFORM _refuse('no_such_model');
    END IF;
  END IF;
  RETURN _add_message(p_conversation_id, p_parent_id, 'assistant', coalesce(p_content, ''), p_reasoning,
                      p_model_id, v_model_name, v_connection_name, p_prompt_tokens, p_completion_tokens,
                      p_state, p_error, NULL);
END
$$;
GRANT EXECUTE ON FUNCTION add_reply(bytea, bigint, bigint, bigint, text, text, text, text, text, integer, integer)
  TO :"app_user";

-- Shows the version P_MESSAGE_ID in its place in one of one's own
-- conversations, and below it the newest message at each step. Returns the
-- conversation's new leaf.
CREATE FUNCTION choose_version(p_token_hash bytea, p_message_id bigint) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_conversation_id bigint;
  v_leaf bigint := p_message_id;
  v_child bigint;
BEGIN
  v_me := _acting(p_token_hash, false);
  SELECT m.conversation_id INTO v_conversation_id
    FROM messages m JOIN conversations c ON c.conversation_id = m.conversation_id
    WHERE m.message_id = p_message_id AND c.account_id = v_me.account_id;
  IF NOT FOUND THEN
    PERFORM _refuse('no_such_message');
  END IF;
  LOOP
    SELECT max(m.message_id) INTO v_child FROM messages m WHERE m.parent_id = v_leaf;
    EXIT WHEN v_child IS NULL;
    v_leaf := v_child;
  END LOOP;
  UPDATE conversations c SET leaf_id = v_leaf WHERE c.conversation_id = v_conversation_id;
  RETURN v_leaf;
END
$$;
GRANT EXECUTE ON FUNCTION choose_version(bytea, bigint) TO :"app_user";


-- Files ---------------------------------------------------------------------

-- One's own files, newest first, with how many messages each is attached to.
CREATE FUNCTION files(p_token_hash bytea)
RETURNS TABLE (
  file_id bigint, kind text, path text, name text, size bigint, mime_type text,
  created_at timestamptz, messages bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
BEGIN
  v_me := _acting(p_token_hash, false);
  RETURN QUERY
    SELECT f.file_id, f.kind, f.path, f.name, f.size, f.mime_type, f.created_at,
           (SELECT count(*) FROM message_files mf WHERE mf.file_id = f.file_id)
    FROM files f
    WHERE f.account_id = v_me.account_id
    ORDER BY f.created_at DESC, f.file_id DESC;
END
$$;
GRANT EXECUTE ON FUNCTION files(bytea) TO :"app_user";

-- Records a file the backend has written into one's own folder: its kind, its
-- path inside the folder, the name it was given, its size in bytes and its
-- type. Returns the file's id.
CREATE FUNCTION add_file(
  p_token_hash bytea, p_kind text, p_path text, p_name text, p_size bigint, p_mime_type text
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_id bigint;
  v_constraint text;
  v_column text;
BEGIN
  v_me := _acting(p_token_hash, false);
  BEGIN
    INSERT INTO files (account_id, kind, path, name, size, mime_type)
      VALUES (v_me.account_id, p_kind, p_path, btrim(p_name), p_size, p_mime_type)
      RETURNING file_id INTO v_id;
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
GRANT EXECUTE ON FUNCTION add_file(bytea, text, text, text, bigint, text) TO :"app_user";

-- What the backend needs to read one of one's own files: the account's id,
-- which names its folder, and the file's path, name, type and size.
CREATE FUNCTION file_access(p_token_hash bytea, p_file_id bigint)
RETURNS TABLE (account_id text, path text, name text, mime_type text, size bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_file files;
BEGIN
  v_me := _acting(p_token_hash, false);
  v_file := _own_file(v_me.account_id, p_file_id);
  RETURN QUERY SELECT v_file.account_id, v_file.path, v_file.name, v_file.mime_type, v_file.size;
END
$$;
GRANT EXECUTE ON FUNCTION file_access(bytea, bigint) TO :"app_user";

-- Deletes the record of one of one's own files, and detaches it from every
-- message. Returns its path inside the account's folder, so that the backend
-- can delete it from disk.
CREATE FUNCTION delete_file(p_token_hash bytea, p_file_id bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me accounts;
  v_file files;
BEGIN
  v_me := _acting(p_token_hash, false);
  v_file := _own_file(v_me.account_id, p_file_id);
  DELETE FROM files f WHERE f.file_id = p_file_id;
  RETURN v_file.path;
END
$$;
GRANT EXECUTE ON FUNCTION delete_file(bytea, bigint) TO :"app_user";
