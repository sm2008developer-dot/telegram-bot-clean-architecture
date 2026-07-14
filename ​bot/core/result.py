"""
Core Result pattern implementation (Monad).
Eliminates silent NoneType errors and forces explicit error handling.
"""

from typing import Generic, TypeVar, Optional, Any, Callable

T = TypeVar("T")


class ResultError(Exception):
    """Exception raised for invalid unwrapping of a failed Result."""
    pass


class Result(Generic[T]):
    """
    Encapsulates the output of an operation, distinguishing between success and failure.
    """

    def __init__(self, is_success: bool, value: Optional[T] = None, error: Optional[str] = None):
        if is_success and error:
            raise ValueError("A successful Result cannot have an error message.")
        if not is_success and value is not None:
            raise ValueError("A failed Result cannot contain a value.")

        self.is_success = is_success
        self.is_failure = not is_success
        self._value = value
        self.error = error

    @classmethod
    def ok(cls, value: T) -> "Result[T]":
        """Creates a successful Result containing the expected payload."""
        return cls(is_success=True, value=value)

    @classmethod
    def fail(cls, error: str) -> "Result[Any]":
        """Creates a failed Result containing a descriptive error message."""
        return cls(is_success=False, error=error)

    def unwrap(self) -> T:
        """
        Extracts the value.
        Raises ResultError if called on a failed Result.
        """
        if self.is_failure:
            raise ResultError(f"Attempted to unwrap a failed Result: {self.error}")
        return self._value  # type: ignore

    def value_or(self, fallback: T) -> T:
        """Returns the inner value if successful, or the provided fallback if failed."""
        if self.is_failure:
            return fallback
        return self._value  # type: ignore

    def match(self, on_success: Callable[[T], Any], on_failure: Callable[[str], Any]) -> Any:
        """Pattern matching for functional pipeline processing."""
        if self.is_success:
            return on_success(self.unwrap())
        return on_failure(self.error or "Unknown error")

