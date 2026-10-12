# The database

**Written 2026-10-11, against the tree at `85b56d4`**, which Z committed as *"Design is done"*. Nothing had been built.

This is the fourth part of the design: what the database holds, and which rules it enforces. Z: *"Next database."* The agent listed the tables it took to follow from the design so far and six questions that would change them; this note records the list as the agent's, Z's answers in Z's words, and the draft that follows from them.

## Z's answers

- **A table for each person's files.** Z: *"Add also files to the list of tables for each user's files."*
- **The accounts schema of Z's other project may be read**, scoped to accounts, sessions and roles. Z: *"Yes. It is simplistic compared to this. ipynb is the original file I was working witth."*
- **Connection keys are encrypted with a key from the server's configuration**, so that a dump or backup of the database alone does not hold them. Z: *"Yes. We will need a .gitignored config/ folder and a config.yml file inside it to set up everything."*
- **Files are kept on disk, not in the database**, under a folder the configuration sets, with a folder for each person named by their username. Z: *"I say keep files on disk, set in config, each user gets a folder with their usernames (username unique)"*.
- **Regenerating a reply, or editing and resending a message, keeps the earlier version.** Z: *"keep earlier version."*
- **Transcripts are saved**, and each person gets a way to manage their files. Z: *"Save them, we'll give the user a way to manage their files."*
- **PostgreSQL only, for now.** The agent pointed out that rules enforced inside the database must be written again for each database added later. Z: *"I understand. We will start with Postgres for now."*

## What was read from Z's other project

With Z's go-ahead, the agent listed the tracked files of that project's database folder by name, and read three cells of its accounts notebook: its description, its schema, and its note on an admin linking an account. It did not open the notebook's first code cell, which a setup notebook often fills with connection details, and it masked any password literal in the schema before reading. That project is Z's own work, so the rule on other people's code does not reach it.

What it has, as the agent found it:

- **Two database roles.** An owner role runs the accounts functions; the application's role may read only its own rows, through row-level security, and may change nothing in the accounts tables.
- **A table of sign-in providers**, seeded with Nextcloud; **a table of identities**, where one provider's user maps to one account and an account has at most one identity per provider, both held by unique keys; and **a table of sessions**, storing only the SHA-256 of each session's token, with an expiry that slides with use, a hard limit, and revocation.
- **Every accounts action is a database function** that runs with the owner's rights and a fixed search path, and that no other role may call: signing in, signing up, linking and relinking an identity, and creating, checking and revoking a session.
- **It signs in through Nextcloud only.** The account table itself, the system roles, and the rules about admins are defined elsewhere in that project's schema, and were not read.

## The draft

The agent's draft, after Z's answers. Following Z's other project, the application connects as a role that cannot change accounts, sessions or roles directly; every change to them goes through a database function that checks the rules.

| Table | Holds | Rules the database enforces |
|---|---|---|
| **accounts** | username, unique and changeable; the password hash, empty for an account made through Nextcloud; the role, admin or member; the status, active or deactivated; whether the password must be changed; the theme | the first human account becomes the admin; only an admin can give up their own admin role, and not as the only admin; the only admin cannot be deactivated or deleted; deleting an account deletes its conversations and files |
| **providers** | the ways to sign in besides a password, starting with Nextcloud | |
| **identities** | an account's link to a provider: the provider's own, unchanging id for the user, and when it was last used | one identity per provider per account, and one account per identity; removing an account's last way to sign in is refused |
| **sessions** | the SHA-256 of each session's token, its account, when it was last used, its sliding expiry and hard limit, and whether it was revoked | *Sign out everywhere else* revokes every session of the account but the current one |
| **settings** | switches for the whole household, starting with self sign-up, on by default | checked again at the moment an account is created |
| **connections** | name, base URL, the protocol chosen and the one detected, the key encrypted, and the last check and its result | changed only by an admin |
| **models** | per connection: the model's name, and what it can do and its context window, each as the server reports it and as the admin sets it | |
| **conversations** | its owner, title, current model, system prompt and output limit | belongs to one account |
| **messages** | its conversation, the message it answers or follows, its role, text and reasoning, the model that wrote it, its token counts, and its state: complete, stopped or failed | earlier versions are kept, below |
| **files** | its owner, its kind (an attached image, an uploaded audio file, a transcript, an export), its path under the owner's folder, its size and type, and when it was made | a path stays inside its owner's folder |

**Earlier versions, as a tree.** Each message records the message before it. Regenerating a reply adds a second reply to the same message; editing and resending adds a second message after the same reply. A conversation shows one path through the tree, the newest version at each step unless the person picks an earlier one, and nothing is deleted.

