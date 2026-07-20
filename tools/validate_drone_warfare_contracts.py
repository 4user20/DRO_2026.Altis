from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def require(errors: list[str], relative: str, required: tuple[str, ...] = (), forbidden: tuple[str, ...] = ()) -> None:
    try:
        source = read(relative)
    except FileNotFoundError:
        errors.append(f"{relative}: missing")
        return
    for token in required:
        if token not in source:
            errors.append(f"{relative}: missing {token!r}")
    for token in forbidden:
        if token in source:
            errors.append(f"{relative}: forbidden {token!r}")


def main() -> int:
    errors: list[str] = []
    require(errors, "dro2026/functions/drone/fn_hasDDT.sqf", (
        "CfgPatches", "DrongosDroneTweaks", "isServer"
    ))
    require(errors, "dro2026/functions/drone/fn_waitDDTReady.sqf", (
        "ddtReady", "_deadline", "DRO2026_missionEnding", "ddtDeploySides", "ddtCycleUnassigned"
    ), ('waitUntil {missionNamespace getVariable ["ddtReady", false]}',))
    require(errors, "dro2026/functions/drone/fn_configureDDT.sqf", (
        "DRO2026_DDT_OVERRIDE_SETTINGS", "ddtCycleRecon", "ddtCycleAttack",
        "ddtCycleUnassigned", "-1", "ddtClassesFPV", "DRA_UAV_01_O",
        "DRA_UAV_01_0", "DRO2026_DDT_DISABLE_NATIVE_JAMMERS", "ddtDeploySides", "[]", "DRO2026_ddtDeploySides"
    ), ("DDT_fnc_", "compile preprocessFile"))
    require(errors, "dro2026/functions/drone/fn_initializeDroneRegistry.sqf", (
        "frtz_drone_kvn_base_F", "frtz_KVN_Base", "frtz_%1_KVN_%2%3",
        "_20KM", "_25KM", "_Bag", "frtz_Item_KVN_", "isClass",
        "DDT_AR2_FPV_AP_backpack_O", "DRA_UAV_01_O", "DRA_UAV_01_0"
    ))
    require(errors, "dro2026/functions/drone/fn_isFiberOpticDrone.sqf", (
        'isKindOf "frtz_drone_kvn_base_F"', 'isKindOf "frtz_KVN_Base"',
        "_kvn_", "DRO2026_droneClassMetadata"
    ))
    require(errors, "dro2026/functions/drone/fn_dispatchDDTDrones.sqf", (
        "isServer", "DRO2026_ddtDeploySides", "DDT_fnc_GroupDeployUAV",
        "DDT_fnc_GetTargetsAT", "DDT_fnc_GetSoftTargets", "DDT_fnc_GetTargetsBomber",
        "serverTime", "ddtCooldown", "simulationEnabled"
    ), ("allUnitsUAV", "spawn DDT_fnc_"))
    require(errors, "dro2026/functions/drone/fn_assignDroneLoadout.sqf", (
        "isServer", "isPlayer", "DRO2026_MAX_DDT_EQUIPPED_GROUPS",
        "DRO2026_ALLOW_MILITIA_DRONES", "DRO2026_contacts", "FPV_AT_TI",
        "addBackpackGlobal", "canAdd", "_knownMappedItem", '_assembled != ""'
    ), ("allUnitsUAV",))
    require(errors, "dro2026/functions/drone/fn_collectDroneIntel.sqf", (
        "targets [true", "knowsAbout", "UAV_FIBEROPTIC", "DRO2026_fnc_addContact",
        "uncertainty", "sunOrMoon"
    ), ("reveal [",))
    require(errors, "dro2026/functions/drone/fn_shareDroneIntel.sqf", (
        "ItemRadio", "distance2D", "INFOSHARE", "_sharedKnowledge", "_maxShares"
    ))
    require(errors, "dro2026/functions/drone/fn_fpvAttackController.sqf", (
        "ddtTasked", "DRO2026_fnc_isExternallyControlledUAV",
        "DRO2026_fnc_isFiberOpticDrone", "_targetVelocity", "_leadTime",
        "_stuckCount", "linearConversion [0, 500", "setDamage 1"
    ), ("systemChat", "allUnitsUAV", "initialized ="))
    require(errors, "dro2026/functions/core/fn_getJammingAtPosition.sqf", (
        "_platform", "DRO2026_fnc_isFiberOpticDrone", "exitWith {0}"
    ))
    require(errors, "dro2026/functions/support/fn_launchFPVStrike.sqf", (
        "ddtExclude", "DRO2026_ownedFPV", "DRO2026_fnc_fpvAttackController"
    ), ("DDT_fnc_",))
    require(errors, "dro2026/functions/drone/fn_droneWarfareDirector.sqf", (
        "DRO2026_DRONE_INTEL_CYCLE", "DRO2026_DRONE_INFOSHARE_CYCLE",
        "DRO2026_fnc_waitDDTReady", "DRO2026_fnc_collectDroneIntel"
    ))

    new_sources = list((ROOT / "dro2026/functions/drone").glob("*.sqf"))
    new_sources += [ROOT / "dro2026/functions/support/fn_launchFPVStrike.sqf"]
    stale = re.compile(r"dro2026[\\/]rc[0-9]+", re.IGNORECASE)
    for path in new_sources:
        source = path.read_text(encoding="utf-8", errors="replace")
        if stale.search(source):
            errors.append(f"{path.relative_to(ROOT)}: stale RC path")
        if "DrongosDroneTweaks\\Scripts" in source:
            errors.append(f"{path.relative_to(ROOT)}: copied/called DDT internal source")

    if errors:
        print("Drone Warfare adapter validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1
    print("Drone Warfare adapter validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
