"""
Database Connection Manager.
Handles robust connection provisioning and ensures SQLite WAL mode is configured
on every new isolated connection to prevent concurrency deadlocks.
"""

import logging
import aiosqlite
from pathlib import Path
from typing import AsyncGenerator
from contextlib import asynccontextmanager
from bot.config import config

error_logger = logging.getLogger("errors")
logger = logging.getLogger(__name__)


class DatabaseManager:
    """Manages SQLite connections with strict multi-reader concurrency optimizations."""

    def __init__(self) -> None:
        self.db_path = config.DATABASE_PATH
        self.schema_path = Path(__file__).parent / "schema.sql"

    async def init_db(self) -> None:
        """Applies the SQL schema on application startup."""
        logger.info("Initializing SQLite database connection and schemas...")
        if not self.schema_path.exists():
            error_logger.critical(f"Schema file missing at {self.schema_path}")
            raise FileNotFoundError("schema.sql is critically missing.")

        # Execute raw setup without UoW restrictions
        async with aiosqlite.connect(self.db_path) as db:
            with open(self.schema_path, "r", encoding="utf-8") as f:
                await db.executescript(f.read())
            await db.commit()
            
        logger.info("Database schemas and FTS triggers fully applied.")

    @asynccontextmanager
    async def acquire_connection(self) -> AsyncGenerator[aiosqlite.Connection, None]:
        """
        Yields an isolated, properly configured SQLite connection.
        Does NOT auto-commit. Transaction lifecycle is managed by UnitOfWork.
        """
        conn = await aiosqlite.connect(self.db_path)
        
        # Connection-level performance PRAGMAs
        await conn.execute("PRAGMA journal_mode=WAL;")
        await conn.execute("PRAGMA synchronous=NORMAL;")
        await conn.execute("PRAGMA foreign_keys=ON;")
        await conn.execute("PRAGMA temp_store=MEMORY;")
        await conn.execute("PRAGMA mmap_size=300000000;")
        
        conn.row_factory = aiosqlite.Row

        try:
            yield conn
        finally:
            await conn.close()


db_manager = DatabaseManager()
