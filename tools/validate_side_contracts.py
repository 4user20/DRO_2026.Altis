from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"

REQUIRED = {
    "dro2026/CfgFunctions.hpp": [
        "class getSideSuffix {};",
        "class getSideNumber {};",
        "class getSideRoleClass {};",
        "class crewManagedVehicle {};",
        "class spawnStrategicHQ {};",
        "class spawnLayeredAA {};",
        "class spawnStrategicDroneSite {};",
        "class spawnBackgroundArtillery {};",
    ],
    "dro2026/functions/core/fn_registerAssets.sqf": [
        '"SHORAD_GUER"',
        '"LONG_RANGE_AA_GUER"',
        '"RADAR_GUER"',
        '"ARTILLERY_GUER"',
        '"EW_GUER"',
        '"LOGISTICS_GUER"',
        '"CONVOY_CARGO_GUER"',
        '"CONVOY_ESCORT_GUER"',
        '"OFFICER_GUER"',
    ],
    "dro2026/functions/core/fn_refreshFactionAssets.sqf": [
        "private _enemySuffix = [enemySide] call DRO2026_fnc_getSideSuffix;",
        'format ["ARTILLERY_%1", _enemySuffix]',
        'format ["LOGISTICS_%1", _enemySuffix]',
    ],
    "dro2026/functions/core/fn_createStrategicInfrastructure.sqf": [
        "DRO2026_fnc_spawnStrategicHQ",
        "DRO2026_fnc_spawnLayeredAA",
        "DRO2026_fnc_spawnStrategicDroneSite",
        "DRO2026_fnc_spawnBackgroundArtillery",
    ],
    "dro2026/functions/objectives/fn_objectiveAirDefence.sqf": [
        '["AIR_DEFENCE_SITE", enemySide',
        "DRO2026_fnc_spawnLayeredAA",
    ],
    "dro2026/functions/objectives/fn_objectiveArtilleryHunt.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["ARTILLERY_%1", _suffix]',
        '"I_Mortar_01_F"',
    ],
    "dro2026/functions/objectives/fn_objectiveEWHunt.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["EW_%1", _suffix]',
        '"I_Truck_02_box_F"',
    ],
    "dro2026/functions/objectives/fn_objectiveDroneSite.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["EW_%1", _suffix]',
    ],
    "dro2026/functions/objectives/fn_objectiveUAVTeam.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["FPV_%1", _suffix]',
        '"I_UAV_01_F"',
    ],
    "dro2026/functions/objectives/fn_objectiveCutRear.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["LOGISTICS_%1", _suffix]',
        '"I_Truck_02_fuel_F"',
        '"I_Truck_02_ammo_F"',
    ],
    "dro2026/functions/objectives/fn_objectiveLogisticsRun.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["CONVOY_CARGO_%1", _suffix]',
        '"I_Truck_02_ammo_F"',
    ],
    "dro2026/functions/objectives/fn_objectiveLogisticsHub.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["LOGISTICS_%1", _suffix]',
    ],
    "dro2026/functions/objectives/fn_objectiveISRRecon.sqf": [
        "DRO2026_fnc_getSideSuffix",
        'format ["LOGISTICS_%1", _suffix]',
        "DRO2026_fnc_getSideNumber",
    ],
}

TWO_WAY = re.compile(r"\b(enemySide|playersSide)\s*==\s*west\b", re.IGNORECASE)
ROLE_TWO_WAY = re.compile(
    r'if\s*\(\s*(?:enemySide|playersSide)\s*==\s*west\s*\)\s*then\s*'
    r'\{\s*"[^"]*_WEST"\s*\}\s*else\s*\{\s*"[^"]*_EAST"\s*\}',
    re.IGNORECASE | re.DOTALL,
)


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="replace")


def main() -> int:
    errors: list[str] = []

    for relative, snippets in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative}: missing")
            continue
        source = read(relative)
        for snippet in snippets:
            if snippet not in source:
                errors.append(f"{relative}: missing contract {snippet!r}")

    for path in DRO.rglob("*.sqf"):
        source = path.read_text(encoding="utf-8", errors="replace")
        relative = path.relative_to(ROOT).as_posix()
        for match in ROLE_TWO_WAY.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            errors.append(f"{relative}:{line}: two-way WEST/EAST role selection")
        for match in TWO_WAY.finditer(source):
            start = max(0, match.start() - 180)
            end = min(len(source), match.end() + 380)
            window = source[start:end].lower()
            if "resistance" not in window and "_guer" not in window:
                line = source.count("\n", 0, match.start()) + 1
                errors.append(
                    f"{relative}:{line}: WEST branch has no nearby RESISTANCE/GUER handling"
                )

    if errors:
        print("Side/faction contract validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Side/faction contract validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
