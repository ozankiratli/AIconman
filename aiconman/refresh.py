"""The scheduled refresh: checks every connection and records the results,
acting for no one. cron runs it every 30 minutes, through
install/refresh_models.sh, from the repository's root:

    .venv/bin/python -m aiconman.refresh

It prints nothing when it finishes. A check that fails is recorded as that
connection's error, as the admin's check is; only a failure of the refresh
itself, such as a database it cannot reach, ends it with an error.
"""

import asyncio
import sys

import httpx

from aiconman import config as configuration
from aiconman import servers
from aiconman.connections import check_connection, recorded
from aiconman.db import Refused, call, connect


async def refresh(config: configuration.Config, transport: httpx.AsyncBaseTransport | None = None) -> int:
    """Checks every connection at once, through TRANSPORT when given, and
    records each result; returns how many were recorded. A connection removed
    meanwhile is skipped."""
    async with connect(config.db) as conn:
        targets = await call(conn, "refresh_targets")
        async with servers.client(transport) as http:
            results = await asyncio.gather(*(check_connection(config, http, target) for target in targets))
        count = 0
        for target, result in zip(targets, results):
            try:
                await call(conn, "refresh_record_check", target["connection_id"], *recorded(result))
                count += 1
            except Refused as e:
                if e.key != "no_such_connection":
                    raise
        return count


def main() -> int:
    asyncio.run(refresh(configuration.load()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
