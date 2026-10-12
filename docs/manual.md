# AIconman manual

AIconman, the AI Connection Manager, is a web interface for the language models you run on your own network. It talks to the model servers you have already set up -- an OpenAI-compatible server such as llama.cpp, or Ollama -- and lets every person in your household chat with them from a browser, each with an account and chats of their own.

**AIconman is for a local network or a VPN, and nothing else.** Do not expose it, or the model servers it talks to, to the internet.

This manual grows with AIconman. So far it covers setting up the Python environment, the configuration, the database and its schema; installing and running AIconman come when there is something to run.

## What you need

- **A machine on your network** to run AIconman, which can reach your model servers. The people using AIconman reach AIconman; only AIconman needs to reach the model servers.
- **Python 3**, with its `venv` module.
- **PostgreSQL 16 or newer**, with its `psql` and `pg_dump` clients.
- **A reverse proxy serving HTTPS**, recommended. Browsers allow the microphone only on pages served over HTTPS or from `localhost`, so without it, speaking to a model is not available; uploading a recording still works.

## Setting up

Run every command below from AIconman's folder, in this order.

### 1. The Python environment

AIconman's Python packages live in a virtual environment of their own, in the folder `.venv`, which git ignores:

```
python3 -m venv .venv
.venv/bin/pip install -r install/requirements.txt
```

`install/requirements.txt` lists every package, pinned to the version AIconman is tested with.

### 2. The configuration files

AIconman's settings and secrets live in the folder `config/`, which git ignores, because what is in it holds secrets. Make the folder, readable by you alone, and copy both templates into it:

```
mkdir -m 700 -p config
cp config.yml.template config/config.yml
cp .env.template config/.env
chmod 600 config/config.yml config/.env
```

- `config/config.yml` holds the settings. *Configuration* below explains each one.
- `config/.env` holds the secrets while you develop AIconman, so that `config/config.yml` holds none and can be read and shared safely. Leave the secret fields in `config/config.yml` empty, and AIconman reads each one from `config/.env`, under the name the template's comment gives.
- **In production, write the secrets in `config/config.yml`, and do not use `config/.env`.**
- **To keep the configuration somewhere else,** set the environment variable `AICONMAN_CONFIG_DIR` to that folder. AIconman and the scripts in `install/` then read `config.yml` and `.env` from there instead of from `config/`.

### 3. Making a secret

AIconman needs several secrets: two database passwords, the secret that signs sign-in cookies, and the key that encrypts your model connections' keys. Make each one with this command, which prints a new random secret of 43 characters every time it runs:

```
openssl rand -base64 32 | sed 's/=*$//'
```

or

```
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Run it once for each of these in `config/.env`, and paste each result after the `=`:

- `AICONMAN_DB_PASSWORD`, the password of the role the backend connects as;
- `AICONMAN_DB_ADMINPW`, the password of the role that owns the database;
- `AICONMAN_STATE_SECRET`, which signs the cookies used while someone signs in;
- `AICONMAN_CONNECTION_KEY`, which encrypts your model connections' keys.

`config/.env` takes one `KEY=value` per line, with no spaces around the `=`. Quotes around a value are removed, and nothing else in the file is interpreted; lines starting with `#` are comments.

`AICONMAN_NEXTCLOUD_CLIENT_ID` and `AICONMAN_NEXTCLOUD_CLIENT_SECRET` stay empty until you set up Nextcloud sign-in; Nextcloud gives you both. In production, the same four secrets go in `config/config.yml` instead, as `db.password`, `db.adminpw`, `auth.state_secret` and `connections.encryption_key`, and Nextcloud's two as `nextcloud.client_id` and `nextcloud.client_secret`.

Never use the same secret twice, and never paste one anywhere but its file.

### 4. The database

AIconman uses a database, `aicm_db` by default, and two PostgreSQL roles:

- **the owner**, `aicm_db_admin` by default, which owns the database and is used to build and update its schema;
- **the app role**, `aicm_db_app` by default, which the running backend connects as. It cannot change accounts, sessions or roles directly; the database's own functions do that, and check the rules as they do.

**Create them** with `install/create_database.sh`, giving it the options `psql` needs to connect as a PostgreSQL superuser:

```
install/create_database.sh -U postgres
```

