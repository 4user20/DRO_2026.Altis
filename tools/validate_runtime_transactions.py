from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"

# Every inner tuple is an alternative group: at least one token must be present.
# Every group listed for a file is mandatory.
REQUIRED: dict[str, tuple[tuple[str, ...], ...]] = {
    "dro2026/CfgFunctions.hpp": (
        ("class isLiveContactSubject {};",),
        ("class getSideRoleClass {};",),
        ("class crewManagedVehicle {};",),
        ("class spawnLayeredAA {};",),
    ),
    "dro2026/functions/core/fn_resolveContactSubject.sqf": (
        ('"PROBABLY_DESTROYED"',),
        ('"CONFIRMED_DESTROYED"',),
        ('"CANCELLED"',),
        ('isKindOf "VirtualMan_F"',),
        ("objectFromNetId",),
    ),
    "dro2026/functions/core/fn_createDroneTeam.sqf": (
        ("if (isNull _group) exitWith",),
        ("if (isNull _operator) exitWith",),
        ("deleteGroup _group",),
        ("createHashMap",),
    ),
    "dro2026/functions/core/fn_spawnGuard.sqf": (
        ("if (isNull _group) exitWith {grpNull};",),
        ("({alive _x} count units _group) == 0",),
        ("deleteGroup _group",),
        ("DRO2026_fnc_registerManagedGroup",),
    ),
    "dro2026/functions/core/fn_spawnStrategicHQ.sqf": (
        ("validateSiteRecord",),
        ("deleteGroup _group",),
        ("deleteVehicle _x",),
    ),
    "dro2026/functions/core/fn_spawnLayeredAA.sqf": (
        ("_deleteMaterialized",),
        ("validateSiteRecord",),
        ("deleteVehicleCrew",),
    ),
    "dro2026/functions/core/fn_spawnStrategicDroneSite.sqf": (
        ("validateSiteRecord",),
        ("deleteGroup _group",),
        ("deleteVehicle _object",),
    ),
    "dro2026/functions/core/fn_createFriendlyPositions.sqf": (
        ("switch (playersSide)",),
        ('default {["O_Soldier_F", "O_Soldier_AR_F", "O_medic_F"]};',),
        ("if (!isNull _group)",),
        ("if (!isNull _unit)",),
        ("deleteGroup _group",),
    ),
    "dro2026/functions/core/fn_createFriendlyLogisticsSite.sqf": (
        ("[playersSide] call DRO2026_fnc_getSideNumber",),
        ('getNumber (_cfg >> "side") == _sideNumber',),
        ("DRO2026_fnc_isSafeInfantryClass",),
        ("validateSiteRecord",),
        ("deleteGroup _group",),
        ("createHashMap",),
    ),
    "dro2026/functions/core/fn_getAirWindow.sqf": (
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
        ('isKindOf "VirtualMan_F"',),
        ('"friendliesClose"',),
        ('"civiliansClose"',),
    ),
    "dro2026/functions/core/fn_getJammingAtPosition.sqf": (
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
        ("terrainIntersectASL",),
        ("jammingRadius",),
    ),
    "dro2026/functions/core/fn_evaluateOperationPhase.sqf": (
        ("if (count _node == 0)",),
        ('case "CANCELLED"',),
        ('"PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"',),
        ('"destroyedCapabilities"',),
    ),
    "dro2026/functions/core/fn_selectObjectiveOpportunity.sqf": (
        ("_excludedTypes",),
        ('missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap]',),
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
        ('"deterministic active-node fallback"',),
        ('"deterministic vanilla materialization fallback"',),
        ('"NO_OBJECTIVE_OPPORTUNITY"',),
    ),
    "dro2026/functions/objectives/fn_selectObjective.sqf": (
        ("_attemptedTypes",),
        ("DRO2026_usedObjectiveTypes pushBackUnique _type",),
        ("DRO2026_usedObjectiveNodes pushBackUnique _nodeId",),
        ('"OBJECTIVE_MATERIALIZATION_FAILED"',),
        ('"OBJECTIVE_SELECTION_EXHAUSTED"',),
        ('missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap]',),
    ),
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        ('"FPV_KITS", 1, "FPV_LAUNCH_REFUND"',),
        ('"BATTERIES", 1, "FPV_LAUNCH_REFUND"',),
        ('"enemyDroneStock"',),
        ("_reservationNodeId",),
    ),
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf": (
        ('"FPV_SALVO_ABORT"',),
        ("_unlaunched",),
        ("DRO2026_fnc_launchFPVStrike",),
    ),
    "dro2026/functions/support/fn_requestFPV.sqf": (
        ("FPV salvo aborted",),
        ("_unlaunched",),
        ('"friendlyFPVStock"',),
    ),
    "dro2026/functions/support/fn_requestISR.sqf": (
        ('"FRIENDLY_DRONE_SITE"',),
        ('"DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"',),
        ('getOrDefault ["id", ""]',),
        ("materialization",),
        ("DRO2026_fnc_launchISR",),
    ),
    "dro2026/functions/support/fn_launchISR.sqf": (
        ("_siteOperational",),
        ('"DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"',),
        ('"DRONE_RECOVERED"',),
        ('"DRONE_LOST"',),
        ('DRO2026_resources set ["friendlyISRStock"',),
        ("_returnDeadline",),
        ("_recoveryRadius",),
        ("deleteVehicleCrew _uav",),
        ("deleteGroup _group",),
    ),
    "dro2026/functions/support/fn_requestAirSupport.sqf": (
        ("_refundTail",),
        ('"MISSION_ENDING"',),
        ('"TARGETS_LOST_BEFORE_LAUNCH"',),
        ('"AIR_WINDOW_CLOSED_BEFORE_LAUNCH"',),
    ),
    "dro2026/functions/support/fn_requestArtillery.sqf": (
        ('isKindOf "VirtualMan_F"',),
        ("DRO2026_supportGroup",),
        ("deleteVehicleCrew",),
        ("deleteGroup",),
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        ("DRO2026_fnc_isLiveContactSubject",),
        ('"LONG_RANGE_SALVO_ABORT"',),
        ("_unlaunched",),
        ('"CANCELLED"',),
    ),
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf": (
        ("_catalogHasMode",),
        ('"STRIKE_FP5"',),
        ('"STRIKE_AUTO"',),
    ),
    "dro2026/functions/directors/fn_operationDirector.sqf": (
        ("DRO2026_fnc_isLiveContactSubject",),
        ('"PROBABLY_DESTROYED"',),
        ('"CONFIRMED_DESTROYED"',),
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
    ),
    "dro2026/functions/directors/fn_airDefenceDirector.sqf": (
        ('getText (_ammoCfg >> "simulation")',),
        ('"shotmissile"',),
        ('"shotrocket"',),
        ("deleteVehicle _projectile",),
        ('"AA_LAUNCH_REJECTED"',),
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
    ),
    "dro2026/functions/directors/fn_enemyAirDirector.sqf": (
        ('missionNamespace getVariable ["DRO2026_missionEnding", false]',),
        ("deleteVehicleCrew",),
        ("deleteGroup",),
    ),
    "dro2026/functions/directors/fn_enemyISRDirector.sqf": (
        ('missionNamespace getVariable ["DRO2026_missionEnding", false]',),
        ("deleteVehicleCrew",),
        ("deleteGroup",),
    ),
    "dro2026/functions/directors/fn_relocateDroneTeam.sqf": (
        ('"DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"',),
        ('getOrDefault ["assistant", objNull]',),
        ('"physicalRefs", _objects',),
        ('"disabledAt"',),
    ),
    "dro2026/functions/objectives/fn_objectiveConvoy.sqf": (
        ("validateSiteRecord",),
        ('"OBJECTIVE_CONVOY_REFUND"',),
        ('"OBJECTIVE_CONVOY_CANCELLED"',),
        ('"CANCELLED"',),
        ('"INTERDICTED"',),
        ('"DELIVERED"',),
        ("_cleanup",),
    ),
    "dro2026/functions/directors/fn_logisticsDirector.sqf": (
        ("DRO2026_fnc_findRoadAwarePosition",),
        ("DRO2026_fnc_transferLogisticsCargo",),
        ('"DELIVERY_RESERVED"',),
        ('"DELIVERY_MATERIALIZATION_REFUND"',),
        ('"DELIVERY_INTERDICTED"',),
        ('"DELIVERY_COMPLETED"',),
        ('"RETURNING"',),
        ('"reservationSettled"',),
        ("_cleanupJob",),
        ("deleteVehicleCrew _x",),
        ("deleteGroup _group",),
    ),
    "dro2026/functions/objectives/fn_artilleryLoop.sqf": (
        ('missionNamespace getVariable ["DRO2026_missionEnding", false]',),
        ("doArtilleryFire",),
        ('"ARTILLERY_AMMO", -_rounds',),
    ),
    "dro2026/functions/directors/fn_civilTrafficDirector.sqf": (
        ("if (isNull _group)",),
        ("objectParent _driver == _vehicle",),
        ("_vehicle deleteVehicleCrew _driver",),
        ("deleteVehicleCrew _vehicle",),
    ),
    "dro2026/functions/directors/fn_civilianIntelDirector.sqf": (
        ('isKindOf "VirtualMan_F"',),
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
        ('"falseProbability"',),
        ('"uncertainty"',),
    ),
    "dro2026/functions/directors/fn_reactionDirector.sqf": (
        ('"pausedUntil"',),
        ('"ROUTE_RESUMED"',),
        ("DRO2026_fnc_isLiveContactSubject",),
        ('"MATERIALIZATION_FAILED_OR_MISSION_ENDING"',),
        ("alive _leader",),
        ("_hqStatus",),
        ('"DESTROYED", "DISABLED", "CANCELLED"',),
    ),
    "dro2026/functions/directors/fn_orderEncirclement.sqf": (
        ('getOrDefault ["positionMean"',),
        ("alive _leader",),
        ('"DRO2026_reactionUntil"',),
    ),
    "dro2026/functions/objectives/fn_objectiveISRRecon.sqf": (
        ("if (isNull _group) exitWith",),
        ("deleteMarker _marker",),
        ("validateSiteRecord",),
    ),
}

