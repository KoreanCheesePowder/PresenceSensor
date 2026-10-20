"""Adapter for the production System Monitor's existing SmartThings OAuth polling.

This module does not make network requests or contain credentials. Integrate it
with the monitor's existing GET /v1/devices/{deviceId}/status and /health calls.
"""
from __future__ import annotations

from typing import Any

CAPABILITY_SUFFIX = ".type6communication"


def extract_type6_status(device_status: dict[str, Any], platform_health: dict[str, Any] | str | None = None) -> dict[str, Any] | None:
    """Return a normalized TYPE6 telemetry record, or None for other devices.

    Platform health is authoritative for OFFLINE; driver silence is a warning
    and must not be treated as an official SmartThings OFFLINE state.
    """
    main = (device_status.get("components") or {}).get("main") or {}
    cap_id = next((key for key in main if isinstance(key, str) and key.lower().endswith(CAPABILITY_SUFFIX)), None)
    if not cap_id:
        return None
    raw = main[cap_id]
    if not isinstance(raw, dict):
        return None

    def attr(name: str, default: Any = None) -> Any:
        data = raw.get(name)
        return data.get("value", default) if isinstance(data, dict) else default

    link = attr("linkState", "checking")
    if link not in {"checking", "normal", "suspect"}:
        link = "checking"
    if isinstance(platform_health, dict):
        cloud = str(platform_health.get("state") or "UNKNOWN").upper()
    else:
        cloud = str(platform_health or "UNKNOWN").upper()

    if cloud == "OFFLINE":
        effective = "offline"
    elif link == "suspect":
        effective = "caution"
    elif cloud == "UNHEALTHY":
        effective = "caution"
    elif link == "normal":
        effective = "online"
    else:
        effective = "unknown" if cloud == "UNKNOWN" else "online"

    return {
        "capability_id": cap_id,
        "link_state": link,
        "platform_health": cloud,
        "monitor_status": effective,
        "communication_label": {
            "checking": "통신 확인 중",
            "normal": "통신 정상",
            "suspect": "통신 끊김 의심",
        }[link],
        "silence_minutes": attr("minutesWithoutRx", 0),
        "last_received": attr("lastReceived", "없음"),
        "timeout_minutes": attr("timeoutMinutes", 60),
    }


def type6_alarm_transition(previous: dict[str, Any] | None, current: dict[str, Any] | None) -> dict[str, str] | None:
    """Create a single change event for the monitor's existing alert pipeline.

    Persist 'previous' from the previous poll keyed by deviceId. Do not alert
    repeatedly while the state remains unchanged. The platform's own OFFLINE
    alerts have priority; avoid duplicate platform/driver alerts.
    """
    if previous is None or current is None:
        return None
    before = previous.get("link_state")
    after = current.get("link_state")
    if before == after:
        return None
    if current.get("platform_health") == "OFFLINE":
        return None
    if after == "suspect":
        return {"event": "type6_link_suspect", "severity": "warning", "title": "TYPE6 통신 끊김 의심"}
    if before == "suspect" and after == "normal":
        return {"event": "type6_link_recovered", "severity": "recovery", "title": "TYPE6 통신 정상 복구"}
    return None
