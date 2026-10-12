"""Sessions: a random token in a cookie, of which the database keeps only the
SHA-256. The database decides whether a session can still be used."""

import hashlib
import secrets
from datetime import timedelta

from fastapi import Request, Response

from aiconman.config import Config
from aiconman.db import Refused


def new_token() -> str:
    """A new session token: 32 random bytes, in URL-safe base64."""
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> bytes:
    """The SHA-256 of TOKEN, which is all the database sees of it."""
    return hashlib.sha256(token.encode()).digest()


def lengths(config: Config) -> tuple[timedelta, timedelta]:
    """How long a session lasts unused, and how long at most."""
    return timedelta(minutes=config.auth.idle_minutes), timedelta(hours=config.auth.absolute_hours)


def set_cookie(response: Response, config: Config, token: str) -> None:
    """Sends TOKEN in the session cookie: hidden from the page's scripts, sent
    only to this site, over HTTPS when the configuration says so, and kept
    for as long as a session can last."""
    response.set_cookie(
        config.auth.cookie_name, token, max_age=config.auth.absolute_hours * 3600, path="/",
        httponly=True, secure=config.auth.cookie_secure, samesite="strict",
    )


def clear_cookie(response: Response, config: Config) -> None:
    """Tells the browser to forget the session cookie."""
    response.delete_cookie(
        config.auth.cookie_name, path="/", httponly=True, secure=config.auth.cookie_secure,
        samesite="strict",
    )


def current(request: Request) -> bytes:
    """The hash of the session token the request carries, refusing a request
    with none."""
    token = request.cookies.get(request.app.state.config.auth.cookie_name)
    if not token:
        raise Refused("session_invalid")
    return token_hash(token)
