"""
Interface defining the strict contract for the Unit of Work.
Required for true Dependency Injection in the Service Layer.
"""

from abc import ABC, abstractmethod
from typing import Any
from aiosqlite import Connection


class IUnitOfWork(ABC):
    session: Connection

    @abstractmethod
    async def __aenter__(self) -> "IUnitOfWork":
        pass

    @abstractmethod
    async def __aexit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        pass

    @abstractmethod
    async def commit(self) -> None:
        """Explicitly commits the transaction."""
        pass

    @abstractmethod
    async def rollback(self) -> None:
        """Explicitly rolls back the transaction."""
        pass
