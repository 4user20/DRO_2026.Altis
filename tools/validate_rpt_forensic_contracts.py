from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


checks: list[dict[str, object]] = []


def require(name: str, condition: bool, detail: str) -> None:
    checks.append({"name": name, "passed": bool(condition), "detail": detail})


begin = read("dro2026/functions/support/fn_beginSupportTargeting.sqf")
request = read("dro2026/functions/support/fn_requestFPV.sqf")
flight = read("dro2026/functions/core/fn_buildWaypointFlightPlan.sqf")
resolver = read("dro2026/functions/core/fn_resolveLauncherAmmo.sqf")

require(
    "fpv_ui_uses_hashmap_contract",
    '["channel", "FPV"]' in begin
    and '["targetPositionASL", AGLToASL _targetPosition]' in begin
    and '[_position, false, _quantity, _mode select [15]] call DRO2026_fnc_requestFPV' not in begin,
    "The UI adapter must emit one normalized HashMap request instead of ambiguous positional arguments.",
)
require(
    "fpv_handler_normalizes_legacy_shapes",
    'case (_requestOrPosition isEqualType createHashMap)' in request
    and 'case (_requestOrPosition isEqualType [])' in request
    and 'case (_requestOrPosition isEqualType "")' in request
    and "INVALID_REQUEST_SHAPE" in request,
    "HashMap, Array and String inputs must be normalized or rejected structurally before typed engine params can fail.",
)
require(
    "fpv_request_correlation",
    "FPV_REQUEST_ACCEPTED" in request
    and "FPV_LAUNCH_ABORTED" in request
    and '["requestId", _requestId]' in request,
    "Accepted and aborted FPV transactions must retain the requestId.",
)
require(
    "destroy_waypoint_requires_object",
    "waypointAttachObject _targetObject" in flight
    and 'if (_hasConcreteTarget) then {"DESTROY"} else {"MOVE"}' in flight
    and '["FLIGHT", "POSITIONAL_STRIKE_ROUTE"' in flight,
    "A spatial strike route must use MOVE; DESTROY is permitted only when attached to a live object.",
)
require(
    "launcher_ammo_resolves_muzzles_and_wells",
    'getArray (_weaponCfg >> "muzzles")' in resolver
    and "compatibleMagazines _weapon" in resolver
    and "compatibleMagazines [_weapon, _x]" in resolver,
    "Launcher resolution must inspect inherited weapons, muzzles and magazine-well compatibility.",
)
require(
    "launcher_ammo_rejects_nonlethal_effects",
    '"smoke", "flare", "chaff"' in resolver
    and '"fake", "dummy", "horn"' in resolver
    and 'if ((_simulation find "shotmissile") >= 0)' in resolver,
    "Smoke, countermeasure and dummy ammo must not be selected as strategic launch ammunition.",
)

failed = [check for check in checks if not check["passed"]]
print(
    json.dumps(
        {
            "validator": "rpt-forensic-contracts",
            "failed": bool(failed),
            "checks": checks,
        },
        ensure_ascii=False,
        indent=2,
    )
)
sys.exit(1 if failed else 0)
