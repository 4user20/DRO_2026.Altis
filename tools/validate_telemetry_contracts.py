from __future__ import annotations
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

cfg = read("dro2026/CfgFunctions.hpp")
pre = read("dro2026/functions/core/fn_preInit.sqf")
record = read("dro2026/functions/core/fn_telemetryRecord.sqf")
start = read("dro2026/functions/core/fn_startTelemetry.sqf")
emit = read("dro2026/functions/core/fn_emitEvent.sqf")
perf = read("dro2026/functions/directors/fn_performanceGovernor.sqf")
group = read("dro2026/functions/core/fn_registerManagedGroup.sqf")
vehicle = read("dro2026/functions/core/fn_crewManagedVehicle.sqf")
directors = read("dro2026/functions/directors/fn_startDirectors.sqf")
support = read("dro2026/functions/support/fn_serverRequestSupport.sqf")

checks = {
    "functions registered": all(token in cfg for token in [
        "class telemetryRecord {};", "class startTelemetry {};",
        "class telemetryObjectSnapshot {};", "class telemetryMark {};",
        "class isTelemetryOwnedObject {};"
    ]),
    "runtime modes": all(token in pre for token in [
        'DRO2026_TELEMETRY_MODE = "VERBOSE"', "DRO2026_TELEMETRY_INTERVAL",
        "DRO2026_TELEMETRY_POSITION_BUCKET", "DRO2026_TELEMETRY_MAX_TRACKED_ENTITIES"
    ]),
    "signature aware limiter": all(token in record for token in [
        "DRO2026_telemetryDedupe", "signature", "suppressed", "_minInterval", "[D26T]"
    ]),
    "all mod events bridged": all(token in emit for token in [
        'DRO2026_telemetryEventIntervalCounts', '["EVENT", _type', "DRO2026_fnc_telemetryRecord"
    ]),
    "bounded managed scans": all(token in start for token in [
        "DRO2026_managedVehicles", "DRO2026_managedGroups", "DRO2026_sites",
        "DRO2026_networkNodes", "DRO2026_TELEMETRY_MAX_TRACKED_ENTITIES"
    ]),
    "no frame or global vehicle scan": 'addMissionEventHandler ["EachFrame"' not in start and "forEach allVehicles" not in start and "count allVehicles" not in start,
    "contact snapshot copies global array": 'private _contacts = +(missionNamespace getVariable ["DRO2026_contacts", []]);' in start,
    "mission lifecycle handlers": all(token in start for token in [
        '"EntityKilled"', '"EntityDeleted"', '"PlayerConnected"',
        '"PlayerDisconnected"', '"HandleDisconnect"', '"MPEnded"'
    ]),
    "active scripts summarized": "count diag_activeSQFScripts" in perf and '["activeScripts",diag_activeSQFScripts]' not in perf,
    "managed registration telemetry": "DRO2026_telemetryId" in group and "CREW_CREATED" in vehicle,
    "support ingress telemetry": all(token in support for token in ["NORMALIZATION_REJECTED", "IDENTITY_REJECTED", "DUPLICATE_REQUEST", "RATE_LIMITED", "REQUEST_RECEIVED"]),
    "telemetry director started": "DRO2026_fnc_startTelemetry" in directors and "START_BATCH" in directors,
}
result = {
    "validator": "bounded-telemetry-contracts",
    "passed": sum(checks.values()),
    "total": len(checks),
    "checks": [{"name": k, "ok": v} for k, v in checks.items()],
}
print(json.dumps(result, ensure_ascii=False, indent=2))
sys.exit(0 if all(checks.values()) else 1)
