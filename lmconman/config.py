"""LMconman's configuration.

The configuration is config.yml in config/, or in the folder the environment
variable LMCONMAN_CONFIG_DIR names. A secret left empty there is taken from
.env in the same folder, under the name in SECRETS.

Run as a script, this prints settings as shell assignments, for the scripts in
install/, with the secrets filled in the same way:

    python -I lmconman/config.py VAR=section.key ...
"""

import os
import shlex
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

SECRETS = {
    ("db", "password"): "LMCONMAN_DB_PASSWORD",
    ("db", "adminpw"): "LMCONMAN_DB_ADMINPW",
    ("auth", "state_secret"): "LMCONMAN_STATE_SECRET",
    ("connections", "encryption_key"): "LMCONMAN_CONNECTION_KEY",
    ("nextcloud", "client_id"): "LMCONMAN_NEXTCLOUD_CLIENT_ID",
    ("nextcloud", "client_secret"): "LMCONMAN_NEXTCLOUD_CLIENT_SECRET",
}


class ConfigError(Exception):
    """A configuration that cannot be read or is not complete."""


def config_dir() -> Path:
    """The configuration folder: LMCONMAN_CONFIG_DIR, or config/."""
    named = os.environ.get("LMCONMAN_CONFIG_DIR")
    return Path(named) if named else ROOT / "config"


def read_env_file(path: Path) -> dict[str, str]:
    """Reads KEY=value lines, skipping blank lines and lines starting with #.
    A value wrapped in matching single or double quotes loses them."""
    values = {}
    for number, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, equals, value = stripped.partition("=")
        if not equals or not key.strip():
            raise ConfigError(f"{path}, line {number}: not KEY=value")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def load_raw(directory: Path | None = None) -> dict:
    """config.yml as a dictionary, with every secret left empty there filled
    from .env, when there is one."""
    directory = directory or config_dir()
    path = directory / "config.yml"
    try:
        with path.open() as f:
            raw = yaml.safe_load(f)
    except OSError as e:
        raise ConfigError(f"cannot read {path}: {e.strerror}") from e
    except yaml.YAMLError as e:
        raise ConfigError(f"{path} is not valid YAML: {e}") from e
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        raise ConfigError(f"{path} is not a mapping of sections")
    env_path = directory / ".env"
    env = read_env_file(env_path) if env_path.exists() else {}
    for (section, key), name in SECRETS.items():
        values = raw.get(section)
        if values is None:
            values = raw[section] = {}
        if not isinstance(values, dict):
            raise ConfigError(f"{path}: {section} is not a mapping of settings")
        if values.get(key) in (None, "") and env.get(name):
            values[key] = env[name]
    return raw


def setting(raw: dict, dotted: str):
    """The value at "section.key" in RAW, or None when it is not there."""
    value = raw
    for part in dotted.split("."):
        value = value.get(part) if isinstance(value, dict) else None
    return value


@dataclass(frozen=True)
class Server:
    host: str
    port: int
    public_url: str


@dataclass(frozen=True)
class Db:
    host: str
    port: int
    dbname: str
    user: str
    password: str


@dataclass(frozen=True)
class Storage:
    root_path: Path


@dataclass(frozen=True)
class Auth:
    password_login: bool
    nextcloud_login: bool
    state_secret: str
    cookie_name: str
    cookie_secure: bool
    idle_minutes: int
    absolute_hours: int


@dataclass(frozen=True)
class Nextcloud:
    instance_address: str
    authorize_url: str
    token_url: str
    profile_url: str
    client_id: str
    client_secret: str
    redirect_uri: str


@dataclass(frozen=True)
class Config:
    server: Server
    db: Db
    storage: Storage
    auth: Auth
    nextcloud: Nextcloud | None
    encryption_key: str


def load(directory: Path | None = None) -> Config:
    """The configuration the backend runs with, refusing one that lacks a
    setting it needs. Nextcloud's settings are needed only when Nextcloud
    sign-in is on, and are None otherwise. With both ways of signing in off,
    password sign-in is on."""
    directory = directory or config_dir()
    raw = load_raw(directory)
    where = directory / "config.yml"

    def get(dotted: str, kind: type, default=None):
        value = setting(raw, dotted)
        if value in (None, ""):
            if default is None:
                raise ConfigError(f"{where}: {dotted} is not set")
            return default
        if kind is int and (isinstance(value, bool) or not isinstance(value, int)):
            raise ConfigError(f"{where}: {dotted} must be a whole number")
        if kind is bool and not isinstance(value, bool):
            raise ConfigError(f"{where}: {dotted} must be true or false")
        if kind is str and not isinstance(value, str):
            raise ConfigError(f"{where}: {dotted} must be text")
        return value

    password_login = get("auth.password_login", bool, False)
    nextcloud_login = get("auth.nextcloud_login", bool, False)
    if not password_login and not nextcloud_login:
        password_login = True
    public_url = get("server.public_url", str).rstrip("/")

    nextcloud = None
    if nextcloud_login:
        instance = get("nextcloud.instance_address", str).rstrip("/")
        nextcloud = Nextcloud(
            instance_address=instance,
            authorize_url=get("nextcloud.authorize_url", str, f"{instance}/apps/oauth2/authorize"),
            token_url=get("nextcloud.token_url", str, f"{instance}/apps/oauth2/api/v1/token"),
            profile_url=get("nextcloud.profile_url", str,
                            f"{instance}/ocs/v2.php/cloud/user?format=json"),
            client_id=get("nextcloud.client_id", str),
            client_secret=get("nextcloud.client_secret", str),
            redirect_uri=get("nextcloud.redirect_uri", str,
                             f"{public_url}/auth/nextcloud/callback"),
        )

    return Config(
        server=Server(
            host=get("server.host", str),
            port=get("server.port", int),
            public_url=public_url,
        ),
        db=Db(
            host=get("db.host", str),
            port=get("db.port", int),
            dbname=get("db.dbname", str),
            user=get("db.user", str),
            password=get("db.password", str),
        ),
        storage=Storage(root_path=Path(get("storage.root_path", str))),
        auth=Auth(
            password_login=password_login,
            nextcloud_login=nextcloud_login,
            state_secret=get("auth.state_secret", str) if nextcloud_login else "",
            cookie_name=get("auth.cookie_name", str),
            cookie_secure=get("auth.cookie_secure", bool),
            idle_minutes=get("auth.idle_minutes", int),
            absolute_hours=get("auth.absolute_hours", int),
        ),
        nextcloud=nextcloud,
        encryption_key=get("connections.encryption_key", str),
    )


def main(arguments: list[str]) -> int:
    """Prints VAR=value for each VAR=section.key argument, quoted for a shell;
    a setting that is not there prints as empty, and a boolean as true or
    false."""
    try:
        raw = load_raw()
    except ConfigError as e:
        print(f"config.py: {e}", file=sys.stderr)
        return 1
    for argument in arguments:
        name, _, dotted = argument.partition("=")
        value = setting(raw, dotted)
        if isinstance(value, bool):
            value = "true" if value else "false"
        print(f"{name}={shlex.quote('' if value is None else str(value))}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