**What stays outside the database:** the password rules, since the database only ever sees the hash, which the backend checks before hashing; and the files themselves.

**The configuration,** `config/config.yml`, ignored by git: the database connection, the folder for files, the key that encrypts connection keys, the session timeouts, and Nextcloud's sign-in settings.

## Open, raised with Z

- **A username names a folder, and a username can change.** Changing it would then mean renaming the folder on disk in step with the database, which must not leave the two out of step if either fails. The alternative is a folder named by the account's own number, which never changes.
- **What a username may contain**, since it names a folder: the characters allowed, and whether two names differing only in case are the same name.
- **The account table and the admin rules of Z's other project** are not in the notebook that was read. Reading them would mean opening that project's schema, scoped to the account table, its roles and the rules about admins, once Z names or clears the file.

## Added later on 2026-10-11, against `85b56d4`: folders, names, and the rest of the accounts schema

**Z's answers:**

1. **Each account gets a unique random string of eight characters, and its folder is named by it.** Z: *"Let's give each account a unique random string of 8 characters, and name the folder with it. User can see it, cannot change it."* So a username can change without anything on disk changing.
2. **A display name, besides the username; and a username is lowercase letters, digits, dashes and underscores, with no dots.** Z: *"We need a display name, besides username. username lowercase, digits, dash, and underscore. No dots."*
3. **The rest of the accounts schema of Z's other project may be read:** Z: *"Start with schema_state, when you find what you need look at build_schema for the shape and rules."*

**What the read found.** In that project's schema description the agent searched by name and read three sections: the account table, its system roles, and its table of household settings. The description lists tables only, with no triggers or functions, so for the rules it searched that project's schema builder and read the account table's definition, the block of admin functions, and the step that makes an installation's first rows. It skipped any line holding a password literal.

- **The account table** has a username, unique; a display name, optional; a kind, which is human, machine or system; a system role, which is admin or member; whether it is active; and when it was made. A person's theme lives with their profile, as *system*, *light* or *dark*.
- **Household settings** are a table of keys and values, with who changed one and when. The keys seeded at installation are the only ones allowed: a function refuses a key that was not seeded, so a mistyped key cannot quietly read as unset.
- **The admin functions** each refuse a caller who is not an active admin, and that check reads who the caller is from the database session itself. **Changing an account's role** keeps a last-admin guard: it refuses to leave no active human admin, and does not count the project's machine account. **Deactivating an account** refuses to deactivate oneself, keeps the same guard, and revokes the account's sessions.
- **Two of AIconman's rules are not there.** In that project any admin may change another admin's role, where Z's rule for AIconman is that only an admin can give up their own. And its first admin is a machine account seeded at installation, where AIconman's first human account becomes the admin. Both are written fresh for AIconman.

**The draft, changed:**

- **accounts** gains an **account id** of eight random characters, lowercase letters and digits, made by the database when the account is created, unique, shown in profile settings, and refused by the database if anything tries to change it; and a **display name**, any text, which need not be unique. A **username** is lowercase letters, digits, dashes and underscores, from 1 to 50 characters, the length the sign-up page of Z's other project allows. Being lowercase only, two usernames can never differ by case alone.
- **files** live under the configured folder, in a folder named by the account id.
- **settings** follow Z's other project: seeded keys only, and every change recorded with who made it and when.
- **The admin rules** follow the functions above, with Z's two rules added: changing one's own role is the only role change that can remove an admin, and the first human account becomes the admin.
- **Kinds of account.** AIconman has only people's accounts for now, so the draft has no kind column, and *"the first human user"* is simply the first account. A kind can be added when there is a second kind.

## Added later on 2026-10-11, against `85b56d4`: a correction, and the destructive pipeline

**A correction.** The section above says the first human account becoming the admin is not in Z's other project. That is wrong. Asked to look at its schema builder's destructive rebuild, the agent read the builder's description, its two entry points and its confirmation step, and the docstring of its schema-only build says the first person to sign in after a rebuild is the first human, and that its sign-up function makes them the admin. The sign-up function the agent had read was in the older notebook, which assigns the member role; the builder's version was not read. The rule that only an admin can give up their own admin role is, as far as was read, still new for AIconman.

**What the destructive rebuild of Z's other project does,** from the same read: it is a separate, named option, and the builder does nothing at all without one. Before dropping anything it prints what it is about to destroy -- the database, the file store, and counts of tables, people and files -- takes a dump of the database, and refuses to go on if the dump fails. It then requires the database's name: typed at a prompt, or given as an option for a script. A bare *yes* is not enough, so that a command copied from one machine's notes cannot destroy another machine's database. Seeding an installation is a second option, which can be run any number of times.

