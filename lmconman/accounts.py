"""The account endpoints: signing up and in with a password, one's own account,
and the admin's accounts and settings. Signing in through Nextcloud is not
here yet.

Every endpoint that acts for a person passes the hash of the session token in
the request's cookie to the database, which decides whether it may.
"""

import asyncio
import logging
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request, Response
from psycopg.types.json import Jsonb
from pydantic import BaseModel, Field

from lmconman import passwords, sessions, storage
from lmconman.db import Refused, call, connect

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api")

Password = Annotated[str, Field(max_length=1024)]


async def db(request: Request):
    """A connection to the database for one request."""
    async with connect(request.app.state.config.db) as conn:
        yield conn


def password_login_on(request: Request) -> None:
    """Refuses while password sign-in is off in the configuration."""
    if not request.app.state.config.auth.password_login:
        raise Refused("password_login_off")


async def hashed(password: str, salt: str) -> bytes:
    """PASSWORD hashed with SALT, in a thread, so that the server goes on
    answering while scrypt runs."""
    return await asyncio.to_thread(passwords.hash_password, password, salt)


async def new_password(password: str) -> tuple[str, bytes]:
    """A new password's salt string and hash, refusing one that does not meet
    the rules, with the rules it does not meet."""
    unmet = passwords.rules_unmet(password)
    if unmet:
        raise Refused("password_weak", {"rules": unmet})
    salt = passwords.new_salt()
    return salt, await hashed(password, salt)


async def account(conn, token_hash: bytes) -> dict:
    """The account the session belongs to, as session_check gives it."""
    return (await call(conn, "session_check", token_hash))[0]


async def start_session(conn, request: Request, response: Response, function: str, *args) -> dict:
    """Calls FUNCTION, a sign-up or a sign-in, with ARGS and a new session's
    token hash and lengths; on success sends the token in the cookie and
    returns the account."""
    config = request.app.state.config
    token = sessions.new_token()
    idle, absolute = sessions.lengths(config)
    await call(conn, function, *args, sessions.token_hash(token), idle, absolute)
    sessions.set_cookie(response, config, token)
    return await account(conn, sessions.token_hash(token))


# Signing up and in -----------------------------------------------------------

class SignUp(BaseModel):
    username: str
    password: Password
    display_name: str | None = None


class SignIn(BaseModel):
    username: str
    password: Password


@router.get("/auth/options")
async def options(request: Request, conn=Depends(db)) -> dict:
    """Which ways of signing in are on, and whether people may sign up."""
    auth = request.app.state.config.auth
    open_ = (await call(conn, "sign_up_open"))[0]["sign_up_open"]
    return {"password_login": auth.password_login, "nextcloud_login": auth.nextcloud_login,
            "sign_up_open": open_}


@router.post("/auth/sign-up", dependencies=[Depends(password_login_on)])
async def sign_up(body: SignUp, request: Request, response: Response, conn=Depends(db)) -> dict:
    """Creates an account with a password, the admin if it is the first, and
    signs it in."""
    salt, hash_ = await new_password(body.password)
    return await start_session(conn, request, response, "sign_up_password",
                               body.username, body.display_name, salt, hash_)


@router.post("/auth/sign-in", dependencies=[Depends(password_login_on)])
async def sign_in(body: SignIn, request: Request, response: Response, conn=Depends(db)) -> dict:
    """Signs in with a username and password."""
    salt = (await call(conn, "password_salt", body.username))[0]["password_salt"]
    if salt is None:
        raise Refused("wrong_credentials")
    return await start_session(conn, request, response, "sign_in_password",
                               body.username, await hashed(body.password, salt))


@router.post("/auth/sign-out")
async def sign_out(request: Request, response: Response, conn=Depends(db)) -> dict:
    """Signs out of this session, if there is one, and forgets the cookie."""
    token = request.cookies.get(request.app.state.config.auth.cookie_name)
    if token:
        await call(conn, "sign_out", sessions.token_hash(token))
    sessions.clear_cookie(response, request.app.state.config)
    return {"signed_out": True}


# One's own account -------------------------------------------------------------

class Username(BaseModel):
    username: str


class DisplayName(BaseModel):
    display_name: str


class Theme(BaseModel):
    theme: str


class PasswordChange(BaseModel):
    current_password: Password | None = None
    new_password: Password


