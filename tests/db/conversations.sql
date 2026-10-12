-- Tests of conversations, messages and files, as the owner role, in one
-- transaction that is rolled back. Expects a freshly built and seeded schema
-- with self sign-up open. No file is written to disk; only records are made.

BEGIN;
\ir helpers.sql

-- The ids of the messages a conversation shows, in order, as P_NAME sees them.
CREATE FUNCTION pg_temp.path(p_name text, p_conversation_id bigint) RETURNS bigint[]
LANGUAGE sql AS $$
  SELECT array_agg(r.message_id ORDER BY r.n)
  FROM messages(pg_temp.t(p_name), p_conversation_id)
    WITH ORDINALITY AS r(message_id, parent_id, role, content, reasoning, model_id, model_name,
                         connection_name, prompt_tokens, completion_tokens, state, error, created_at,
                         version, versions, files, n)
$$;

SELECT sign_up_password('alex', NULL, 'salt-alex', pg_temp.pw('alex'), pg_temp.t('alex'), '1 hour', '1 day') AS alex_id \gset
SELECT sign_up_password('sam', NULL, 'salt-sam', pg_temp.pw('sam'), pg_temp.t('sam'), '1 hour', '1 day') AS sam_id \gset
SELECT admin_create_connection(pg_temp.t('alex'), 'pi', 'http://pi.example.lan:8080/v1', NULL, NULL) AS pi \gset
SELECT admin_record_check(pg_temp.t('alex'), :pi, 'openai', NULL, '[{"name": "qwen3-4b", "chat": true}, {"name": "gone"}]');
SELECT admin_record_check(pg_temp.t('alex'), :pi, 'openai', NULL, '[{"name": "qwen3-4b", "chat": true}]');
SELECT model_id AS qwen FROM admin_models(pg_temp.t('alex'), :pi) WHERE name = 'qwen3-4b' \gset
SELECT model_id AS gone FROM admin_models(pg_temp.t('alex'), :pi) WHERE name = 'gone' \gset
SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box.example.lan', 'ollama', NULL) AS box \gset
SELECT admin_record_check(pg_temp.t('alex'), :box, NULL, NULL, '[{"name": "llama3"}]');
SELECT model_id AS llama FROM admin_models(pg_temp.t('alex'), :box) WHERE name = 'llama3' \gset

-- Conversations -------------------------------------------------------------

SELECT create_conversation(pg_temp.t('alex'), '  Trip plan  ', :qwen) AS trip \gset
SELECT pg_temp.ok('a person starts a conversation, its title trimmed',
  (SELECT title FROM conversation(pg_temp.t('alex'), :trip)) = 'Trip plan');
SELECT pg_temp.ok('  with its model and that model''s connection',
  (SELECT model_name = 'qwen3-4b' AND connection_name = 'pi' FROM conversation(pg_temp.t('alex'), :trip)));
SELECT pg_temp.ok('  and no messages yet',
  NOT EXISTS (SELECT 1 FROM messages(pg_temp.t('alex'), :trip)));
SELECT create_conversation(pg_temp.t('alex'), '', NULL) AS untitled \gset
SELECT pg_temp.ok('a conversation can start with no title and no model',
  (SELECT title = '' AND model_id IS NULL FROM conversation(pg_temp.t('alex'), :untitled)));
SELECT pg_temp.refused('a title of 201 characters',
  $$SELECT create_conversation(pg_temp.t('alex'), repeat('t', 201), NULL)$$, 'title_invalid');
SELECT pg_temp.refused('a title with a line break',
  $$SELECT create_conversation(pg_temp.t('alex'), E'a\nb', NULL)$$, 'title_invalid');
SELECT pg_temp.refused('a model the last check did not find',
  format('SELECT create_conversation(pg_temp.t(%L), %L, %s)', 'alex', 'x', :gone), 'model_unavailable');
SELECT pg_temp.refused('a model that does not exist',
  $$SELECT create_conversation(pg_temp.t('alex'), 'x', -1)$$, 'no_such_model');
UPDATE conversations SET updated_at = now() - interval '1 hour' WHERE conversation_id = :untitled;
SELECT pg_temp.ok('a person''s conversations are listed, the most recently changed first',
  (SELECT array_agg(conversation_id) FROM conversations(pg_temp.t('alex'))) = ARRAY[:trip, :untitled]::bigint[]);
SELECT pg_temp.ok('another person sees none of them',
  NOT EXISTS (SELECT 1 FROM conversations(pg_temp.t('sam'))));