It takes the names from `config/config.yml` (`db.dbname`, `db.adminuser` and `db.user`), and the two passwords from there too (`db.adminpw` and `db.password`); a password left empty there is taken from `config/.env`. It prints none of them, and passes the passwords to `psql` in its environment, never on the command line. Run it as yourself, not through `sudo -u postgres`: it reads `config/`, which only you can read.

The options are `psql`'s own. If PostgreSQL runs on another machine, add `-h` and its address; it must be the server `db.host` and `db.port` name.

The script creates the two roles and the empty database, owned by the owner role, which only the two roles may connect to. If a name or a password is empty, it stops before connecting, and says which.

It is meant to run once. Run again, it stops at the first role that already exists.

**Check that the app role can connect:**

```
psql -h localhost -U aicm_db_app -d aicm_db -c 'SELECT current_user;'
```

It asks for the app role's password, and answers `aicm_db_app`.

### 5. The schema

**Build the schema** in the new database with `install/build_schema.sh`, which connects as the owner role, to `db.host` and `db.port`:

```
install/build_schema.sh --rebuild
```

It destroys everything in the database's schema before building it again, so it never does anything without `--rebuild`, and it asks first:

1. It says which database it is about to change, and how many tables it has.
2. It dumps the whole database into the folder `db/backups/` inside `storage.root_path`, readable by you alone, and stops if the dump fails. A dump can be restored with `pg_restore`.
3. It asks you to type the database's name, and stops unless it matches. In a script, give the name with `--confirm-db NAME` instead.
4. It builds the schema and seeds it in one transaction, so if anything fails, the schema stays as it was.

Seeding adds what an installation needs: Nextcloud as a way to sign in, and the switch for self sign-up, starting from `auth.allow_auto_signup`. To add what is missing without rebuilding, run `install/build_schema.sh --seed`; it leaves everything already there as it is, so a setting the admin has changed keeps its value.

The owner's password is `db.adminpw` in `config/config.yml`, or `AICONMAN_DB_ADMINPW` in `config/.env`.

## Configuration

`config/config.yml` explains each setting where it is set. In short:

- **server:** the address and port the backend listens on, behind your reverse proxy (8642 by default); and `public_url`, the address people type to reach AIconman.
- **db:** where PostgreSQL is, the database's name (`dbname`), the app role (`user`, `password`), and the owner (`adminuser`, `adminpw`). The owner is the database's owner, not an AIconman admin account.
- **storage:** `root_path`, the folder where people's files are kept: attached images, recordings, transcripts and exports. Each account gets a folder inside it, named by the account's id, and the dumps `install/build_schema.sh` makes go into `db/backups/` inside it. The folder must exist, and the user AIconman runs as must be able to write to it.
- **auth:**
  - `password_login` and `nextcloud_login` turn each way of signing in on or off. If both are off, password sign-in is turned on anyway, so that nobody is locked out. With Nextcloud sign-in on, password sign-in may be turned off.
  - `allow_auto_signup` is whether people may create their own accounts. It is only the starting value: once AIconman runs, the admin changes it in Administration.
  - `state_secret` signs the short-lived cookies used while someone signs in.
  - the session cookie's name, whether it is sent over HTTPS only (it should be), and how long a session lasts: 30 days without use, and 90 days in any case, by default.
- **nextcloud:** for signing in with Nextcloud. `instance_address` is your Nextcloud's address, as people's browsers reach it. The three sign-in addresses, `authorize_url`, `token_url` and `profile_url`, are made from it, and the template leaves them commented out; uncomment one only to change it. Browsers open `authorize_url`, and AIconman's machine calls the other two, so if that machine reaches your Nextcloud at a different address, set those two. If your Nextcloud is not set up with pretty URLs, uncomment `authorize_url` and `token_url` and add `/index.php` after your Nextcloud's address in both. `client_id` and `client_secret` come from registering AIconman as an OAuth 2.0 client in your Nextcloud. `redirect_uri`, the address Nextcloud sends people back to, is `server.public_url` followed by `/auth/nextcloud/callback`, and is the redirect address to register there; the template leaves it commented out, and if you uncomment it to change it, it must match the registered address character for character. This manual will describe the registration when Nextcloud sign-in is built.
- **connections:** `encryption_key` encrypts the keys of your model connections in the database, so that a dump or backup of the database alone does not hold them. If you lose it, every connection's key has to be entered again.
