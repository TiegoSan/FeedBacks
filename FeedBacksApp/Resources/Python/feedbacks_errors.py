"""Error types for the GoGoGo agent."""

from __future__ import annotations


class GoGoGoError(Exception):
    """Base class for typed agent errors."""

    code = "internal_error"

    def __init__(self, message: str, *, retryable: bool = False) -> None:
        super().__init__(message)
        self.retryable = retryable


class RegistryError(GoGoGoError):
    code = "registry_error"


class RequestValidationError(GoGoGoError):
    code = "request_validation_error"

    def __init__(self, message: str, *, code: str | None = None) -> None:
        super().__init__(message, retryable=False)
        self.code = code or self.code


class RunnerError(GoGoGoError):
    code = "runner_error"

    def __init__(self, message: str, *, code: str | None = None, retryable: bool = True) -> None:
        super().__init__(message, retryable=retryable)
        self.code = code or self.code
