-- Builds AIconman's schema in the schema public of the database it is run
-- against, after dropping everything in it. Run by install/build_schema.sh as
-- the owner role, in one transaction, with the app role's name as the psql
-- variable app_user.

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT USAGE ON SCHEMA public TO :"app_user";

\ir accounts.sql
\ir connections.sql
\ir conversations.sql

-- Functions are created executable by PUBLIC; only the grants above remain.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
