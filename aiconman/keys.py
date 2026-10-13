"""The connections' keys, encrypted with connections.encryption_key: AES-256-GCM
from the cryptography library, with the AES key derived from the configured
text by HKDF-SHA256. The database keeps only what encrypt returns.

A stored key is one version byte, a 12-byte nonce, and the ciphertext with its
16-byte tag.
"""

import os

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

VERSION = b"\x01"
PURPOSE = b"aiconman connection key"
NONCE = 12
TAG = 16


class UndecryptableKey(Exception):
    """A stored key that the configured secret does not open: the secret has
    changed since the key was saved, or the stored bytes are damaged."""


def _cipher(secret: str) -> AESGCM:
    """AES-256-GCM keyed by SECRET, through HKDF-SHA256."""
    key = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=PURPOSE).derive(secret.encode())
    return AESGCM(key)


def encrypt(secret: str, key: str) -> bytes:
    """KEY, a server's API key, encrypted with SECRET under a new random
    nonce."""
    nonce = os.urandom(NONCE)
    return VERSION + nonce + _cipher(secret).encrypt(nonce, key.encode(), PURPOSE)


def decrypt(secret: str, stored: bytes) -> str:
    """The API key STORED holds, raising UndecryptableKey when SECRET does not
    open it."""
    stored = bytes(stored)
    if stored[:1] != VERSION or len(stored) < 1 + NONCE + TAG:
        raise UndecryptableKey("not a stored key of this version")
    try:
        return _cipher(secret).decrypt(stored[1:1 + NONCE], stored[1 + NONCE:], PURPOSE).decode()
    except InvalidTag as e:
        raise UndecryptableKey("the configured secret does not open this key") from e
