"""Tests of lmconman/config.py, on configurations written into temporary
folders. Needs no database.

    .venv/bin/python -m unittest discover -s tests/backend -p 'test_config.py'
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

from lmconman import config

ROOT = Path(__file__).resolve().parent.parent.parent

COMPLETE = """
server:
  host: 127.0.0.1
  port: 8642
  public_url: https://lmconman.example.lan/
db:
  host: 127.0.0.1
  port: 5432
  dbname: test_db
  user: test_app
  password: ""
  adminuser: test_admin
  adminpw: ""
storage:
  root_path: /srv/lmconman
auth:
  password_login: true
  nextcloud_login: false
  allow_auto_signup: true
  state_secret: ""
  cookie_name: lmconman_session
  cookie_secure: true
  idle_minutes: 43200
  absolute_hours: 2160
nextcloud:
  instance_address: https://nextcloud.example.lan/
  client_id: ""
  client_secret: ""
connections:
  encryption_key: made-up-key
"""


class ConfigTest(unittest.TestCase):
    def empty_folder(self) -> Path:
        """A temporary folder, removed after the test."""
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        return Path(temporary.name)

    def folder(self, config_yml: str, env: str | None = None) -> Path:
        """A temporary configuration folder holding CONFIG_YML, and ENV as its
        .env when given."""
        directory = self.empty_folder()
        (directory / "config.yml").write_text(textwrap.dedent(config_yml))
        if env is not None:
            (directory / ".env").write_text(textwrap.dedent(env))
        return directory

    def test_a_secret_set_in_config_yml_is_used(self):
        directory = self.folder(COMPLETE.replace('password: ""', "password: from-yml"))
        self.assertEqual(config.load(directory).db.password, "from-yml")

    def test_a_secret_left_empty_comes_from_env(self):
        directory = self.folder(COMPLETE, "LMCONMAN_DB_PASSWORD=from-env\n")
        self.assertEqual(config.load(directory).db.password, "from-env")

    def test_a_secret_set_in_config_yml_wins_over_env(self):
        directory = self.folder(COMPLETE.replace('password: ""', "password: from-yml"),
                                "LMCONMAN_DB_PASSWORD=from-env\n")
        self.assertEqual(config.load(directory).db.password, "from-yml")

    def test_env_quotes_comments_and_blank_lines(self):
        directory = self.folder(COMPLETE, """
            # a comment
            LMCONMAN_DB_PASSWORD="quoted value"

            LMCONMAN_DB_ADMINPW='single $quoted'
            """)
        raw = config.load_raw(directory)
        self.assertEqual(config.setting(raw, "db.password"), "quoted value")
        self.assertEqual(config.setting(raw, "db.adminpw"), "single $quoted")

    def test_a_line_in_env_that_is_not_key_value(self):
        directory = self.folder(COMPLETE, "LMCONMAN_DB_PASSWORD\n")
        with self.assertRaisesRegex(config.ConfigError, "line 1: not KEY=value"):
            config.load_raw(directory)

    def test_the_calling_shell_environment_is_not_read(self):
        directory = self.folder(COMPLETE)
        os.environ["LMCONMAN_DB_PASSWORD"] = "from-shell"
        self.addCleanup(os.environ.pop, "LMCONMAN_DB_PASSWORD")
        with self.assertRaisesRegex(config.ConfigError, "db.password is not set"):
            config.load(directory)

    def test_no_config_yml(self):
        with self.assertRaisesRegex(config.ConfigError, "cannot read"):
            config.load(self.empty_folder())

    def test_config_yml_that_is_not_yaml(self):
        with self.assertRaisesRegex(config.ConfigError, "not valid YAML"):
            config.load(self.folder("db: [unclosed\n"))

    def test_a_setting_missing(self):
        directory = self.folder(COMPLETE.replace("  dbname: test_db\n", ""), "LMCONMAN_DB_PASSWORD=x\n")
        with self.assertRaisesRegex(config.ConfigError, "db.dbname is not set"):
            config.load(directory)

    def test_a_port_that_is_not_a_number(self):
        directory = self.folder(COMPLETE.replace("port: 8642", "port: eighty"), "LMCONMAN_DB_PASSWORD=x\n")
        with self.assertRaisesRegex(config.ConfigError, "server.port must be a whole number"):
            config.load(directory)

    def test_a_switch_that_is_not_true_or_false(self):
        directory = self.folder(COMPLETE.replace("cookie_secure: true", "cookie_secure: maybe"),
                                "LMCONMAN_DB_PASSWORD=x\n")
        with self.assertRaisesRegex(config.ConfigError, "auth.cookie_secure must be true or false"):
            config.load(directory)

    def test_with_both_ways_of_signing_in_off_password_sign_in_is_on(self):
        directory = self.folder(COMPLETE.replace("password_login: true", "password_login: false"),
                                "LMCONMAN_DB_PASSWORD=x\n")
        self.assertTrue(config.load(directory).auth.password_login)

    def test_nextcloud_settings_are_not_needed_while_its_sign_in_is_off(self):
        loaded = config.load(self.folder(COMPLETE, "LMCONMAN_DB_PASSWORD=x\n"))
        self.assertIsNone(loaded.nextcloud)

    def test_nextcloud_sign_in_needs_its_client_id(self):
        directory = self.folder(COMPLETE.replace("nextcloud_login: false", "nextcloud_login: true"),
                                "LMCONMAN_DB_PASSWORD=x\nLMCONMAN_STATE_SECRET=s\n")
        with self.assertRaisesRegex(config.ConfigError, "nextcloud.client_id is not set"):
            config.load(directory)

    def test_nextcloud_addresses_are_made_from_the_instance_and_public_url(self):
        directory = self.folder(COMPLETE.replace("nextcloud_login: false", "nextcloud_login: true"), """
            LMCONMAN_DB_PASSWORD=x
            LMCONMAN_STATE_SECRET=s
            LMCONMAN_NEXTCLOUD_CLIENT_ID=id
            LMCONMAN_NEXTCLOUD_CLIENT_SECRET=secret
            """)
        nextcloud = config.load(directory).nextcloud
        self.assertEqual(nextcloud.authorize_url, "https://nextcloud.example.lan/apps/oauth2/authorize")
        self.assertEqual(nextcloud.token_url, "https://nextcloud.example.lan/apps/oauth2/api/v1/token")
        self.assertEqual(nextcloud.profile_url,
                         "https://nextcloud.example.lan/ocs/v2.php/cloud/user?format=json")
        self.assertEqual(nextcloud.redirect_uri, "https://lmconman.example.lan/auth/nextcloud/callback")

    def test_a_nextcloud_address_given_wins(self):
        changed = COMPLETE.replace("nextcloud_login: false", "nextcloud_login: true").replace(
            "  client_id: \"\"\n",
            "  client_id: id\n  token_url: https://nc-internal.example.lan/index.php/apps/oauth2/api/v1/token\n")
        directory = self.folder(changed, "LMCONMAN_DB_PASSWORD=x\nLMCONMAN_STATE_SECRET=s\n"
                                         "LMCONMAN_NEXTCLOUD_CLIENT_SECRET=secret\n")
        self.assertEqual(config.load(directory).nextcloud.token_url,
                         "https://nc-internal.example.lan/index.php/apps/oauth2/api/v1/token")

    def test_the_templates_filled_in_load(self):
        directory = self.folder((ROOT / "config.yml.template").read_text(), "\n".join([
            "LMCONMAN_DB_PASSWORD=made-up",
            "LMCONMAN_CONNECTION_KEY=made-up",
        ]))
        loaded = config.load(directory)
        self.assertEqual((loaded.server.port, loaded.db.dbname, loaded.db.user), (8642, "lmcm_db", "lmcm_db_app"))

    def test_as_a_script_it_prints_shell_assignments(self):
        directory = self.folder(COMPLETE, "LMCONMAN_DB_ADMINPW=it's $here\n")
        result = subprocess.run(
            [sys.executable, "-I", str(ROOT / "lmconman" / "config.py"),
             "name=db.dbname", "pw=db.adminpw", "signup=auth.allow_auto_signup", "none=db.nothing"],
            env={**os.environ, "LMCONMAN_CONFIG_DIR": str(directory)},
            capture_output=True, text=True, check=True,
        )
        shell = subprocess.run(["bash", "-c", result.stdout + 'printf "%s|%s|%s|%s" "$name" "$pw" "$signup" "$none"'],
                               capture_output=True, text=True, check=True)
        self.assertEqual(shell.stdout, "test_db|it's $here|true|")


if __name__ == "__main__":
    unittest.main()
