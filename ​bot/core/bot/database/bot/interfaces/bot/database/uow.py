"""
Unit of Work implementation providing transaction boundaries.
Fixes the Result pattern clash by requiring explicit `.commit()` calls.
"""

import logging
from bot.interfaces.uow_interface import IUnitOfWork
from bot.database.connection import db_manager

logger = logging.getLogger("errors")


class UnitOfWork(IUnitOfWork):
    """
    Context manager that isolates database transactions.
    Rolls back automatically unless `uow.commit()` is explicitly invoked.
    """

    def __init__(self) -> None:
        self._conn_ctx = db_manager.acquire_connection()
        self.session = None  # type: ignore
        self._committed = False

    async def __aenter__(self) -> "UnitOfWork":
        self.session = await self._conn_ctx.__aenter__()
        # Begin transaction explicitly (aiosqlite defers this until first write)
        await self.session.execute("BEGIN;")
        return self

    async def commit(self) -> None:
        """Commits the active transaction and marks it as successful."""
        if self.session:
            await self.session.commit()
            self._committed = True

    async def rollback(self) -> None:
        """Rolls back the active transaction."""
        if self.session:
            await self.session.rollback()
            self._committed = False

    async def __aexit__(self, exc_type: Exception, exc_val: Exception, exc_tb: Exception) -> None:
        try:
            # If an exception occurred OR commit wasn't explicitly called (Result.fail trigger)
            if exc_type is not None or not self._committed:
                await self.rollback()
        except Exception as e:
            logger.error(f"Failed to rollback UnitOfWork: {e}", exc_info=True)
        finally:
            await self._conn_ctx.__aexit__(exc_type, exc_val, exc_tb)