FORBIDDEN: dict[str, tuple[str, ...]] = {
    "dro2026/functions/directors/fn_logisticsDirector.sqf": (
        '!missionNamespace getVariable ["DRO2026_missionEnding"',
    ),
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        "nearestObjects",
        "_drone setDir",
    ),
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf": (
        "nearestObjects",
        "_drone setDir",
    ),
    "dro2026/functions/directors/fn_enemyAirDirector.sqf": (
        'getOrDefault ["AIR_EAST"',
        "vehicle player",
        "alive player",
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        "private _isLiveStrategicContact",
    ),
    "dro2026/functions/objectives/fn_selectObjective.sqf": (
        '_selectedType = "CUT_REAR"',
        'DRO2026_usedObjectiveTypes pushBackUnique _type;\n    if',
    ),
}

AMBIGUOUS_NOT = re.compile(
    r"!\s*(?:missionNamespace|uiNamespace|profileNamespace|parsingNamespace)\s+getVariable\b"
)
EMPTY_FLY = re.compile(r'createVehicle\s*\[[^;\n]*"FLY"')


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="replace")


def line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def check_empty_fly(path: Path, source: str, errors: list[str]) -> None:
    for match in EMPTY_FLY.finditer(source):
        window = source[match.end() : match.end() + 1000]
        if not any(token in window for token in ("setPosATL", "setPosASL", "setPosWorld")):
            errors.append(
                f"{path.relative_to(ROOT).as_posix()}:{line_number(source, match.start())}: "
                "empty FLY materialization lacks explicit position"
            )


def main() -> int:
    errors: list[str] = []

    for relative, groups in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative}: missing")
            continue
        source = read(relative)
        for alternatives in groups:
            if not any(snippet in source for snippet in alternatives):
                errors.append(
                    f"{relative}: missing one of {', '.join(repr(item) for item in alternatives)}"
                )

    for relative, snippets in FORBIDDEN.items():
        path = ROOT / relative
        if not path.is_file():
            continue
        source = read(relative)
        for snippet in snippets:
            if snippet in source:
                errors.append(f"{relative}: forbidden contract {snippet!r}")

    for path in DRO.rglob("*.sqf"):
        source = path.read_text(encoding="utf-8", errors="replace")
        relative = path.relative_to(ROOT).as_posix()
        for match in AMBIGUOUS_NOT.finditer(source):
            errors.append(
                f"{relative}:{line_number(source, match.start())}: "
                "ambiguous unary ! before namespace getVariable"
            )
        check_empty_fly(path, source, errors)

    if errors:
        print("Runtime transaction validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Runtime transaction validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