SELECT pg_temp.refused('  cannot open one',
  format('SELECT conversation(pg_temp.t(%L), %s)', 'sam', :trip), 'no_such_conversation');
SELECT pg_temp.refused('  or read its messages',
  format('SELECT messages(pg_temp.t(%L), %s)', 'sam', :trip), 'no_such_conversation');
SELECT pg_temp.refused('  or rename it',
  format('SELECT rename_conversation(pg_temp.t(%L), %s, %L)', 'sam', :trip, 'x'), 'no_such_conversation');
SELECT pg_temp.refused('  or add to it',
  format('SELECT add_user_message(pg_temp.t(%L), %s, NULL, %L, NULL)', 'sam', :trip, 'hi'), 'no_such_conversation');
SELECT pg_temp.refused('  or delete it',
  format('SELECT delete_conversation(pg_temp.t(%L), %s)', 'sam', :trip), 'no_such_conversation');
SELECT pg_temp.refused('the admin cannot open another person''s conversation either',
  format('SELECT conversation(pg_temp.t(%L), %s)', 'alex',
         create_conversation(pg_temp.t('sam'), 'Sam''s', NULL)), 'no_such_conversation');

SELECT rename_conversation(pg_temp.t('alex'), :trip, ' Trip to Lisbon ');
SELECT pg_temp.ok('a person renames their conversation',
  (SELECT title FROM conversation(pg_temp.t('alex'), :trip)) = 'Trip to Lisbon');
SELECT set_conversation_settings(pg_temp.t('alex'), :trip, 'Answer briefly.', 512);
SELECT pg_temp.ok('sets its system prompt and output limit',
  (SELECT system_prompt = 'Answer briefly.' AND output_limit = 512 FROM conversation(pg_temp.t('alex'), :trip)));
SELECT pg_temp.refused('an output limit of 0',
  format('SELECT set_conversation_settings(pg_temp.t(%L), %s, %L, 0)', 'alex', :trip, ''), 'output_limit_invalid');
SELECT pg_temp.refused('no system prompt',
  format('SELECT set_conversation_settings(pg_temp.t(%L), %s, NULL, NULL)', 'alex', :trip), 'system_prompt_invalid');
SELECT set_conversation_settings(pg_temp.t('alex'), :trip, 'Answer briefly.', NULL);
SELECT pg_temp.ok('an output limit of NULL leaves it to the server',
  (SELECT output_limit IS NULL FROM conversation(pg_temp.t('alex'), :trip)));

-- Messages and their versions -------------------------------------------------

SELECT add_user_message(pg_temp.t('alex'), :trip, NULL, 'Plan a trip', NULL) AS u1 \gset
SELECT pg_temp.ok('a person''s first message opens the conversation, and is shown',
  pg_temp.path('alex', :trip) = ARRAY[:u1]::bigint[]);
SELECT add_reply(pg_temp.t('alex'), :trip, :u1, :qwen, NULL, 'Here is a plan', 'Thinking.', 'complete', NULL, 12, 34) AS r1 \gset
SELECT pg_temp.ok('a reply keeps its model''s and connection''s names, its reasoning and its counts',
  (SELECT model_name = 'qwen3-4b' AND connection_name = 'pi' AND reasoning = 'Thinking.'
          AND prompt_tokens = 12 AND completion_tokens = 34 AND state = 'complete'
   FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :r1));
SELECT pg_temp.refused('a reply that follows a reply',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, %L, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :r1, :qwen, 'x', 'complete'), 'parent_invalid');
SELECT pg_temp.refused('a person''s message that follows a person''s message',
  format('SELECT add_user_message(pg_temp.t(%L), %s, %s, %L, NULL)', 'alex', :trip, :u1, 'x'), 'parent_invalid');
