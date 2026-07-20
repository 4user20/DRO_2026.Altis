if (!isServer) exitWith {};
[] call DRO2026_fnc_buildTheaterGraph;

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_HQ"}) < 0) then {
    ["ENEMY_HQ", enemySide, "ENEMY_HQ"] call DRO2026_fnc_spawnStrategicHQ;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_HQ"}) < 0) then {
    ["FRIENDLY_HQ", playersSide, "FRIENDLY_HQ"] call DRO2026_fnc_spawnStrategicHQ;
};

private _hasEnemyObjectiveAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "AIR_DEFENCE_SITE"}) >= 0;
if (!_hasEnemyObjectiveAA && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_LAYERED_AA"}) < 0}) then {
    ["ENEMY_LAYERED_AA", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD", false] call DRO2026_fnc_spawnLayeredAA;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_LAYERED_AA"}) < 0) then {
    [
        "FRIENDLY_LAYERED_AA", playersSide,
        "FRIENDLY_AA_LONG", "FRIENDLY_AA_SHORAD",
        DRO2026_ENABLE_FRIENDLY_LONG_RANGE_AA
    ] call DRO2026_fnc_spawnLayeredAA;
};

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "STRATEGIC_DRONE_SITE"}) < 0) then {
    ["STRATEGIC_DRONE_SITE", "ENEMY_DRONE_REAR", enemySide] call DRO2026_fnc_spawnStrategicDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FPV_TEAM"}) < 0) then {
    ["FPV_TEAM", "ENEMY_DRONE_FORWARD", enemySide] call DRO2026_fnc_spawnStrategicDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE"}) < 0) then {
    ["FRIENDLY_FPV_SITE", "FRIENDLY_DRONE_FORWARD", playersSide] call DRO2026_fnc_spawnStrategicDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE"}) < 0) then {
    ["FRIENDLY_DRONE_SITE", "FRIENDLY_DRONE_REAR", playersSide] call DRO2026_fnc_spawnStrategicDroneSite;
};

if (DRO2026_ENABLE_BACKGROUND_ARTILLERY && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ARTILLERY_SITE"}) < 0}) then {
    [enemySide] call DRO2026_fnc_spawnBackgroundArtillery;
};
