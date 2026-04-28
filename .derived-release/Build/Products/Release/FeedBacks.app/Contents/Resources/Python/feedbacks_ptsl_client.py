"""PTSL gRPC client helpers for GoGoGo runners."""

from __future__ import annotations

import json
import os
from typing import Any

from feedbacks_errors import RunnerError

try:
    import grpc
except ModuleNotFoundError as exc:  # pragma: no cover - runtime dependency
    grpc = None
    _grpc_import_error = exc
else:
    _grpc_import_error = None

import feedbacks_ptsl_pb2 as pt


class PTSLClient:
    def __init__(
        self,
        *,
        address: str | None = None,
        company_name: str = "GogoLabs",
        application_name: str = "GoGoGo",
        version: int = 5,
        version_minor: int = 0,
        version_revision: int = 0,
    ) -> None:
        if grpc is None:
            raise RunnerError(
                "Python dependency missing: grpcio (pip install grpcio)",
                code="missing_dependency",
                retryable=False,
            ) from _grpc_import_error

        self._version = version
        self._version_minor = version_minor
        self._version_revision = version_revision

        resolved_address = address or os.environ.get("GOGOGO_PTSL_ADDRESS") or "localhost:31416"
        self._channel = grpc.insecure_channel(resolved_address)
        self._rpc = self._channel.unary_unary(
            "/ptsl.PTSL/SendGrpcRequest",
            request_serializer=pt.Request.SerializeToString,
            response_deserializer=pt.Response.FromString,
        )
        self.session_id = ""

        # Ensure host is reachable before registration.
        self.send(command_id=pt.CId_HostReadyCheck)
        register_body = self.send(
            command_id=pt.CId_RegisterConnection,
            request_body={
                "company_name": company_name,
                "application_name": application_name,
            },
        )
        self.session_id = str((register_body or {}).get("session_id", ""))
        if not self.session_id:
            raise RunnerError(
                "PTSL RegisterConnection returned empty session_id",
                code="ptsl_register_failed",
                retryable=False,
            )

    def close(self) -> None:
        self._channel.close()

    def __enter__(self) -> "PTSLClient":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def send(self, *, command_id: int, request_body: dict[str, Any] | None = None) -> dict[str, Any] | None:
        request_json = "" if request_body is None else json.dumps(request_body)

        header_kwargs: dict[str, Any] = {
            "command": command_id,
            "version": self._version,
            "version_minor": self._version_minor,
            "version_revision": self._version_revision,
            "session_id": self.session_id,
        }

        request = pt.Request(
            header=pt.RequestHeader(**header_kwargs),
            request_body_json=request_json,
        )

        try:
            response = self._rpc(request)
        except Exception as exc:
            if grpc is not None and isinstance(exc, grpc.RpcError):
                status_code = exc.code()
                details = (exc.details() or str(exc) or "PTSL RPC failed").strip()
                retryable_codes = {
                    grpc.StatusCode.CANCELLED,
                    grpc.StatusCode.UNKNOWN,
                    grpc.StatusCode.DEADLINE_EXCEEDED,
                    grpc.StatusCode.RESOURCE_EXHAUSTED,
                    grpc.StatusCode.ABORTED,
                    grpc.StatusCode.INTERNAL,
                    grpc.StatusCode.UNAVAILABLE,
                    grpc.StatusCode.DATA_LOSS,
                }
                retryable = status_code in retryable_codes
                raise RunnerError(
                    f"PTSL RPC transport error ({status_code.name}): {details}",
                    code="ptsl_transport_error",
                    retryable=retryable,
                ) from exc
            raise RunnerError(
                f"PTSL RPC transport error: {exc}",
                code="ptsl_transport_error",
                retryable=True,
            ) from exc
        if response.header.status == pt.TStatus_Failed:
            raise RunnerError(
                self._decode_error(response.response_error_json or ""),
                code="ptsl_command_failed",
                retryable=True,
            )

        if not response.response_body_json:
            return None

        try:
            return json.loads(response.response_body_json)
        except json.JSONDecodeError as exc:
            raise RunnerError(
                f"Invalid JSON body from PTSL response: {exc}",
                code="ptsl_invalid_response",
                retryable=False,
            ) from exc

    @staticmethod
    def _decode_error(raw: str) -> str:
        if not raw:
            return "PTSL command failed without details"

        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return raw

        errors = payload.get("errors") or []
        messages: list[str] = []
        for err in errors:
            if not isinstance(err, dict):
                continue
            msg = str(err.get("command_error_message") or "").strip()
            etype = str(err.get("command_error_type") or "").strip()
            if not msg:
                continue
            messages.append(f"{etype}: {msg}" if etype else msg)

        if messages:
            return " | ".join(messages)
        return raw
