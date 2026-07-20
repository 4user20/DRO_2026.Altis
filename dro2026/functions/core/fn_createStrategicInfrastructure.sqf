if (!isServer) exitWith {};
[] call DRO2026_fnc_buildTheaterGraph;

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_HQ"}) < 0) then {
    ["ENEMY_HQ", enemySide, "ENEMY_HQ"] call DRO2026_fnc_spawnStrategicHQ;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_HQ"}) < 0) then {
    ["FRIENDLY_HQ", playersSide, "FRIENDLY_HQ"] call DRO2026_fnc_spawnStrategicHQ;
};

// One physical long-range battery per side at most. Objective materializers remain authoritative when present.
private _hasEnemyObjectiveAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "AIR_DEFENCE_SITE"}) >= 0;
if (!_hasEnemyObjectiveAA && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_LAYERED_AA"}) < 0}) then {
    ["ENEMY_LAYERED_AA", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD", true] call DRO2026_fnc_spawnLayeredAA;
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

// Physical operational targets: every stock/capability has objects that can be found and destroyed.
["NODE_LOGISTICS_01","LOGISTICS_HUB",enemySide,"",35] call DRO2026_fnc_spawnOperationalNodeSite;
["NODE_FRIENDLY_LOGISTICS","FRIENDLY_LOGISTICS",playersSide,"",215] call DRO2026_fnc_spawnOperationalNodeSite;
private _ballisticRole = format ["BALLISTIC_MISSILE_%1",[enemySide] call DRO2026_fnc_getSideSuffix];
["NODE_BALLISTIC_01","BALLISTIC_MISSILE_SITE",enemySide,_ballisticRole,70] call DRO2026_fnc_spawnOperationalNodeSite;
["NODE_FARP_01","FARP",enemySide,"",120] call DRO2026_fnc_spawnOperationalNodeSite;
["NODE_FRIENDLY_FARP","FRIENDLY_FARP",playersSide,"",300] call DRO2026_fnc_spawnOperationalNodeSite;

// Balanced anti-drone gun groups: two enemy groups for high-value nodes, one friendly HQ group.
["NODE_LOGISTICS_01",enemySide,30] call DRO2026_fnc_spawnPointDefenceGroup;
["NODE_ENEMY_HQ",enemySide,210] call DRO2026_fnc_spawnPointDefenceGroup;
["NODE_FRIENDLY_HQ",playersSide,150] call DRO2026_fnc_spawnPointDefenceGroup;

if (DRO2026_ENABLE_BACKGROUND_ARTILLERY && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ARTILLERY_SITE"}) < 0}) then {
    [enemySide] call DRO2026_fnc_spawnBackgroundArtillery;
};

[] call DRO2026_fnc_syncNetworkState;