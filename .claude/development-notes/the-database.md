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

## Added 2026-10-12, against `b5c2c93`: the plan for building it, and the rebuild

Z: *"We will start working database schema."* The agent proposed building it in four stages, each tested against `aicm_scratch_db` and then stopped for Z's review: the rebuild; accounts, settings, sessions, providers and identities; connections and models; and conversations, messages and files. It listed what it would decide unless Z objected, and asked three questions.

**Z's answers:**

- **Which schema.** The agent had proposed a schema of its own, `aiconman`, which a rebuild would drop and build again, never the database. Z: *"what does this mean, why did we create other databases?"* A database is what `install/create_database.sh` makes, with its owner, and who may connect to it. A schema is a namespace inside a database, holding its tables and functions, and every database starts with one, `public`. Both databases stay: the rebuild empties and rebuilds what is inside one, and never drops the database itself, which would take a superuser or the right to create databases, and the owner role has neither. A schema of its own would only add a name in a database that holds nothing but AIconman, and `db/create_database.sql` already hands `public` to the owner role. So the agent dropped its proposal, and AIconman uses `public`.
- **PostgreSQL 16 and newer.** Z: *"We should try to make it PostgreSQL 16+ compatible at least (I think it is Ubuntu 24.04 standard)"*. This machine runs 18.6, and the agent did not check what Ubuntu 24.04 ships. Nothing added after 16 is used, which stays unproven until the schema runs on a 16 server.
- **The backend sends the SHA-256 of a session token, never the token.** Z: *"SHA-256 is correct"*.
- **The tests are in `tests/`.** Z: *"tests should have their own folder tests/ and db tests can go under tests/db/ plain SQL is fine."* The tests of the install scripts went to `tests/install/`.
- **Every function that acts for a person takes the hash of their session token**, and the database checks the session on every call. Z: *"(a) is correct"*. So the app role gets no access to any table, only the right to call functions, and the draft's row-level security for reading one's own rows is not needed.
- **Dumps go into `db/backups/` inside the storage folder.** Z: *"files_path/db/backups/"*. The agent read *files_path* as `storage.root_path`. An account's folder is named by eight letters and digits, so a folder named `db` cannot be one.
- **The configuration folder can be named by `AICONMAN_CONFIG_DIR`.** Z: *"AICONMAN_CONFIG_DIR is fine. yml should also take it."* The agent read the second sentence as `config.yml` being found through it too, with `.env`, and both templates now say so.
- **The scratch folder is the agent's.** Z: *"My copies in .tmp/scratch/ and the aicm_scratch_db are for you to use and test."* The agent runs the repository's scripts with `AICONMAN_CONFIG_DIR=.tmp/scratch/config`, so the copies of `install/` and `db/` there are not used.

**The first stage, the rebuild:**

- `install/common.sh` finds the configuration folder, reads settings from `config.yml` through PyYAML, fills empty secrets from `.env`, and stops naming every empty setting. `install/create_database.sh` now uses it.
- `install/build_schema.sh --rebuild` says what it is about to destroy, dumps the database as the owner role into `<storage.root_path>/db/backups/`, under a name that cannot overwrite another dump, stops if the dump fails, requires the database's name typed or given with `--confirm-db`, and runs `db/build_schema.sql` in one transaction. Without `--rebuild` it does nothing. Seeding waits for the accounts stage, with the settings it seeds.
- `db/build_schema.sql` drops the schema `public` and creates it again, and lets the app role use it. The tables come in the next stages.

**How it was checked.** `tests/install/test_create_database.sh` runs the earlier ten cases through `AICONMAN_CONFIG_DIR`, without PostgreSQL, 23 checks; a copy of the tree with `fill_from_env` broken fails one of them. `tests/install/test_build_schema.sh` runs against `aicm_scratch_db`, 28 checks: no option and an unknown option do nothing; no terminal without `--confirm-db`, the wrong name, and a dump that fails each stop with the schema untouched; a build that fails partway rolls back its drop; and the right name rebuilds, after a dump that holds the schema as it was, readable by its owner only, with `public` the owner's, the app role able to use it but not create in it, and `PUBLIC` given nothing. Its first run failed one check: the dumps were named to the second, and the cases ran within one second, so a later dump overwrote an earlier one. Two rebuilds in one second would have lost the dump of the state before the first; each dump is now created under a unique name. ShellCheck reports nothing on the scripts or the tests.

**A slip.** While fixing the dump's name, the agent ran a `sed -i` on `install/build_schema.sh` whose replacement was the matched line itself. It changed nothing, but it rewrote the file by a script, against the rule to change files with the Edit tool.

