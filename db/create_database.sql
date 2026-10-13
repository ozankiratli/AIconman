-- Creates LMconman's two database roles and its database, empty. The schema is
-- built afterwards, as the owner role.
--
-- Run by install/create_database.sh, as a PostgreSQL superuser. The script
-- passes the names as the psql variables admin_user, app_user and db_name, and
-- the passwords in the environment as LMCONMAN_DB_ADMINPW and
-- LMCONMAN_DB_PASSWORD.

\getenv admin_password LMCONMAN_DB_ADMINPW
\getenv app_password LMCONMAN_DB_PASSWORD

CREATE ROLE :"admin_user" LOGIN PASSWORD :'admin_password';
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password';
CREATE DATABASE :"db_name" OWNER :"admin_user";
REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db_name" TO :"app_user";

\connect :"db_name"
ALTER SCHEMA public OWNER TO :"admin_user";
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO :"app_user";
