from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"

# Official BI Community Wiki contracts used by this validator:
# - allPlayers includes Headless Clients / curators / spectators; filter VirtualMan_F
# - createVehicle "FLY" only guarantees airborne placement when crew already exists
# - setDir should precede setPos, and setVectorDirAndUp requires a coherent direction/up frame
# - isPlayer is true for Headless Clients; remoteExecutedOwner can be zero for HC/outside remote execution

SERVER_GUARD_RE = re.compile(r"if\s*\(\s*!isServer\s*\)\s*exitWith")
FLY_RE = re.compile(r'createVehicle\s*\[[^\n;]*"FLY"')
FIXED_UP_RE = re.compile(
    r"setVectorDirAndUp\s*\[\s*_[A-Za-z0-9_]+\s*,\s*"
    r"\[\s*0\s*,\s*0\s*,\s*1\s*\]\s*\]"
)
SIDE_LEAK_RE = re.compile(
    r"\bin\s*\[\s*_[A-Za-z0-9_]*sideNumber\s*,\s*2\s*\]",
    re.IGNORECASE,
)


def read(relative: str) -> str:
    path = ROOT / relative
    return path.read_text(encoding="utf-8", errors="replace")


def line_at(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def check_fly_contract(path: Path, source: str, errors: list[str]) -> None:
    for match in FLY_RE.finditer(source):
        window = source[match.start() : match.start() + 1000]
        crew_candidates = [
            value
            for value in (
                window.find("createVehicleCrew"),
                window.find("BIS_fnc_spawnVehicle"),
            )
            if value >= 0
        ]
        if not crew_candidates:
            continue

        crew_at = min(crew_candidates)
        set_position_candidates = [
            value
            for value in (
                window.find("setPosATL"),
                window.find("setPosASL"),
            )
            if value >= 0
        ]
        if not set_position_candidates or min(set_position_candidates) > crew_at:
            errors.append(
                f"{path.relative_to(ROOT)}:{line_at(source, match.start())}: "
                "empty FLY airframe is crewed before explicit setPosATL/setPosASL"
            )


def require(
    errors: list[str],
    relative: str,
    required: tuple[str, ...] = (),
    forbidden: tuple[str, ...] = (),
) -> None:
    source = read(relative)
    missing = [token for token in required if token not in source]
    blocked = [token for token in forbidden if token in source]
    if missing:
        errors.append(f"{relative}: missing {', '.join(missing)}")
    if blocked:
        errors.append(f"{relative}: forbidden {', '.join(blocked)}")


errors: list[str] = []
warnings: list[str] = []

sqf_files = sorted(DRO.rglob("*.sqf"))
for path in sqf_files:
    source = path.read_text(encoding="utf-8", errors="replace")

    if SERVER_GUARD_RE.search(source[:900]) and "allPlayers" in source:
        if 'isKindOf "VirtualMan_F"' not in source:
            errors.append(
                f"{path.relative_to(ROOT)}: server-side allPlayers is not filtered for VirtualMan_F"
            )

    check_fly_contract(path, source, errors)

    for match in FIXED_UP_RE.finditer(source):
        errors.append(
            f"{path.relative_to(ROOT)}:{line_at(source, match.start())}: "
            "pitched setVectorDirAndUp uses fixed world-up"
        )

    for match in SIDE_LEAK_RE.finditer(source):
        errors.append(
            f"{path.relative_to(ROOT)}:{line_at(source, match.start())}: "
            "INDEPENDENT side leaks into another side pool"
        )

require(
    errors,
    "dro2026/functions/support/fn_serverRequestSupport.sqf",
    required=(
        "isPlayer _requester",
        'isKindOf "VirtualMan_F"',
        "remoteExecutedOwner",
        "isDedicated",
        "_remoteOwner <= 2",
        "owner _requester",
    ),
)
require(
    errors,
    "dro2026/functions/core/fn_refreshFactionAssets.sqf",
    required=(
        "ENEMY_CAS_AIR",
        "ePlaneClasses",
        "eHeliClasses",
        "_cfgSide == _sideNumber",
    ),
)
require(
    errors,
    "dro2026/functions/core/fn_publishSupportCatalog.sqf",
    required=('getNumber (_cfg >> "side") != _sideNumber',),
)
require(
    errors,
    "dro2026/functions/directors/fn_enemyAirDirector.sqf",
    required=(
        "ENEMY_CAS_AIR",
        'getNumber (_cfg >> "side") == _enemySideNumber',
        "setPosATL _spawn",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
    forbidden=('getOrDefault ["AIR_EAST"',),
)
require(
    errors,
    "dro2026/functions/directors/fn_enemyISRDirector.sqf",
    required=(
        'isKindOf "VirtualMan_F"',
        "setPosATL _spawn",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
)
require(
    errors,
    "dro2026/functions/support/fn_launchISR.sqf",
    required=(
        "_selectionValid",
        'getNumber (_classCfg >> "side")',
        "setPosATL _spawn",
        "_refundReservation",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
)
require(
    errors,
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    required=(
        "_applyFlightVector",
        "vectorCrossProduct",
        "setVectorDirAndUp",
        "side-correct registry",
        "setPosATL _spawnPosition",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
    forbidden=("nearestObjects",),
)
require(
    errors,
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    required=(
        "_selectionValid",
        "_exactClass in _pool",
        "_applyFlightVector",
        "vectorCrossProduct",
        "setVectorDirAndUp",
        "setPosASL _spawnASL",
        "LONG_RANGE_LAUNCH_REFUND",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
    forbidden=("nearestObjects",),
)
require(
    errors,
    "dro2026/functions/support/fn_requestAirSupport.sqf",
    required=(
        "setPosATL _spawn",
        "deleteVehicleCrew",
        "deleteGroup",
    ),
)
require(
    errors,
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
    required=(
        "_isLiveStrategicContact",
        'isKindOf "VirtualMan_F"',
        "LONG_RANGE_SALVO_ABORT",
    ),
)
require(
    errors,
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf",
    required=(
        'isKindOf "VirtualMan_F"',
        "_canUseFP5",
        "_strategicAvailable",
    ),
)
require(
    errors,
    "dro2026/functions/directors/fn_sensorDirector.sqf",
    required=('isKindOf "VirtualMan_F"',),
)
require(
    errors,
    "dro2026/functions/objectives/fn_objectiveISRRecon.sqf",
    required=('isKindOf "VirtualMan_F"',),
)
require(
    errors,
    "dro2026/functions/directors/fn_relocateDroneTeam.sqf",
    required=('isKindOf "VirtualMan_F"',),
)
require(
    errors,
    "dro2026/functions/directors/fn_logisticsDirector.sqf",
    required=(
        'isKindOf "VirtualMan_F"',
        "_setActiveConvoyStatus",
        '"INTERDICTED"',
        '"DELIVERED"',
        "deleteGroup _deliveryGroup",
    ),
)

report = {
    "validator": "arma-wiki-contracts",
    "sqf_files_scanned": len(sqf_files),
    "errors": errors,
    "warnings": warnings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors else 0)