## Added later on 2026-10-12, against `b5c2c93`: the second stage, accounts

Z: *"OK! Go ahead."* Built: `db/accounts.sql`, included by `db/build_schema.sql`; `db/seed.sql`; `install/build_schema.sh --seed`, with a rebuild now building and seeding in one transaction; and the schema's tests in `tests/db/`.

**A correction of the agent's own claim.** Asked to choose how the database knows who is acting, the agent said that under (a) *"the backend can't act as anyone without their token."* That holds only if the database decides whether a password is right. If the backend checked passwords and then asked the database for a session, a backend that was broken into could make a session for anyone. So the database checks: the backend asks for an account's salt and hashing parameters with `password_salt()`, hashes the password typed, and the database compares that with the hash it keeps, which the app role can never read. Sign-in through Nextcloud still rests on the backend's word about who Nextcloud verified, which the database has no way to check; and a backend that was broken into would see the passwords typed while it was.

**What the database enforces, from Z's decisions:** the first account is the admin; an account id is eight lowercase letters and digits, made by the database and refused any change, even by the owner role; a username is 1 to 50 lowercase letters, digits, dashes and underscores, and unique; self sign-up is checked at the moment an account is created, by password or through Nextcloud; the admin creates accounts whether or not sign-up is open, with a first password that must be changed; a reset password must be changed at the next sign-in; only an admin gives up their own admin role, and the only active admin is refused; every account can have a password and Nextcloud, links Nextcloud itself, and cannot unlink its last way to sign in; a person changes their own username and deletes their own account; settings are the seeded keys only, and record who changed them.

**What the agent decided, for Z to keep or change:**

- **A refusal is SQLSTATE `AI001` with a key as its message**, such as `last_admin`. Where a constraint refuses, the constraint is named for the key, so the rule and its key are written once.
- **No function takes the admin role from anyone else.** Making an admin is `admin_make_admin`; giving it up is `give_up_admin`, for oneself only.
- **An admin cannot deactivate or delete another admin**, nor themselves through administration. The agent's reading of Z's rule that only an admin gives up their own role: removing an admin's account removes the role too. An admin **can** reset another admin's password, so that an admin who forgot theirs can be let back in.
- **A display name** is 1 to 100 characters with no control characters, trimmed, and is the username when none is given; sign-up has no field for it in the design.
- **The theme** is `device`, which follows the device and is the default, `dark`, `light`, `dark-hc` or `light-hc`.
- **An account that must change its password can do nothing else** until it does, besides checking its session and signing out.
- **Changing one's password revokes one's other sessions**; a reset and a deactivation revoke all of the account's sessions.
- **An account's sessions that can no longer be used are deleted at its next sign-in.** There is no sweep of the whole table.
- **Self sign-up applies to the first account too**, as the template's comment says (*"Leave this on for first user."*). Seeding it closed on an empty database leaves no way to make the first account but changing the setting in the database.
- **`password_salt()` tells whether a username exists and has a password.** Sign-up says when a username is taken anyway, so the database does not hide it.

**How it was checked.** `tests/db/run.sh` rebuilds the schema on `aicm_scratch_db` without a dump and runs two files: `accounts.sql`, 108 checks as the owner role in a transaction that is rolled back, which moves sessions' times by hand to test idle timeouts and expiry; and `app_role.sql`, 6 checks as the app role, that it may call exactly the 25 functions granted to it, cannot read a table or call a helper, and that `PUBLIC` may call nothing. Two copies of the schema with a rule broken each fail the check for that rule: comparing the password's hash with `<>`, which lets a missing hash through, and the last-admin guard off by one. `tests/install/test_build_schema.sh` gained seeding: 41 checks.

**What the tests found.** An empty username was refused as `display_name_invalid`: the display name defaults to the username, and PostgreSQL checks constraints in alphabetical order, so the display name's check came first. The username's rule is now one function, used by the table's constraint and checked first when an account is made. And the listing's order was tested wrongly: inside one transaction every account is made at the same moment, so the test now sets an earlier time on one account.

**Not checked:** two sign-ups at once on an empty database, and two admins giving up the role at once. The functions lock for both, but the tests run in one session and cannot show it. And PostgreSQL 16, as above.

## Added later on 2026-10-12, against `b2b18b1`: the third stage, connections and models

Z committed the accounts stage as `b2b18b1`: *"Looks good so far. Committed. Connections and models next."* Built: `db/connections.sql`, included by `db/build_schema.sql` after `db/accounts.sql`, and its tests in `tests/db/connections.sql`.

