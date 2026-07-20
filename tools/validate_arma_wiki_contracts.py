from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"
SOURCE_MANIFEST = ROOT / "tools" / "arma_source_manifest.json"

# Source hierarchy is defined in tools/arma_source_manifest.json:
# - BI Community Wiki: primary engine/locality/network semantics
# - acemod/arma3-wiki: machine-readable command data mirror (dist branch)
# - Stokys guide: secondary mission/event-script guidance only
# - Context7 HEMTT: parser/analyzer/build tooling only
# This validator is intentionally offline and deterministic.

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
    return (ROOT / relative).read_text(encoding="utf-8", errors="replace")


def line_at(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def check_fly_contract(path: Path, source: str, errors: list[str]) -> None:
    for match in FLY_RE.finditer(source):
        window = source[match.start() : match.start() + 1100]
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
                window.find("setPosWorld"),
            )
            if value >= 0
        ]
        if not set_position_candidates or min(set_position_candidates) > crew_at:
            errors.append(
                f"{path.relative_to(ROOT)}:{line_at(source, match.start())}: "
                "empty FLY airframe is crewed before explicit position"
            )


def require(
    errors: list[str],
    relative: str,
    required: tuple[str, ...] = (),
    forbidden: tuple[str, ...] = (),
) -> None:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"{relative}: missing")
        return
    source = path.read_text(encoding="utf-8", errors="replace")
    missing = [token for token in required if token not in source]
    blocked = [token for token in forbidden if token in source]
    if missing:
        errors.append(f"{relative}: missing {', '.join(missing)}")
    if blocked:
        errors.append(f"{relative}: forbidden {', '.join(blocked)}")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    if not SOURCE_MANIFEST.is_file():
        errors.append("tools/arma_source_manifest.json: missing")
    else:
        try:
            manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
            source_ids = {
                item.get("id")
                for item in manifest.get("sources", [])
                if isinstance(item, dict)
            }
            for required_source in (
                "bohemia-community-wiki",
                "acemod-arma3-wiki",
                "stokys-scripting-guide",
            ):
                if required_source not in source_ids:
                    errors.append(f"source manifest missing {required_source}")
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"source manifest unreadable: {exc}")

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
        "dro2026/functions/core/fn_resolveRemoteRequester.sqf",
        required=(
            "isPlayer _x",
            'isKindOf "VirtualMan_F"',
            "remoteExecutedOwner",
            "isDedicated",
            "_remoteOwner <= 2",
            "owner _x",
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_getSideRoleClass.sqf",
        required=(
            "DRO2026_assetRegistry getOrDefault",
            'getNumber (_cfg >> "side")',
            "selectRandom _valid",
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
            "DRO2026_fnc_getSideSuffix",
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_publishSupportCatalog.sqf",
        required=('getNumber (_cfg >> "side") != _sideNumber',),
    )
    require(
        errors,
        "dro2026/functions/core/fn_createDroneTeam.sqf",
        required=(
            "if (isNull _operator) exitWith",
            "deleteGroup _group",
            "createHashMap",
        ),
    )
    for relative in (
        "dro2026/functions/core/fn_spawnStrategicHQ.sqf",
        "dro2026/functions/core/fn_spawnLayeredAA.sqf",
        "dro2026/functions/core/fn_spawnStrategicDroneSite.sqf",
    ):
        require(
            errors,
            relative,
            required=("validateSiteRecord", "deleteGroup", "deleteVehicle"),
        )
    require(
        errors,
        "dro2026/functions/core/fn_resolveContactSubject.sqf",
        required=(
            '"PROBABLY_DESTROYED"',
            '"CONFIRMED_DESTROYED"',
            '"CANCELLED"',
            'isKindOf "VirtualMan_F"',
            "objectFromNetId",
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_getAirWindow.sqf",
        required=(
            '"DESTROYED", "DISABLED", "CANCELLED"',
            'isKindOf "VirtualMan_F"',
            '"friendliesClose"',
            '"civiliansClose"',
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_getJammingAtPosition.sqf",
        required=(
            '"DESTROYED", "DISABLED", "CANCELLED"',
            "terrainIntersectASL",
            "jammingRadius",
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_evaluateOperationPhase.sqf",
        required=(
            "if (count _node == 0)",
            'case "CANCELLED"',
            '"PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_selectObjectiveOpportunity.sqf",
        required=(
            "_excludedTypes",
            'missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap]',
            '"DESTROYED", "DISABLED", "CANCELLED"',
            '"deterministic active-node fallback"',
            '"deterministic vanilla materialization fallback"',
            '"NO_OBJECTIVE_OPPORTUNITY"',
        ),
    )
    require(
        errors,
        "dro2026/functions/objectives/fn_selectObjective.sqf",
        required=(
            "_attemptedTypes",
            "DRO2026_usedObjectiveTypes pushBackUnique _type",
            "DRO2026_usedObjectiveNodes pushBackUnique _nodeId",
            '"OBJECTIVE_MATERIALIZATION_FAILED"',
            '"OBJECTIVE_SELECTION_EXHAUSTED"',
        ),
        forbidden=('_selectedType = "CUT_REAR"',),
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
            'missionNamespace getVariable ["DRO2026_missionEnding", false]',
        ),
        forbidden=('getOrDefault ["AIR_EAST"', "vehicle player", "alive player"),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_enemyISRDirector.sqf",
        required=(
            'isKindOf "VirtualMan_F"',
            "setPosATL _spawn",
            "deleteVehicleCrew",
            "deleteGroup",
            'missionNamespace getVariable ["DRO2026_missionEnding", false]',
        ),
    )
    require(
        errors,
        "dro2026/functions/support/fn_requestISR.sqf",
        required=(
            '"FRIENDLY_DRONE_SITE"',
            '"DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"',
            'getOrDefault ["id", ""]',
            "materialization",
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
            "_siteOperational",
            '"DRONE_RECOVERED"',
            '"DRONE_LOST"',
            'DRO2026_resources set ["friendlyISRStock"',
            "_returnDeadline",
            "_recoveryRadius",
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
            "_reservationNodeId",
            "FPV_LAUNCH_REFUND",
            "deleteVehicleCrew",
            "deleteGroup",
        ),
        forbidden=("nearestObjects", "_drone setDir"),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_enemyFPVDirector.sqf",
        required=(
            "FPV_SALVO_ABORT",
            "_unlaunched",
            "DRO2026_fnc_launchFPVStrike",
        ),
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
        forbidden=("nearestObjects", "_drone setDir"),
    )
    require(
        errors,
        "dro2026/functions/support/fn_requestAirSupport.sqf",
        required=(
            "setPosATL _spawn",
            "_refundTail",
            '"MISSION_ENDING"',
            '"TARGETS_LOST_BEFORE_LAUNCH"',
            '"AIR_WINDOW_CLOSED_BEFORE_LAUNCH"',
            "deleteVehicleCrew",
            "deleteGroup",
        ),
    )
    require(
        errors,
        "dro2026/functions/support/fn_requestArtillery.sqf",
        required=(
            'isKindOf "VirtualMan_F"',
            "DRO2026_supportGroup",
            "deleteVehicleCrew",
            "deleteGroup",
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
        required=(
            "DRO2026_fnc_isLiveContactSubject",
            "LONG_RANGE_SALVO_ABORT",
            "_unlaunched",
            '"CANCELLED"',
        ),
        forbidden=("private _isLiveStrategicContact",),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf",
        required=(
            'isKindOf "VirtualMan_F"',
            "_catalogHasMode",
            '"STRIKE_FP5"',
            '"STRIKE_AUTO"',
            "_canUseFP5",
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_operationDirector.sqf",
        required=(
            "DRO2026_fnc_isLiveContactSubject",
            '"DESTROYED", "DISABLED", "CANCELLED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_airDefenceDirector.sqf",
        required=(
            'getText (_ammoCfg >> "simulation")',
            '"shotmissile"',
            '"shotrocket"',
            "deleteVehicle _projectile",
            '"AA_LAUNCH_REJECTED"',
            '"DESTROYED", "DISABLED", "CANCELLED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_relocateDroneTeam.sqf",
        required=(
            'isKindOf "VirtualMan_F"',
            '"DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"',
            'getOrDefault ["assistant", objNull]',
            '"physicalRefs", _objects',
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_reactionDirector.sqf",
        required=(
            "DRO2026_fnc_isLiveContactSubject",
            "_hqStatus",
            '"DESTROYED", "DISABLED", "CANCELLED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_civilianIntelDirector.sqf",
        required=(
            'isKindOf "VirtualMan_F"',
            '"DESTROYED", "DISABLED", "CANCELLED"',
            '"falseProbability"',
        ),
    )
    for relative in (
        "dro2026/functions/directors/fn_sensorDirector.sqf",
        "dro2026/functions/objectives/fn_objectiveISRRecon.sqf",
    ):
        require(errors, relative, required=('isKindOf "VirtualMan_F"',))
    require(
        errors,
        "dro2026/functions/directors/fn_logisticsDirector.sqf",
        required=(
            "DRO2026_MAX_ACTIVE_LOGISTICS_JOBS_PER_SIDE",
            "_setSiteState",
            '"siteRecord"',
            '"DELIVERY_INTERDICTED"',
            '"DELIVERY_COMPLETED"',
            '"CANCELED"',
            '"COMPLETE"',
            '"DESTROYED"',
            '"DISABLED"',
            "_cleanupJob",
            "DRO2026_fnc_transferLogisticsCargo",
        ),
    )
    require(
        errors,
        "dro2026/functions/objectives/fn_objectiveConvoy.sqf",
        required=(
            "validateSiteRecord",
            '"OBJECTIVE_CONVOY_REFUND"',
            '"OBJECTIVE_CONVOY_CANCELLED"',
            '"CANCELLED"',
            '"INTERDICTED"',
            '"DELIVERED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/objectives/fn_artilleryLoop.sqf",
        required=(
            'missionNamespace getVariable ["DRO2026_missionEnding", false]',
            "doArtilleryFire",
            '"ARTILLERY_AMMO", -_rounds',
        ),
    )

    report = {
        "validator": "arma-wiki-contracts",
        "source_manifest": SOURCE_MANIFEST.relative_to(ROOT).as_posix(),
        "sqf_files_scanned": len(sqf_files),
        "errors": errors,
        "warnings": warnings,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
