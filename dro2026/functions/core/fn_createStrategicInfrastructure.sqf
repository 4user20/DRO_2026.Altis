if (!isServer) exitWith {};
[] call DRO2026_fnc_buildTheaterGraph;

private _spawnHQ = {
    params ["_nodeKey", "_side", "_type"];
    private _pos = [_nodeKey] call DRO2026_fnc_getTheaterNode;
    private _hqClass = ["COMMAND", "Land_Cargo_HQ_V1_F"] call DRO2026_fnc_getRoleClass;
    private _hq = createVehicle [_hqClass, _pos, [], 0, "NONE"];
    if (isNull _hq) exitWith {objNull};
    _hq setDir random 360;
    private _bunker = createVehicle ["Land_BagBunker_Tower_F", _pos getPos [18, 55], [], 0, "CAN_COLLIDE"];
    private _tent = createVehicle ["Land_TentA_F", _pos getPos [14, 215], [], 0, "CAN_COLLIDE"];
    private _officerClass = switch (_side) do {
        case west: {["OFFICER_WEST", "B_soldier_UAV_F"] call DRO2026_fnc_getRoleClass};
        default {["OFFICER_EAST", "O_crew_F"] call DRO2026_fnc_getRoleClass};
    };
    private _group = createGroup [_side, true];
    private _officer = _group createUnit [_officerClass, _pos getPos [3, random 360], [], 2, "NONE"];
    _officer setRank "MAJOR";
    _officer setSkill 0.75;
    private _guards = [];
    for "_i" from 1 to 4 do {
        private _u = _group createUnit [_officerClass, _pos getPos [8 + random 8, random 360], [], 3, "FORM"];
        _u setSkill 0.56;
        _guards pushBack _u;
    };
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setBehaviourStrong "AWARE";
    [_group, _pos, 65] call BIS_fnc_taskDefend;
    DRO2026_sites pushBack createHashMapFromArray [["type", _type], ["position", _pos], ["object", _hq], ["objects", [_hq, _bunker, _tent]], ["officer", _officer], ["group", _group]];
    _hq
};

private _spawnLayeredAA = {
    params ["_siteType", "_side", "_longNode", "_shortNode"];
    private _longPos = [_longNode] call DRO2026_fnc_getTheaterNode;
    private _shortPos = [_shortNode] call DRO2026_fnc_getTheaterNode;
    private _longRole = if (_side == west) then {"LONG_RANGE_AA_WEST"} else {"LONG_RANGE_AA_EAST"};
    private _radarRole = if (_side == west) then {"RADAR_WEST"} else {"RADAR_EAST"};
    private _shortRole = if (_side == west) then {"SHORAD_WEST"} else {"SHORAD_EAST"};
    private _longFallback = if (_side == west) then {"B_SAM_System_03_F"} else {"S300_F_UCG"};
    private _radarFallback = if (_side == west) then {"B_Radar_System_01_F"} else {"Land_Radar_F"};
    private _shortFallback = if (_side == west) then {"B_APC_Tracked_01_AA_F"} else {"O_APC_Tracked_02_AA_F"};

    private _lr = createVehicle [[_longRole, _longFallback] call DRO2026_fnc_getRoleClass, _longPos, [], 0, "NONE"];
    private _radar = createVehicle [[_radarRole, _radarFallback] call DRO2026_fnc_getRoleClass, _longPos getPos [80, random 360], [], 0, "NONE"];
    private _short = createVehicle [[_shortRole, _shortFallback] call DRO2026_fnc_getRoleClass, _shortPos, [], 0, "NONE"];
    private _objects = [];
    {
        if (!isNull _x) then {
            _objects pushBack _x;
            if ((typeOf _x) isKindOf "AllVehicles") then {
                private _grp = _side createVehicleCrew _x;
                if (!isNull _grp) then {[_grp, false] call DRO2026_fnc_registerManagedGroup};
                DRO2026_managedVehicles pushBackUnique _x;
            };
        };
    } forEach [_lr, _radar, _short];
    if (count _objects > 0) then {
        DRO2026_sites pushBack createHashMapFromArray [["type", _siteType], ["position", _longPos], ["object", _lr], ["radar", _radar], ["shorad", _short], ["objects", _objects], ["background", true]];
    };
};

private _hasEnemyHQ = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_HQ"}) >= 0;
if (!_hasEnemyHQ) then {["ENEMY_HQ", enemySide, "ENEMY_HQ"] call _spawnHQ;};
private _hasFriendlyHQ = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_HQ"}) >= 0;
if (!_hasFriendlyHQ) then {["FRIENDLY_HQ", playersSide, "FRIENDLY_HQ"] call _spawnHQ;};