**From the design:** connections belong to the household, and only an admin adds, changes, checks or removes one (`the-interface.md`); a connection is a name, a base URL, an optional key, and a protocol that is detected when left empty or chosen, OpenAI-compatible or Ollama (`the-backbone.md`); a key can be replaced and never read back in the interface; each model has what it can do, chat, images and speech, and a context window, as the server reports them and as the admin sets them, and the admin's value wins; removing a connection removes its models.

**What the agent decided, for Z to keep or change:**

- **A connection's name** is unique, 1 to 100 characters with no control characters, and trimmed. **Its base URL** starts with `http://` or `https://`, has no spaces, and is at most 2000 characters; it is stored as typed.
- **The protocols are `openai` and `ollama`.** llama.cpp speaks the first. The protocol the admin chose wins over the one detected; with neither, a model cannot be used yet.
- **The key** is stored as the bytes the backend encrypted, and comes back out only through two functions the backend calls to reach a server: `model_access`, for any signed-in account using a model, and `admin_connection_access`, for the admin's check. The admin's listing says only whether there is one. The admin can remove a key.
- **A model the last check did not find is kept, marked not found,** with its id and the admin's values, so that it comes back as it was when a check finds it again. Members see only the models found; nothing deletes a model but removing its connection.
- **Unknown stays unknown.** What a model can do and its window are NULL when neither the server nor the admin gave them. Whether the model picker shows a model whose chat is unknown is the interface's decision, not the database's.
- **The window stored is whatever number the backend reports.** Which number that is for Ollama and for llama.cpp is still gaps 1 and 2 in `the-backbone.md`.
- **A failed check records its error only,** and leaves the models and the protocol detected as they were.
- **Only an admin's session can record a check.** Under (a), every function acts for a person, so the backend cannot refresh the model lists on its own, at startup or on a timer, without an admin signed in.

**Raised for the backend:** the Python standard library has no cipher, so encrypting the keys will take a library Z approves by name.

**How it was checked.** `tests/db/connections.sql` has 57 checks: the admin adds a connection and members cannot; each refusal of a name, a URL, a protocol and a key; a check records the protocol, the result and the models; members see the models with what each can do; the admin's values win and both are kept; a model the next check does not find disappears for members and comes back with its id and the admin's values; a failed check changes only the error; nine malformed checks are refused and change nothing; `model_access` gives what the backend needs, takes the chosen protocol over the detected one, and refuses a model not found, an unknown one, and one with no protocol; keys are replaced and removed; and removing a connection removes its models. `tests/db/app_role.sql` now expects 36 functions. Three copies of the schema with a rule broken each fail the check for that rule: models not found shown to members, the server's window winning over the admin's, and a member recording a check. Every check passed on the first run.

## Added later on 2026-10-12, against `b2b18b1`: the scheduled refresh, and the backend's libraries

**The refresh.** Z, on the consequence of (a) above: *"Let's set up a cronjob (every 30 mins), and put a button on the admin panel for faster refresh."* (`the-interface.md`). The job runs with no session, so the database gained the only two functions of the connections that act for no one: `refresh_targets()`, every connection with its base URL, protocols and key, still encrypted; and `refresh_record_check()`, which records a check exactly as the admin's does. Both now go through one helper, `_record_check`. The job itself and the admin's button wait for the backend. A broken backend could now record checks and read every connection's encrypted key without a session; it could already read keys through `model_access` with any member's session, and they are useless without `connections.encryption_key`, which the backend holds anyway.

**Checked:** five more checks in `tests/db/connections.sql`, 62 in all, and `tests/db/app_role.sql` now expects 38 functions; 176 checks pass. A copy whose `refresh_targets` gives no key fails the check for it.

**The libraries.** Z: *"Add libraries that are needed to requirements.txt I will review and raise questions if I have them. This should not be a blocker for the work."* The agent added the backend's: FastAPI, approved on 2026-10-11; Uvicorn, to run it; python-multipart, which FastAPI needs for form fields and uploaded files, the audio and images among them; HTTPX, for the requests to the model servers; psycopg, for PostgreSQL; and cryptography, for the connections' keys. Each was pinned to its newest version on the day, and `install/requirements.txt` pins every package they bring with them too, so that an installation gets exactly the versions tested. A fresh environment built from the file matched `.venv` package for package, and every one imports. The licenses, from each package's own metadata, are in `SOURCES.md`; none conflicts with GPL-3.0, as the agent reads them, psycopg's LGPL-3.0 and certifi's MPL-2.0 included.

