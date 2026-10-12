"""Each account's folder under storage.root_path, named by the account's id."""

import re
import shutil
from pathlib import Path

from aiconman.config import Config

ACCOUNT_ID = re.compile(r"[a-z0-9]{8}")


def account_folder(config: Config, account_id: str) -> Path:
    """The folder of the account ACCOUNT_ID, refusing an id that is not eight
    lowercase letters and digits, which could name a path outside the
    storage folder."""
    if not ACCOUNT_ID.fullmatch(account_id):
        raise ValueError(f"not an account id: {account_id!r}")
    return config.storage.root_path / account_id


def remove_account_folder(config: Config, account_id: str) -> None:
    """Removes the folder of the account ACCOUNT_ID with everything in it,
    when there is one."""
    folder = account_folder(config, account_id)
    if folder.exists():
        shutil.rmtree(folder)