## Added later on 2026-10-11, against `85b56d4`: two roles, PostgreSQL, the configuration, and the Python environment

**Two roles.** Z asked whether AIconman needs two database roles. The agent's answer was yes: the rules live in database functions, and they hold only if the running backend cannot write to the tables directly, which a table's owner always can; and the owner's password is needed only to build and update the schema. Z: *"Two users rule the real question is "Can it apply to mariadb?""* The agent's answer, from its recollection and to be checked against MariaDB's documentation through the reading log if MariaDB is ever supported: MariaDB has users with grants down to tables and columns, and procedures, functions and views that run with their definer's rights, so the split carries over; but it has no row-level security, so each person reading only their own rows would come from views or procedures filtering on the acting account, and every function would be written again. Z: *"OK! You're right. I am also thinking that postgres might be the place we want to keep this project in."*

**The configuration takes the shape of Z's other project's.** Z showed that project's `config.yml` (its values are Z's own and stay out of this repository; only its shape was used) and wrote: *"[Z's other project's] shape is better for database. and NC needs some help here. Let's rename files as storage for project consistency."* The agent merged the two, and Z: *"Apply this to template."* What came of it, in `config.yml.template`:

- **db:** `host`, `port`, `dbname`, `user` and `password` for the app role, `adminuser` and `adminpw` for the owner, as in Z's other project. Its comment says the owner is the database's owner, not an AIconman admin account.
- **storage:** `root_path`, renamed from *files*.
- **nextcloud:** `instance_address`, with the three sign-in addresses Z's other project names (authorize, token and profile) made from it when left empty; `client_id`, `client_secret`, and `redirect_uri` written out, since it must match the address registered in Nextcloud character for character. That project's provider code was left out, since it names a database row.
- **auth:** the two sign-in switches, `password_login` and `nextcloud_login`; `allow_auto_signup` as the starting value, which the admin changes at runtime, the way Z's other project treats its own; `state_secret`; the cookie's name and whether it is HTTPS-only; and session lengths of 30 days idle and 90 days at most, from Z's other project's values.
- **connections:** `encryption_key`.
- **Secrets** are read from `.env` while developing, as `AICONMAN_DB_PASSWORD`, `AICONMAN_DB_ADMINPW`, `AICONMAN_STATE_SECRET`, `AICONMAN_CONNECTION_KEY` and `AICONMAN_NEXTCLOUD_CLIENT_SECRET`. `.env` was regenerated for the new names, its values unprinted, and `db/create_database.sql` reads the owner's password as `AICONMAN_DB_ADMINPW`.

**The Python environment.** Z: *"I approve PyYAML. We need to create a python virtual environment to install all packages that the server needs etc. It should be created at .venv and .venv should be gitignored. We need an install folder to put what's needed inside. python requirements file can go there, along with other install scripts we will be creating."* `.venv` was already ignored by the repository's Python `.gitignore`. It was created with the machine's Python 3.14.7, and PyYAML 6.0.3 installed into it, whose package metadata gives its license as MIT. `install/requirements.txt` pins it; installing from that file into `.venv` was run and succeeded, and PyYAML loads from `.venv`.

## Added later on 2026-10-11, against `85b56d4`: default names, and where `.env` lives

Z: *"I will create the databases. But we're not there yet."* And:

- **Default names:** the database is `aicm_db`, the owner role `aicm_db_admin` and the app role `aicm_db_app`, in `config.yml.template` and in `db/create_database.sql`. Z: *"default db name: aicm_db roles let's rename to aicm_db_admin aicm_db_app for defaults."*
- **`auth` comes before `nextcloud`** in the template. Z: *"Let's move auth above nextcloud in config.yml"*.
- **The development secrets live in `config/.env`**, beside `config/config.yml`, so that everything local and secret is in the one folder git ignores. Z: *"manual says cp .env.template .env but does not mention cp config.yml.template config/config.yml also let's copy .env to config/ and keep it there too."* The agent read this as `config/.env` replacing `.env` at the root; `.env.template` stays at the root, beside `config.yml.template`. The existing `.env` was moved without being read, `config/` was made readable by Z alone, and `config/.env` was then regenerated from the changed template, its values unprinted, so that its comments say where it lives.
- **The manual's setup is four steps in order:** the Python environment; the configuration files, both templates copied into `config/` together; making a secret; and the database. Making a secret has a section of its own with the command, since the person setting AIconman up runs it once for each secret. Z: *"Let's add a command to generate a secure password in the manual, user will need to do this a few times."*

## Added 2026-10-12, against `85b56d4`: Nextcloud's addresses, and the script that creates the database

