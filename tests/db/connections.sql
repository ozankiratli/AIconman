-- Tests of connections and models, as the owner role, in one transaction that
-- is rolled back. Expects a freshly built and seeded schema with self sign-up
-- open. Keys are made-up bytes; nothing is sent to a server.

BEGIN;
\ir helpers.sql

SELECT sign_up_password('alex', NULL, 'salt-alex', pg_temp.pw('alex'), pg_temp.t('alex'), '1 hour', '1 day');
SELECT sign_up_password('sam', NULL, 'salt-sam', pg_temp.pw('sam'), pg_temp.t('sam'), '1 hour', '1 day');

-- Adding a connection ----------------------------------------------------------

SELECT pg_temp.refused('a member cannot add a connection',
  $$SELECT admin_create_connection(pg_temp.t('sam'), 'pi', 'http://pi.example.lan:8080/v1', NULL, NULL, 60, 300)$$, 'not_admin');
SELECT admin_create_connection(pg_temp.t('alex'), '  pi  ', 'http://pi.example.lan:8080/v1', NULL, '\x6b6579'::bytea, 60, 300) AS pi \gset
SELECT pg_temp.ok('the admin adds a connection, its name trimmed',
  (SELECT name FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi) = 'pi');
SELECT pg_temp.ok('  with a key, which the listing shows only as present',
  (SELECT has_key FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.ok('  not yet checked',
  (SELECT checked_at IS NULL AND models_found = 0 FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.refused('a name already taken',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'pi', 'http://other.example.lan', NULL, NULL, 60, 300)$$, 'name_taken');
SELECT pg_temp.refused('an empty name',
  $$SELECT admin_create_connection(pg_temp.t('alex'), '  ', 'http://other.example.lan', NULL, NULL, 60, 300)$$, 'name_invalid');
SELECT pg_temp.refused('no name',
  $$SELECT admin_create_connection(pg_temp.t('alex'), NULL, 'http://other.example.lan', NULL, NULL, 60, 300)$$, 'name_invalid');
SELECT pg_temp.refused('a base URL that is not http or https',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'ftp://box.example.lan', NULL, NULL, 60, 300)$$, 'base_url_invalid');
SELECT pg_temp.refused('a base URL with a space',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box example.lan', NULL, NULL, 60, 300)$$, 'base_url_invalid');
SELECT pg_temp.refused('no base URL',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', NULL, NULL, NULL, 60, 300)$$, 'base_url_invalid');
SELECT pg_temp.refused('a protocol AIconman does not speak',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box.example.lan', 'vllm', NULL, 60, 300)$$, 'protocol_invalid');
SELECT pg_temp.refused('an empty key',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box.example.lan', NULL, '\x'::bytea, 60, 300)$$, 'api_key_invalid');
SELECT pg_temp.ok('  with its two timeouts, in seconds',
  (SELECT connect_timeout = 60 AND answer_timeout = 300 FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.refused('a timeout of 0 seconds',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box.example.lan', NULL, NULL, 0, 300)$$, 'connect_timeout_invalid');
SELECT pg_temp.refused('no timeout for an answer',
  $$SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'http://box.example.lan', NULL, NULL, 60, NULL)$$, 'answer_timeout_invalid');
SELECT pg_temp.refused('a member is not confirmed as the admin',
  $$SELECT admin_confirm(pg_temp.t('sam'))$$, 'not_admin');
SELECT pg_temp.passes('the admin is confirmed', $$SELECT admin_confirm(pg_temp.t('alex'))$$);
SELECT pg_temp.ok('the members have no models before a check',
  NOT EXISTS (SELECT 1 FROM models(pg_temp.t('sam'))));

-- Checking it ----------------------------------------------------------------------

SELECT pg_temp.refused('a member cannot record a check',
  format($$SELECT admin_record_check(pg_temp.t('sam'), %s, 'openai', NULL, '[]')$$, :pi), 'not_admin');
SELECT admin_record_check(pg_temp.t('alex'), :pi, 'openai', NULL,
  '[{"name": "qwen3-4b", "chat": true, "images": false, "context": 4096},
    {"name": "whisper", "chat": false, "speech": true}]');
SELECT pg_temp.ok('a check records the protocol detected and that it succeeded',
  (SELECT detected_protocol = 'openai' AND check_error IS NULL AND checked_at = now()
   FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.ok('  and the models found',
  (SELECT models_found FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi) = 2);
SELECT pg_temp.ok('a member sees the models, with their connection',
  (SELECT array_agg(name || '@' || connection_name ORDER BY name) FROM models(pg_temp.t('sam')))
  = ARRAY['qwen3-4b@pi', 'whisper@pi']);
SELECT pg_temp.ok('  and what each can do, as reported',
  (SELECT chat AND NOT images AND speech IS NULL AND context = 4096
   FROM models(pg_temp.t('sam')) WHERE name = 'qwen3-4b'));
SELECT pg_temp.ok('  NULL where nothing was reported',
  (SELECT images IS NULL AND context IS NULL FROM models(pg_temp.t('sam')) WHERE name = 'whisper'));
SELECT model_id AS qwen FROM models(pg_temp.t('sam')) WHERE name = 'qwen3-4b' \gset
SELECT model_id AS whisper FROM models(pg_temp.t('sam')) WHERE name = 'whisper' \gset

-- The admin's values ------------------------------------------------------------------

SELECT pg_temp.refused('a member cannot set what a model can do',
  format('SELECT admin_set_model(pg_temp.t(%L), %s, NULL, NULL, NULL, 8192)', 'sam', :qwen), 'not_admin');
SELECT admin_set_model(pg_temp.t('alex'), :qwen, NULL, true, NULL, 8192);
SELECT pg_temp.ok('a value the admin sets wins over the reported one',
  (SELECT images AND context = 8192 FROM models(pg_temp.t('sam')) WHERE model_id = :qwen));
SELECT pg_temp.ok('  and the admin sees both',
  (SELECT reported_context = 4096 AND set_context = 8192 AND NOT reported_images AND set_images
   FROM admin_models(pg_temp.t('alex'), :pi) WHERE model_id = :qwen));
SELECT pg_temp.refused('a context window of 0',
  format('SELECT admin_set_model(pg_temp.t(%L), %s, NULL, NULL, NULL, 0)', 'alex', :qwen), 'context_invalid');
SELECT pg_temp.refused('a model that does not exist',
  $$SELECT admin_set_model(pg_temp.t('alex'), -1, NULL, NULL, NULL, NULL)$$, 'no_such_model');
SELECT admin_set_model(pg_temp.t('alex'), :whisper, NULL, NULL, NULL, 448);

-- Checking again ----------------------------------------------------------------------

SELECT admin_record_check(pg_temp.t('alex'), :pi, 'openai', NULL,
  '[{"name": "qwen3-4b", "chat": true, "images": false, "context": 32768}]');
SELECT pg_temp.ok('a model the next check does not find disappears for members',
  (SELECT array_agg(name) FROM models(pg_temp.t('sam'))) = ARRAY['qwen3-4b']);
SELECT pg_temp.ok('  and is kept for the admin, marked not found',
  (SELECT NOT present FROM admin_models(pg_temp.t('alex'), :pi) WHERE model_id = :whisper));
SELECT pg_temp.ok('the newly reported value is kept, and the admin''s still wins',
  (SELECT reported_context = 32768 FROM admin_models(pg_temp.t('alex'), :pi) WHERE model_id = :qwen)
  AND (SELECT context = 8192 FROM models(pg_temp.t('sam')) WHERE model_id = :qwen));
SELECT pg_temp.refused('a model not found cannot be used',
  format('SELECT model_access(pg_temp.t(%L), %s)', 'sam', :whisper), 'model_unavailable');
SELECT admin_record_check(pg_temp.t('alex'), :pi, 'openai', NULL,
  '[{"name": "qwen3-4b", "chat": true, "context": 32768, "counts": true}, {"name": "whisper", "speech": true}]');
SELECT pg_temp.ok('a model found again comes back with the same id and the admin''s values',
  (SELECT context = 448 FROM models(pg_temp.t('sam')) WHERE model_id = :whisper));
SELECT pg_temp.ok('whether a model''s server counts tokens is recorded, false where not reported',
  (SELECT counts_tokens FROM model_access(pg_temp.t('sam'), :qwen))
  AND NOT (SELECT counts_tokens FROM model_access(pg_temp.t('sam'), :whisper)));

SELECT admin_record_check(pg_temp.t('alex'), :pi, NULL, 'unreachable', NULL);
SELECT pg_temp.ok('a failed check records its error',
  (SELECT check_error = 'unreachable' FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.ok('  and leaves the models and the protocol detected as they were',
  (SELECT detected_protocol = 'openai' AND models_found = 2
   FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));
SELECT pg_temp.ok('  and whether a model''s server counts tokens',
  (SELECT counts_tokens FROM model_access(pg_temp.t('sam'), :qwen)));
SELECT pg_temp.refused('an empty error',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, NULL, '', NULL)$$, :pi), 'check_error_invalid');

SELECT pg_temp.refused('a check whose models are not a list',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '{"name": "m"}')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a check with no models given',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, NULL)$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a model with no name',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"chat": true}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a model with an empty name',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": ""}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('the same model twice',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": "m"}, {"name": "m"}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a capability that is not true or false',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": "m", "chat": "maybe"}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('counting tokens that is not true or false',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": "m", "counts": "maybe"}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a context window that is not a whole number',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": "m", "context": 40.5}]')$$, :pi), 'models_invalid');
SELECT pg_temp.refused('a reported context window below 1',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'openai', NULL, '[{"name": "m", "context": -1}]')$$, :pi), 'context_invalid');
SELECT pg_temp.refused('a protocol detected that AIconman does not speak',
  format($$SELECT admin_record_check(pg_temp.t('alex'), %s, 'vllm', NULL, '[]')$$, :pi), 'detected_protocol_invalid');
SELECT pg_temp.ok('  and a refused check changes nothing',
  (SELECT models_found = 2 AND check_error = 'unreachable' FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :pi));

-- Using a model -------------------------------------------------------------------------

SELECT pg_temp.ok('a member gets what the backend needs to use a model',
  (SELECT model_name = 'qwen3-4b' AND context = 8192 AND base_url = 'http://pi.example.lan:8080/v1'
          AND protocol = 'openai' AND api_key = '\x6b6579'::bytea
   FROM model_access(pg_temp.t('sam'), :qwen)));
SELECT admin_update_connection(pg_temp.t('alex'), :pi, 'pi', 'http://pi.example.lan:8080/v1', 'ollama', 60, 300);
SELECT pg_temp.ok('a protocol the admin chose wins over the one detected',
  (SELECT protocol FROM model_access(pg_temp.t('sam'), :qwen)) = 'ollama');
SELECT admin_update_connection(pg_temp.t('alex'), :pi, 'pi', 'http://pi.example.lan:8080/v1', 'ollama', 120, 900);
SELECT pg_temp.ok('the admin changes the timeouts, and the backend gets them to use a model',
  (SELECT connect_timeout = 120 AND answer_timeout = 900 FROM model_access(pg_temp.t('sam'), :qwen)));
SELECT pg_temp.ok('  to check the connection',
  (SELECT connect_timeout = 120 AND answer_timeout = 900 FROM admin_connection_access(pg_temp.t('alex'), :pi)));
SELECT pg_temp.ok('  and to refresh it',
  (SELECT connect_timeout = 120 AND answer_timeout = 900 FROM refresh_targets() WHERE connection_id = :pi));
SELECT pg_temp.refused('a negative timeout',
  format($$SELECT admin_update_connection(pg_temp.t('alex'), %s, 'pi', 'http://pi.example.lan:8080/v1', NULL, 60, -1)$$, :pi), 'answer_timeout_invalid');
SELECT pg_temp.refused('a model id that does not exist',
  $$SELECT model_access(pg_temp.t('sam'), -1)$$, 'no_such_model');
SELECT pg_temp.refused('no session',
  format('SELECT model_access(pg_temp.t(%L), %s)', 'nobody', :qwen), 'session_invalid');

SELECT admin_create_connection(pg_temp.t('alex'), 'box', 'https://box.example.lan', NULL, NULL, 60, 300) AS box \gset
SELECT admin_record_check(pg_temp.t('alex'), :box, NULL, NULL, '[{"name": "m", "counts": true}]');
SELECT model_id AS box_model FROM models(pg_temp.t('sam')) WHERE connection_name = 'box' \gset
SELECT pg_temp.ok('a new model whose server counts tokens is recorded so',
  (SELECT counts_tokens FROM models WHERE model_id = :box_model));
SELECT pg_temp.refused('a model whose protocol is neither chosen nor detected',
  format('SELECT model_access(pg_temp.t(%L), %s)', 'sam', :box_model), 'protocol_unknown');
SELECT pg_temp.ok('a connection without a key gives none',
  (SELECT has_key FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :box) = false);

-- The scheduled refresh, with no session ------------------------------------------------

SELECT pg_temp.ok('the scheduled refresh lists every connection, with its key still encrypted',
  (SELECT array_agg(connection_id ORDER BY connection_id) FROM refresh_targets()) = ARRAY[:pi, :box]::bigint[]
  AND (SELECT api_key FROM refresh_targets() WHERE connection_id = :pi) = '\x6b6579'::bytea);
SELECT refresh_record_check(:box, 'ollama', NULL, '[{"name": "m"}, {"name": "n", "chat": true}]');
SELECT pg_temp.ok('  and records a check as the admin''s check does',
  (SELECT detected_protocol = 'ollama' AND models_found = 2 AND check_error IS NULL
   FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :box));
SELECT pg_temp.ok('  a model whose server no longer counts tokens among it',
  NOT (SELECT counts_tokens FROM model_access(pg_temp.t('sam'), :box_model)));
SELECT pg_temp.refused('  refusing what the admin''s check refuses',
  format($$SELECT refresh_record_check(%s, 'openai', NULL, '[{"name": ""}]')$$, :box), 'models_invalid');
SELECT pg_temp.refused('  and a connection that does not exist',
  $$SELECT refresh_record_check(-1, NULL, 'unreachable', NULL)$$, 'no_such_connection');
SELECT refresh_record_check(:box, NULL, 'timed out', NULL);
SELECT pg_temp.ok('  and a failed check',
  (SELECT check_error = 'timed out' AND models_found = 2
   FROM admin_connections(pg_temp.t('alex')) WHERE connection_id = :box));

-- Changing and removing ------------------------------------------------------------------

SELECT pg_temp.refused('renaming to a name already taken',
  format($$SELECT admin_update_connection(pg_temp.t('alex'), %s, 'pi', 'https://box.example.lan', NULL, 60, 300)$$, :box), 'name_taken');
SELECT pg_temp.refused('a member cannot change a connection',
  format($$SELECT admin_update_connection(pg_temp.t('sam'), %s, 'box', 'https://box.example.lan', NULL, 60, 300)$$, :box), 'not_admin');
SELECT pg_temp.refused('a connection that does not exist',
  $$SELECT admin_update_connection(pg_temp.t('alex'), -1, 'x', 'https://x.example.lan', NULL, 60, 300)$$, 'no_such_connection');
SELECT admin_set_connection_key(pg_temp.t('alex'), :pi, '\x6e6577'::bytea);
SELECT pg_temp.ok('the admin replaces a key',
  (SELECT api_key FROM admin_connection_access(pg_temp.t('alex'), :pi)) = '\x6e6577'::bytea);
SELECT admin_set_connection_key(pg_temp.t('alex'), :pi, NULL);
SELECT pg_temp.ok('  and removes it',
  (SELECT api_key IS NULL FROM model_access(pg_temp.t('sam'), :qwen)));
SELECT pg_temp.refused('a member cannot read a connection for checking',
  format('SELECT admin_connection_access(pg_temp.t(%L), %s)', 'sam', :pi), 'not_admin');
SELECT pg_temp.refused('a member cannot remove a connection',
  format('SELECT admin_delete_connection(pg_temp.t(%L), %s)', 'sam', :pi), 'not_admin');
SELECT admin_delete_connection(pg_temp.t('alex'), :pi);
SELECT pg_temp.ok('the admin removes a connection, and its models with it',
  NOT EXISTS (SELECT 1 FROM connections WHERE connection_id = :pi)
  AND NOT EXISTS (SELECT 1 FROM models WHERE connection_id = :pi));
SELECT pg_temp.ok('  so the members no longer see them',
  (SELECT array_agg(DISTINCT connection_name) FROM models(pg_temp.t('sam'))) = ARRAY['box']);

ROLLBACK;