@router.get("/me")
async def me(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """One's own account, including whether it must change its password."""
    return await account(conn, token_hash)


@router.post("/me/sign-out-others")
async def sign_out_others(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Signs out of every other session of one's account."""
    revoked = (await call(conn, "sign_out_others", token_hash))[0]["sign_out_others"]
    return {"revoked": revoked}


@router.put("/me/username")
async def set_username(body: Username, token_hash: bytes = Depends(sessions.current),
                       conn=Depends(db)) -> dict:
    """Changes one's own username."""
    await call(conn, "set_username", token_hash, body.username)
    return await account(conn, token_hash)


@router.put("/me/display-name")
async def set_display_name(body: DisplayName, token_hash: bytes = Depends(sessions.current),
                           conn=Depends(db)) -> dict:
    """Changes one's own display name."""
    await call(conn, "set_display_name", token_hash, body.display_name)
    return await account(conn, token_hash)


@router.put("/me/theme")
async def set_theme(body: Theme, token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Changes one's own theme."""
    await call(conn, "set_theme", token_hash, body.theme)
    return await account(conn, token_hash)


@router.put("/me/password")
async def set_password(body: PasswordChange, token_hash: bytes = Depends(sessions.current),
                       conn=Depends(db)) -> dict:
    """Sets one's own password, and signs out one's other sessions. The current
    password is needed unless the account has none yet or must change the one
    it has; the database decides."""
    me = await account(conn, token_hash)
    current_hash = None
    if body.current_password is not None and me["has_password"]:
        salt = (await call(conn, "password_salt", me["username"]))[0]["password_salt"]
        current_hash = await hashed(body.current_password, salt)
    salt, hash_ = await new_password(body.new_password)
    await call(conn, "set_password", token_hash, current_hash, salt, hash_)
    return await account(conn, token_hash)


@router.post("/me/give-up-admin")
async def give_up_admin(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Gives up one's own admin role."""
    await call(conn, "give_up_admin", token_hash)
    return await account(conn, token_hash)


class Confirm(BaseModel):
    username: str


@router.post("/me/delete")
async def delete_me(body: Confirm, request: Request, response: Response,
                    token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Deletes one's own account, its chats and its folder, when BODY's
    username is the account's, and forgets the cookie."""
    config = request.app.state.config
    account_id = (await call(conn, "delete_own_account", token_hash, body.username))[0]["delete_own_account"]
    sessions.clear_cookie(response, config)
    return {"deleted": account_id, "folder_removed": remove_folder(request, account_id)}


def remove_folder(request: Request, account_id: str) -> bool:
    """Removes a deleted account's folder; on failure, logs it and returns
    false."""
    try:
        storage.remove_account_folder(request.app.state.config, account_id)
        return True
    except OSError:
        log.exception("could not remove the folder of the deleted account %s", account_id)
        return False


# Administration ------------------------------------------------------------------

class NewAccount(BaseModel):
    username: str
    password: Password
    display_name: str | None = None


class NewPassword(BaseModel):
    password: Password


class Active(BaseModel):
    active: bool


class SettingValue(BaseModel):
    value: Any


@router.get("/admin/accounts")
async def admin_accounts(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> list[dict]:
    """Every account, oldest first."""
    return await call(conn, "admin_accounts", token_hash)


@router.post("/admin/accounts", dependencies=[Depends(password_login_on)])
async def admin_create_account(body: NewAccount, token_hash: bytes = Depends(sessions.current),
                               conn=Depends(db)) -> dict:
    """Creates an account with a first password, to be changed at its first
    sign-in."""
    salt, hash_ = await new_password(body.password)
    account_id = (await call(conn, "admin_create_account", token_hash, body.username,
                             body.display_name, salt, hash_))[0]["admin_create_account"]
    return {"account_id": account_id}


@router.post("/admin/accounts/{account_id}/reset-password")
async def admin_reset_password(account_id: str, body: NewPassword,
                               token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Sets a new password for an account, to be changed at its next sign-in,
    and signs it out everywhere."""
    salt, hash_ = await new_password(body.password)
    await call(conn, "admin_reset_password", token_hash, account_id, salt, hash_)
    return {"reset": account_id}


@router.post("/admin/accounts/{account_id}/make-admin")
async def admin_make_admin(account_id: str, token_hash: bytes = Depends(sessions.current),
                           conn=Depends(db)) -> dict:
    """Makes an account an admin."""
    await call(conn, "admin_make_admin", token_hash, account_id)
    return {"admin": account_id}


@router.put("/admin/accounts/{account_id}/active")
async def admin_set_active(account_id: str, body: Active, token_hash: bytes = Depends(sessions.current),
                           conn=Depends(db)) -> dict:
    """Deactivates or reactivates a member's account."""
    await call(conn, "admin_set_active", token_hash, account_id, body.active)
    return {"account_id": account_id, "active": body.active}


@router.delete("/admin/accounts/{account_id}")
async def admin_delete_account(account_id: str, request: Request,
                               token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Deletes a member's account, its chats and its folder."""
    deleted = (await call(conn, "admin_delete_account", token_hash, account_id))[0]["admin_delete_account"]
    return {"deleted": deleted, "folder_removed": remove_folder(request, deleted)}


@router.get("/admin/settings")
async def admin_settings(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> list[dict]:
    """The household's settings, with who changed each last and when."""
    return await call(conn, "admin_settings", token_hash)


@router.put("/admin/settings/{key}")
async def admin_set_setting(key: str, body: SettingValue, token_hash: bytes = Depends(sessions.current),
                            conn=Depends(db)) -> dict:
    """Changes one of the household's settings."""
    await call(conn, "admin_set_setting", token_hash, key, Jsonb(body.value))
    return {"key": key, "value": body.value}