SELECT pg_temp.refused('a reply that opens a conversation',
  format('SELECT add_reply(pg_temp.t(%L), %s, NULL, %s, NULL, %L, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :qwen, 'x', 'complete'), 'parent_invalid');
SELECT pg_temp.refused('a message that follows one in another conversation',
  format('SELECT add_user_message(pg_temp.t(%L), %s, %s, %L, NULL)', 'alex', :untitled, :r1, 'x'), 'parent_invalid');
SELECT pg_temp.refused('a message with no text and no file',
  format('SELECT add_user_message(pg_temp.t(%L), %s, %s, %L, NULL)', 'alex', :trip, :r1, '  '), 'message_empty');

SELECT add_user_message(pg_temp.t('alex'), :trip, :r1, 'Make it cheaper', NULL) AS u2 \gset
SELECT add_reply(pg_temp.t('alex'), :trip, :u2, :qwen, NULL, 'A cheaper plan', NULL, 'complete', NULL, NULL, NULL) AS r2 \gset
SELECT add_reply(pg_temp.t('alex'), :trip, :u2, :llama, NULL, 'Another cheaper plan', NULL, 'complete', NULL, NULL, NULL) AS r2b \gset
SELECT pg_temp.ok('regenerating adds another reply, which the conversation shows',
  pg_temp.path('alex', :trip) = ARRAY[:u1, :r1, :u2, :r2b]::bigint[]);
SELECT pg_temp.ok('  as the second of two, here from another model',
  (SELECT version = 2 AND versions = 2 AND model_name = 'llama3' AND connection_name = 'box'
   FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :r2b));
SELECT add_user_message(pg_temp.t('alex'), :trip, :r1, 'Make it longer', NULL) AS u2b \gset
SELECT pg_temp.ok('editing a message adds another in its place, which the conversation shows',
  pg_temp.path('alex', :trip) = ARRAY[:u1, :r1, :u2b]::bigint[]);
SELECT pg_temp.ok('  as the second of two',
  (SELECT version = 2 AND versions = 2 FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :u2b));
SELECT choose_version(pg_temp.t('alex'), :u2);
SELECT pg_temp.ok('choosing an earlier version shows it, with the newest reply below it',
  pg_temp.path('alex', :trip) = ARRAY[:u1, :r1, :u2, :r2b]::bigint[]);
SELECT pg_temp.ok('  as the first of two',
  (SELECT version = 1 AND versions = 2 FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :u2));
SELECT choose_version(pg_temp.t('alex'), :r2);
SELECT pg_temp.ok('choosing an earlier reply shows it',
  pg_temp.path('alex', :trip) = ARRAY[:u1, :r1, :u2, :r2]::bigint[]);
SELECT add_user_message(pg_temp.t('alex'), :trip, NULL, 'Plan a different trip', NULL) AS u1b \gset
SELECT pg_temp.ok('editing the first message adds another first message',
  pg_temp.path('alex', :trip) = ARRAY[:u1b]::bigint[]
  AND (SELECT version = 2 AND versions = 2 FROM messages(pg_temp.t('alex'), :trip)));
SELECT choose_version(pg_temp.t('alex'), :u1);
SELECT pg_temp.ok('  and choosing the first one again shows the newest below it at each step',
  pg_temp.path('alex', :trip) = ARRAY[:u1, :r1, :u2b]::bigint[]);
SELECT pg_temp.ok('nothing was deleted along the way',
  (SELECT count(*) FROM messages WHERE conversation_id = :trip) = 7);
SELECT pg_temp.refused('another person cannot choose a version',
  format('SELECT choose_version(pg_temp.t(%L), %s)', 'sam', :u2), 'no_such_message');

-- Replies that stopped or failed, and imported ones ----------------------------

SELECT add_reply(pg_temp.t('alex'), :trip, :u2b, :qwen, NULL, 'Half a pl', NULL, 'stopped', NULL, NULL, NULL) AS stopped \gset
SELECT pg_temp.ok('a reply stopped partway is kept as stopped',
  (SELECT state = 'stopped' AND content = 'Half a pl' FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :stopped));
SELECT add_reply(pg_temp.t('alex'), :trip, :u2b, :qwen, NULL, NULL, NULL, 'failed', 'unreachable', NULL, NULL) AS failed \gset
SELECT pg_temp.ok('a failed reply keeps its error',
  (SELECT state = 'failed' AND error = 'unreachable' AND content = '' FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :failed));
SELECT pg_temp.refused('a failed reply with no error',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, NULL, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :u2b, :qwen, 'failed'), 'error_invalid');
SELECT pg_temp.refused('a complete reply with an error',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, %L, NULL, %L, %L, NULL, NULL)', 'alex', :trip, :u2b, :qwen, 'x', 'complete', 'oops'), 'error_invalid');
SELECT pg_temp.refused('a state that does not exist',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, %L, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :u2b, :qwen, 'x', 'streaming'), 'state_invalid');
SELECT pg_temp.refused('no state',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, %L, NULL, NULL, NULL, NULL, NULL)', 'alex', :trip, :u2b, :qwen, 'x'), 'state_invalid');
SELECT pg_temp.refused('a negative token count',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, %s, NULL, %L, NULL, %L, NULL, -1, 5)', 'alex', :trip, :u2b, :qwen, 'x', 'complete'), 'tokens_invalid');
SELECT pg_temp.refused('a reply that names no model',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, NULL, NULL, %L, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :u2b, 'x', 'complete'), 'model_name_invalid');
SELECT pg_temp.refused('a model id that does not exist',
  format('SELECT add_reply(pg_temp.t(%L), %s, %s, -1, NULL, %L, NULL, %L, NULL, NULL, NULL)', 'alex', :trip, :u2b, 'x', 'complete'), 'no_such_model');