**Raised for Z's review:** FastAPI 0.143.0 requires `opentelemetry-api`, a library for recording telemetry. From the agent's knowledge, not from a read, the API package alone records and sends nothing unless an OpenTelemetry SDK and an exporter are installed and set up, and neither is. Confirming that would be a read for the reading log.

**A slip.** The agent rewrote `install/requirements.txt` whole with the Write tool instead of changing it with Edit.

## Added later on 2026-10-12, against `3d1cca2`: the fourth stage, conversations, messages and files

Z committed the connections, the refresh and the libraries as `3d1cca2`, and: *"Last database stage. Go ahead!"* Built: `db/conversations.sql`, included by `db/build_schema.sql` after `db/connections.sql`, and its tests in `tests/db/conversations.sql`.

**From the design and Z's answers:** a conversation belongs to one account, with a title, a model, a system prompt and an output limit (`the-interface.md`); a reply is labeled with its model, and the model can be switched mid-conversation; removing a connection leaves conversations with their messages, able to go on with another model; regenerating a reply and editing a message keep the earlier version, as a tree, and the conversation shows one path, the newest version at each step unless the person picks an earlier one, with nothing deleted (Z: *"keep earlier version."*); files are kept on disk, in a folder named by the account's id, with a table of their records, and transcripts are saved (Z: *"Save them, we'll give the user a way to manage their files."*).

**What the agent decided, for Z to keep or change:**

- **No one reads another person's conversations or files**, the admin included: a conversation or file of someone else is refused exactly as one that does not exist. The admin interface's design covers users and connections only.
- **A message is a person's or a model's.** The system prompt is the conversation's, not a message. A person's message follows a reply, or opens the conversation; a reply follows a person's message; the database refuses anything else. A person's message needs text, a file, or both.
- **The path shown is kept as the conversation's leaf**, the newest message added. Choosing a version moves the leaf to the newest message below the one chosen, step by step. "Newest" is the order the messages were added in. Each message on the path says which version it is in its place and how many there are, for the interface's arrows.
- **A reply is stored once it ends**: complete, stopped or failed, a failed one with its error. There is no state for a reply still streaming, so a reply in progress is not in the database, and a page reloaded mid-reply does not find it.
- **A reply keeps its model's and connection's names** beside the model's id, which becomes NULL when the model's connection is removed. A reply with no model id keeps the name it is given, which is how an imported reply would come in. Import itself, and the export format it reads, are not designed: whether an import keeps the original times, for one, is open.
- **A conversation's title may be empty**, for the interface to show as it chooses, and is at most 200 characters. An output limit of NULL leaves the limit to the server. Nothing limits the length of a message or a system prompt.
- **A file's kind** is image, audio, transcript or export. **Its path** is one or more parts of letters, digits, dots, dashes and underscores, separated by slashes, with no part `.` or `..`, so it cannot leave the account's folder; it is unique within the account. Its name is the one it was given, up to 255 characters.
- **Deleting a file detaches it from its messages, which stay.** Deleting a conversation keeps the files that were attached to it, among the person's files. Deleting an account deletes its conversations and files; the database keeps no file on disk, so the backend deletes the account's folder, and a file's own, from the id and the path these functions return.
- **Messages are never deleted** except with their conversation.

**How it was checked.** `tests/db/conversations.sql` has 80 checks: starting, listing, renaming and setting a conversation; another person and the admin refused every way into it; the tree, with regenerating, editing, the first message edited, choosing versions, and the version numbers, and nothing deleted; each refused parent; stopped, failed and imported replies and each refused reply; files recorded, each refused path, kind, type, size and name, the same path in two accounts' folders, files attached in order, someone else's file and the same file twice refused, and a file deleted and detached; a connection removed, with its replies keeping their names and the conversation picking another model; and deleting a conversation and an account. `tests/db/app_role.sql` now expects 53 functions. All 256 checks passed on the first run. Four copies of the schema with a rule broken each fail the check for that rule: the oldest version shown below a choice instead of the newest, a path allowed to climb out with `..`, a conversation reachable without its owner's session, and a reply allowed without a model name.

**Found before the first run.** Reading the file back, the agent found that its check on a reply's model name let a NULL through, since a comparison with NULL is unknown and a check that is unknown passes. It was fixed before the tests ran; the fourth broken copy above puts it back, and fails. **A slip:** the first copy built to break the path rule did not change the file, since the `sed` pattern matched nothing, and its tests passed; it was caught by the count of changed lines, and rerun with a pattern that matched (`platform-traps.md`).

**The database is built**, in four stages. Every function the app role may call is tested, as the owner role, and what the app role can reach is tested as the app role itself. Not checked, as before: what two sessions do at once, and PostgreSQL 16.
