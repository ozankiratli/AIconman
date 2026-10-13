"""Passwords: the rules a new one must meet, and hashing with scrypt from
Python's standard library.

The database never sees a password. It keeps the hash and the salt string this
module writes, gives the salt string back for an account, and compares the
hash of a password typed at sign-in with the one it keeps.
"""

import base64
import hashlib
import secrets
import unicodedata

MIN_LENGTH = 16
MIN_EACH = 2

# scrypt's cost. It is written into each salt string, so a password hashed with
# other values is still checked with its own.
N, R, P = 2**17, 8, 1
KEY_LENGTH = 32


def normalized(password: str) -> str:
    """PASSWORD as it is checked and hashed: normalized to NFC, so that the
    same characters typed on another device hash the same, and with any
    whitespace at either end removed, as a pasted password often carries."""
    return unicodedata.normalize("NFC", password).strip()


def rules_unmet(password: str) -> list[str]:
    """The rules PASSWORD, normalized, does not meet, by name: at least 16
    characters ("length"); no whitespace ("spaces"); and at least two each of
    uppercase letters, lowercase letters, digits, and symbols, a symbol being
    any character that is not a letter or a digit. Whitespace, refused anyway,
    does not count as a symbol."""
    password = normalized(password)
    unmet = []
    if len(password) < MIN_LENGTH:
        unmet.append("length")
    if any(c.isspace() for c in password):
        unmet.append("spaces")
    if sum(c.isupper() for c in password) < MIN_EACH:
        unmet.append("uppercase")
    if sum(c.islower() for c in password) < MIN_EACH:
        unmet.append("lowercase")
    if sum(c.isdigit() for c in password) < MIN_EACH:
        unmet.append("digits")
    if sum(not c.isalnum() and not c.isspace() for c in password) < MIN_EACH:
        unmet.append("symbols")
    return unmet


def new_salt() -> str:
    """A salt string for a new password: the algorithm, its cost, and 16
    random bytes in base64, as scrypt$n=...,r=...,p=...$<salt>."""
    salt = base64.b64encode(secrets.token_bytes(16)).decode()
    return f"scrypt$n={N},r={R},p={P}${salt}"


def hash_password(password: str, salt: str) -> bytes:
    """PASSWORD, normalized, hashed as the salt string SALT says."""
    algorithm, cost, salt_b64 = salt.split("$")
    if algorithm != "scrypt":
        raise ValueError(f"unknown password algorithm {algorithm!r}")
    values = dict(part.split("=") for part in cost.split(","))
    n, r, p = int(values["n"]), int(values["r"]), int(values["p"])
    return hashlib.scrypt(
        normalized(password).encode(),
        salt=base64.b64decode(salt_b64), n=n, r=r, p=p, dklen=KEY_LENGTH,
        maxmem=2 * 128 * r * n * p,
    )
