"""The backend's access to the database: a connection as the app role, through
which it calls the schema's functions, the only thing the app role may do.

A function's refusal, SQLSTATE AI001, comes back as Refused, carrying its key.
"""

from contextlib import asynccontextmanager

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

from aiconman.config import Db

REFUSAL = "AI001"


class Refused(Exception):
    """A function of the schema refused; KEY says why, such as last_admin."""

    def __init__(self, key: str):
        super().__init__(key)
        self.key = key


@asynccontextmanager
async def connect(db: Db):
    """A connection as the app role, in which each statement commits on its
    own, giving rows as dictionaries."""
    conn = await psycopg.AsyncConnection.connect(
        host=db.host, port=db.port, dbname=db.dbname, user=db.user, password=db.password,
        autocommit=True, row_factory=dict_row,
    )
    try:
        yield conn
    finally:
        await conn.close()


async def call(conn: psycopg.AsyncConnection, function: str, *args) -> list[dict]:
    """Calls the schema's FUNCTION with ARGS and returns its rows, raising
    Refused when it refuses."""
    query = sql.SQL("SELECT * FROM {}({})").format(
        sql.Identifier(function), sql.SQL(", ").join(sql.Placeholder() * len(args))
    )
    try:
        cursor = await conn.execute(query, args)
    except psycopg.Error as e:
        if e.sqlstate == REFUSAL:
            raise Refused(e.diag.message_primary) from None
        raise
    return await cursor.fetchall()