private _hasEnemyAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_LAYERED_AA"}) >= 0;
if (!_hasEnemyAA) then {["ENEMY_LAYERED_AA", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD"] call _spawnLayeredAA;};
private _hasFriendlyAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_LAYERED_AA"}) >= 0;
if (!_hasFriendlyAA) then {["FRIENDLY_LAYERED_AA", playersSide, "FRIENDLY_AA_LONG", "FRIENDLY_AA_SHORAD"] call _spawnLayeredAA;};

private _hasEnemyStrategicDrone = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) in ["STRATEGIC_DRONE_SITE", "DRONE_SITE"]}) >= 0;
if (!_hasEnemyStrategicDrone) then {
    private _pos = ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode;
    private _team = [_pos, enemySide, "STRATEGIC_DRONE_SITE"] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    private _launcher = createVehicle [[if (enemySide == west) then {"LONG_RANGE_LAUNCHER_WEST"} else {"LONG_RANGE_LAUNCHER_EAST"}, "FRTZ_FP2_Launcher"] call DRO2026_fnc_getRoleClass, _pos getPos [10, 30], [], 0, "NONE"];
    DRO2026_sites pushBack createHashMapFromArray [["type", "STRATEGIC_DRONE_SITE"], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["launcher", _launcher], ["virtual", false]];
};
private _hasEnemyForwardDrone = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FPV_TEAM"}) >= 0;
if (!_hasEnemyForwardDrone) then {
    private _pos = ["ENEMY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode;
    private _team = [_pos, enemySide, "FPV_TEAM"] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    DRO2026_sites pushBack createHashMapFromArray [["type", "FPV_TEAM"], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["virtual", false]];
};

private _hasFriendlyFPV = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE"}) >= 0;
if (!_hasFriendlyFPV) then {
    private _pos = ["FRIENDLY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode;
    private _team = [_pos, playersSide, "FRIENDLY_FPV_SITE"] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    DRO2026_sites pushBack createHashMapFromArray [["type", "FRIENDLY_FPV_SITE"], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["virtual", false]];
};
private _hasFriendlyStrategic = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE"}) >= 0;
if (!_hasFriendlyStrategic) then {
    private _pos = ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode;
    private _team = [_pos, playersSide, "FRIENDLY_DRONE_SITE"] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    private _launcher = createVehicle [["LONG_RANGE_LAUNCHER_WEST", "FRTZ_FP2_Launcher"] call DRO2026_fnc_getRoleClass, _pos getPos [10, 30], [], 0, "NONE"];
    DRO2026_sites pushBack createHashMapFromArray [["type", "FRIENDLY_DRONE_SITE"], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["launcher", _launcher], ["virtual", false]];
};

private _hasArty = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ARTILLERY_SITE"}) >= 0;
if (!_hasArty) then {
    private _pos = ["ENEMY_ARTILLERY"] call DRO2026_fnc_getTheaterNode;
    private _role = if (enemySide == west) then {"ARTILLERY_WEST"} else {"ARTILLERY_EAST"};
    private _fallback = if (enemySide == west) then {"B_MBT_01_arty_F"} else {"O_MBT_02_arty_F"};
    private _class = [_role, _fallback] call DRO2026_fnc_getRoleClass;
    private _arty = createVehicle [_class, _pos, [], 0, "NONE"];
    if (!isNull _arty && {count getArtilleryAmmo [_arty] > 0}) then {
        private _grp = enemySide createVehicleCrew _arty;
        if (!isNull _grp) then {[_grp, false] call DRO2026_fnc_registerManagedGroup};
        DRO2026_managedVehicles pushBackUnique _arty;
        private _positions = [_pos];
        for "_i" from 1 to 2 do {
            private _p = [_pos, 350, 900, 8, 0, 0.3, 0, [], [_pos, _pos]] call BIS_fnc_findSafePos;
            if !(_p isEqualTo [0,0,0]) then {_positions pushBack _p};
        };
        DRO2026_sites pushBack createHashMapFromArray [["type", "ARTILLERY_SITE"], ["position", _pos], ["object", _arty], ["positions", _positions], ["background", true]];
        [_arty, _positions, "", ""] spawn DRO2026_fnc_artilleryLoop;
    } else {
        if (!isNull _arty) then {deleteVehicle _arty};
    };
};