- **The client id is a development secret too**, read from `config/.env` as `AICONMAN_NEXTCLOUD_CLIENT_ID`. Z: *"Let's add Nextcloud client ID to .env file too."*
- **Nextcloud's three sign-in addresses are commented out** in `config.yml.template`, each with its full default written in, rather than set to `""`. Z: *"If the user does not need to set them, they should be commented out, it is confusing as it stands."*
- **`instance_address` is the address people's browsers reach Nextcloud at.** The template had said it was the address AIconman's machine reaches it at, which the agent had written; but the browser opens the authorize address, and only the token and profile addresses are called by AIconman's machine. The two are the same in the usual setup. Where they differ, the token and profile addresses are set by hand. Found by the agent when Z asked whether the handling of the instance address was right.
- **`redirect_uri` is made from `server.public_url`**, as `public_url` followed by `/auth/nextcloud/callback`, and is commented out in the template like the three above. The agent raised that the same address was otherwise typed twice; Z: *"let's make redirect uri follow public_uri"*.
- **Raised by the agent, open:** the three default paths came from Z's other project's configuration and have no `/index.php/` in them. From the agent's memory, not from a read: Nextcloud serves its apps only under `/index.php/` unless its web server rewrites addresses, so on an instance without that the defaults would fail. Settling it needs Nextcloud's own documentation, through the reading log.
- **The database is created by `install/create_database.sh`**, which reads the names and both passwords from `config/config.yml`, takes a password left empty there from `config/.env`, stops in bash if a name or a password is still empty, and runs `db/create_database.sql` with `psql`, handing on its own arguments. Z: *"I think a better way to do it is to run these with a bash script?"*, and on reading from both files: *"I think both config/.env and config/config.yml (so it can be used when the user is installing the app)"*. It is the first part of the pipeline in *a correction, and the destructive pipeline* above; the rebuild waits for the schema.
- **`db/create_database.sql` no longer checks the passwords or defaults the names.** Its check failed on every run (`platform-traps.md`, 2026-10-12). Its default names repeated the template's; the agent removed them with the check, since the script always passes the names, so a run of the SQL by hand without them fails at the first statement.

The script was checked without PostgreSQL, in scratch copies with made-up configurations and a stand-in `psql` that records its arguments and the two password variables: passwords from `config/config.yml`, from `config/.env`, and one from each; quotes, a dollar sign and a backslash in a password; an empty password, an empty name, no `config/config.yml`, a `config/config.yml` that is not valid YAML, and passwords only in the calling shell's environment, each stopping before `psql` with a message saying what was wrong; and the real templates, filled with made-up passwords. ShellCheck 0.11.0, installed into `.venv` at Z's word (*"Install linter on the .venv add it to requirements. We will have to install a ton of tools anyway."*), reports nothing on it. Its run against PostgreSQL is Z's.

## Added later on 2026-10-12, against `85b56d4`: the scratch database, `index.php`, and the development tools

- **The scratch database is `aicm_scratch_db`, with roles of its own**, `aicm_scratch_db_admin` and `aicm_scratch_db_app`, and its configuration in `.tmp/scratch/config/`, which git ignores; Z prepared the folder. Z: *"I prepared a folder to create aicm_scratch_db under .tmp/scratch if you approve I'll create it. It will be your scratchpad."* The name replaces `aicm_db_scratch`, recorded on 2026-10-11. The agent had raised separate roles on 2026-10-11, and they were not taken up then. When Z prepared the folder, the agent pointed out that roles belong to the whole PostgreSQL server, so the scratch configuration could not reuse `aicm_db`'s role names: the script would stop at its first `CREATE ROLE`. Z gave the names above. The folder holds copies of `install/` and `db/` and has no `.venv`, which the copied script needs.
- **No `/index.php/` in AIconman's defaults.** R-017 found that Nextcloud's manual gives the authorize and token addresses without it, and says to include it where pretty URLs are not configured. Z: *"No index.php on our side. If people don't use pretty url, they can add it at the end of their URL, we should not even bother. We can make a tiny note in the manual but it doesn't go into template or anywhere else. Let's not waste more time on this,"* The manual's note names the two addresses the manual's own note covers, since R-017 says nothing about the profile address.
- **Development tools have an environment of their own.** Z: *"Let's make a requirements file for development tools and create dev/.venv for this purpose."* The agent put the file at `dev/requirements.txt`, beside `dev/.venv`, and `.venv` stays what `install/requirements.txt` lists. ShellCheck was moved there: taken out of `install/requirements.txt`, uninstalled from `.venv`, and installed into `dev/.venv`, made with Python 3.14.7. From there it reports nothing on `install/create_database.sh`, and it fails a control script with an unquoted variable. The section above says ShellCheck was installed into `.venv`; this replaces that.
