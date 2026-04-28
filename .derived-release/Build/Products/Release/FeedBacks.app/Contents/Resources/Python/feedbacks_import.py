from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from feedbacks_errors import RunnerError
import feedbacks_ptsl_pb2 as pt
from feedbacks_ptsl_client import PTSLClient


def nominal_fps_for_token(token: str) -> int:
    mapping = {
        "STCR_Fps23976": 24,
        "STCR_Fps24": 24,
        "STCR_Fps25": 25,
        "STCR_Fps2997": 30,
        "STCR_Fps2997Drop": 30,
        "STCR_Fps30": 30,
        "STCR_Fps30Drop": 30,
        "STCR_Fps47952": 48,
        "STCR_Fps48": 48,
        "STCR_Fps50": 50,
        "STCR_Fps5994": 60,
        "STCR_Fps5994Drop": 60,
        "STCR_Fps60": 60,
        "STCR_Fps60Drop": 60,
        "STCR_Fps100": 100,
        "STCR_Fps11988": 120,
        "STCR_Fps11988Drop": 120,
        "STCR_Fps120": 120,
        "STCR_Fps120Drop": 120,
    }
    return mapping.get(token, 25)


def next_memory_location_number(client: PTSLClient) -> int:
    body = client.send(
        command_id=pt.CId_GetMemoryLocations,
        request_body={"pagination_request": {"limit": 0, "offset": 0}},
    ) or {}

    max_number = 0
    for item in body.get("memory_locations") or []:
        if not isinstance(item, dict):
            continue
        number = item.get("number")
        if isinstance(number, int):
            max_number = max(max_number, number)

    return max_number + 1


def ruler_candidates(ruler_name: str) -> list[str]:
    trimmed = ruler_name.strip() or "Markers 5"
    candidates = [trimmed, f"Marker Ruler {trimmed}", f"Ruler {trimmed}"]

    match = re.search(r"\d+", trimmed)
    if match:
        digits = match.group(0)
        candidates.extend(
            [
                digits,
                f"Markers {digits}",
                f"Marker Ruler {digits}",
                f"Ruler {digits}",
            ]
        )

    deduped: list[str] = []
    seen: set[str] = set()
    for value in candidates:
        if value in seen:
            continue
        seen.add(value)
        deduped.append(value)
    return deduped


def is_duplicate_memory_location_error(message: str) -> bool:
    lowered = message.strip().lower()
    return (
        "already used" in lowered
        or "memory location number is already used" in lowered
        or "already exists" in lowered
    )


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "created": 0, "attempted": 0, "failures": [], "error": "Missing input payload path"}))
        return 1

    payload_path = Path(sys.argv[1])
    try:
        payload = json.loads(payload_path.read_text(encoding="utf-8"))
        marker_name = str(payload.get("markerName", "")).strip()
        color_index = int(payload.get("colorIndex", 12))
        ruler_name = str(payload.get("rulerName", "")).strip() or "Markers 5"
        rows = payload.get("rows") or []

        if not marker_name:
            raise RunnerError("Marker name cannot be empty", code="invalid_marker_name", retryable=False)
        if color_index < 1 or color_index > 16:
            raise RunnerError("colorIndex must be in 1..16", code="invalid_color_index", retryable=False)
        if not isinstance(rows, list) or not rows:
            raise RunnerError("No marker row selected", code="no_marker_row_selected", retryable=False)

        with PTSLClient(company_name="GogoLabs", application_name="FeedBacks") as client:
            host = client.send(command_id=pt.CId_HostReadyCheck) or {}
            is_host_ready = bool(host.get("is_host_ready", True))
            if not is_host_ready:
                raise RunnerError("Pro Tools host is not ready", code="ptsl_host_not_ready", retryable=True)

            fps_body = client.send(command_id=pt.CId_GetSessionTimeCodeRate) or {}
            token = str(fps_body.get("time_code_rate") or fps_body.get("current_setting") or "")
            fps = nominal_fps_for_token(token)

            next_number = next_memory_location_number(client)
            candidates = ruler_candidates(ruler_name)
            created = 0
            failures = []

            for row in rows:
                timecode = str((row or {}).get("timecode") or "").strip()
                comment = str((row or {}).get("comment") or "").strip()
                if not timecode:
                    failures.append({"timecode": "", "error": "Missing timecode"})
                    continue

                ff = int(timecode.split(":")[3])
                if ff >= fps:
                    failures.append({"timecode": timecode, "error": f"Frame value {ff} out of range for session fps={fps}"})
                    continue

                created_on_named_ruler = False
                last_error_message = "CreateMemoryLocation failed"

                for _ in range(20):
                    should_try_next_number = False
                    for candidate in candidates:
                        body = {
                            "number": next_number,
                            "name": marker_name,
                            "start_time": timecode,
                            "time_properties": "TP_Marker",
                            "reference": "MLR_Absolute",
                            "color_index": color_index,
                            "comments": comment,
                            "location": "MarkerLocation_NamedRuler",
                            "track_name": candidate,
                        }
                        try:
                            client.send(command_id=pt.CId_CreateMemoryLocation, request_body=body)
                            created_on_named_ruler = True
                            break
                        except RunnerError as exc:
                            last_error_message = str(exc)
                            if is_duplicate_memory_location_error(last_error_message):
                                should_try_next_number = True
                                break
                    if created_on_named_ruler:
                        break
                    if should_try_next_number:
                        next_number += 1
                        continue
                    break

                if not created_on_named_ruler:
                    failures.append(
                        {
                            "name": marker_name,
                            "timecode": timecode,
                            "error": last_error_message,
                            "ruler": ruler_name,
                        }
                    )
                    continue

                created += 1
                next_number += 1

        print(
            json.dumps(
                {
                    "ok": True,
                    "hostReady": True,
                    "fps": fps,
                    "rateToken": token or "STCR_Fps25",
                    "created": created,
                    "attempted": len(rows),
                    "failures": failures,
                    "error": None,
                }
            )
        )
        return 0
    except RunnerError as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "hostReady": False,
                    "fps": None,
                    "rateToken": None,
                    "created": 0,
                    "attempted": 0,
                    "failures": [],
                    "error": str(exc),
                }
            )
        )
        return 1
    except Exception as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "hostReady": False,
                    "fps": None,
                    "rateToken": None,
                    "created": 0,
                    "attempted": 0,
                    "failures": [],
                    "error": str(exc),
                }
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