SELECT add_reply(pg_temp.t('alex'), :trip, :u2b, NULL, 'old-model', 'An imported reply', NULL, 'complete', NULL, NULL, NULL) AS imported \gset
SELECT pg_temp.ok('a reply with no model id keeps the model name given, as an imported one would',
  (SELECT model_id IS NULL AND model_name = 'old-model' AND connection_name IS NULL
   FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :imported));

-- Files ---------------------------------------------------------------------

SELECT add_file(pg_temp.t('alex'), 'image', 'images/beach.png', ' beach.png ', 1234, 'image/png') AS beach \gset
SELECT pg_temp.ok('a person records a file in their folder',
  (SELECT kind = 'image' AND path = 'images/beach.png' AND name = 'beach.png' AND size = 1234
          AND mime_type = 'image/png' AND messages = 0
   FROM files(pg_temp.t('alex')) WHERE file_id = :beach));
SELECT pg_temp.refused('a path that climbs out of the folder',
  $$SELECT add_file(pg_temp.t('alex'), 'image', '../x.png', 'x.png', 1, 'image/png')$$, 'path_invalid');
SELECT pg_temp.refused('a path that climbs out partway',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/../../x.png', 'x.png', 1, 'image/png')$$, 'path_invalid');
SELECT pg_temp.refused('an absolute path',
  $$SELECT add_file(pg_temp.t('alex'), 'image', '/etc/passwd', 'x', 1, 'text/plain')$$, 'path_invalid');
SELECT pg_temp.refused('a path with an empty part',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images//x.png', 'x.png', 1, 'image/png')$$, 'path_invalid');
SELECT pg_temp.refused('a path with a "." part',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/./x.png', 'x.png', 1, 'image/png')$$, 'path_invalid');
SELECT pg_temp.refused('a path with a space',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/x y.png', 'x.png', 1, 'image/png')$$, 'path_invalid');
SELECT pg_temp.refused('a path already recorded',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/beach.png', 'b.png', 1, 'image/png')$$, 'path_taken');
SELECT add_file(pg_temp.t('sam'), 'image', 'images/beach.png', 'beach.png', 10, 'image/png') AS sams_beach \gset
SELECT pg_temp.ok('another person may use the same path in their own folder', :sams_beach IS NOT NULL);
SELECT pg_temp.refused('a kind of file that does not exist',
  $$SELECT add_file(pg_temp.t('alex'), 'video', 'v/x.mp4', 'x.mp4', 1, 'video/mp4')$$, 'kind_invalid');
SELECT pg_temp.refused('a type in uppercase',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/y.png', 'y.png', 1, 'Image/PNG')$$, 'mime_type_invalid');
SELECT pg_temp.refused('a negative size',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/y.png', 'y.png', -1, 'image/png')$$, 'size_invalid');
SELECT pg_temp.refused('an empty name',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/y.png', '  ', 1, 'image/png')$$, 'name_invalid');
SELECT pg_temp.refused('no name',
  $$SELECT add_file(pg_temp.t('alex'), 'image', 'images/y.png', NULL, 1, 'image/png')$$, 'name_invalid');

SELECT add_file(pg_temp.t('alex'), 'image', 'images/map.jpg', 'map.jpg', 99, 'image/jpeg') AS map \gset
SELECT add_user_message(pg_temp.t('alex'), :trip, :imported, 'Look at these', ARRAY[:map, :beach]) AS u3 \gset
SELECT pg_temp.ok('a person attaches their files to a message, in the order given',
  (SELECT files -> 0 ->> 'name' = 'map.jpg' AND files -> 1 ->> 'name' = 'beach.png'
   FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :u3));
SELECT pg_temp.ok('  and the list of files counts the messages each is attached to',
  (SELECT messages FROM files(pg_temp.t('alex')) WHERE file_id = :beach) = 1);
SELECT add_user_message(pg_temp.t('alex'), :trip, :imported, NULL, ARRAY[:map]) AS u3b \gset
SELECT pg_temp.ok('a message may have a file and no text',
  (SELECT content = '' AND jsonb_array_length(files) = 1 FROM messages(pg_temp.t('alex'), :trip) WHERE message_id = :u3b));
SELECT pg_temp.refused('attaching someone else''s file',
  format('SELECT add_user_message(pg_temp.t(%L), %s, %s, %L, ARRAY[%s]::bigint[])', 'alex', :trip, :imported, 'x', :sams_beach), 'no_such_file');
SELECT pg_temp.refused('attaching the same file twice',
  format('SELECT add_user_message(pg_temp.t(%L), %s, %s, %L, ARRAY[%s, %s]::bigint[])', 'alex', :trip, :imported, 'x', :map, :map), 'files_invalid');
SELECT pg_temp.ok('the backend reads a file by the account''s id and its path',
  (SELECT account_id = :'alex_id' AND path = 'images/beach.png' AND mime_type = 'image/png'
   FROM file_access(pg_temp.t('alex'), :beach)));
SELECT pg_temp.refused('another person cannot read a file',
  format('SELECT file_access(pg_temp.t(%L), %s)', 'sam', :beach), 'no_such_file');
SELECT pg_temp.refused('  or delete it',
  format('SELECT delete_file(pg_temp.t(%L), %s)', 'sam', :beach), 'no_such_file');
SELECT pg_temp.ok('deleting a file gives back its path, for the backend to delete it from disk',
  delete_file(pg_temp.t('alex'), :beach) = 'images/beach.png');
SELECT pg_temp.ok('  and detaches it from its messages, which stay',
  EXISTS (SELECT 1 FROM messages WHERE message_id = :u3)
  AND (SELECT array_agg(file_id) FROM message_files WHERE message_id = :u3) = ARRAY[:map]::bigint[]);

-- A connection removed ---------------------------------------------------------

SELECT set_conversation_model(pg_temp.t('alex'), :untitled, :llama);
SELECT admin_delete_connection(pg_temp.t('alex'), :box);
SELECT pg_temp.ok('removing a connection leaves its replies, with their model''s and connection''s names',
  (SELECT model_id IS NULL AND model_name = 'llama3' AND connection_name = 'box' FROM messages WHERE message_id = :r2b));
SELECT pg_temp.ok('  and a conversation that used one of its models has none',
  (SELECT model_id IS NULL FROM conversation(pg_temp.t('alex'), :untitled)));
SELECT set_conversation_model(pg_temp.t('alex'), :untitled, :qwen);
SELECT pg_temp.ok('  until the person picks another',
  (SELECT model_name FROM conversation(pg_temp.t('alex'), :untitled)) = 'qwen3-4b');
SELECT pg_temp.refused('switching to a model the last check did not find',
  format('SELECT set_conversation_model(pg_temp.t(%L), %s, %s)', 'alex', :untitled, :gone), 'model_unavailable');

-- Deleting -------------------------------------------------------------------

SELECT delete_conversation(pg_temp.t('alex'), :trip);
SELECT pg_temp.ok('deleting a conversation deletes every version of its messages',
  NOT EXISTS (SELECT 1 FROM conversations WHERE conversation_id = :trip)
  AND NOT EXISTS (SELECT 1 FROM messages WHERE conversation_id = :trip));
SELECT pg_temp.ok('  and keeps the files that were attached',
  EXISTS (SELECT 1 FROM files WHERE file_id = :map));
SELECT create_conversation(pg_temp.t('sam'), 'Hello', NULL) AS sams_chat \gset
SELECT add_user_message(pg_temp.t('sam'), :sams_chat, NULL, 'hello', ARRAY[:sams_beach]::bigint[]);
SELECT admin_delete_account(pg_temp.t('alex'), :'sam_id');
SELECT pg_temp.ok('deleting an account deletes its conversations, their messages, and its files',
  NOT EXISTS (SELECT 1 FROM conversations WHERE account_id = :'sam_id')
  AND NOT EXISTS (SELECT 1 FROM messages WHERE conversation_id = :sams_chat)
  AND NOT EXISTS (SELECT 1 FROM files WHERE account_id = :'sam_id'));

ROLLBACK;
