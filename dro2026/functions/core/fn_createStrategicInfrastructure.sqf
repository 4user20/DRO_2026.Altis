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
    private _officerClass = if (_side == west) then {["OFFICER_WEST", "B_soldier_UAV_F"] call DRO2026_fnc_getRoleClass} else {["OFFICER_EAST", "O_crew_F"] call DRO2026_fnc_getRoleClass};
    private _group = createGroup [_side, true];
    private _officer = _group createUnit [_officerClass, _pos getPos [3, random 360], [], 2, "NONE"];
    _officer setRank "MAJOR";
    _officer setSkill 0.75;
    for "_i" from 1 to 2 do {
        private _u = _group createUnit [_officerClass, _pos getPos [8 + random 8, random 360], [], 3, "FORM"];
        _u setSkill 0.56;
    };
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", true];
    _group setBehaviourStrong "AWARE";
    [_group, _pos, 55] call BIS_fnc_taskDefend;
    private _record = createHashMapFromArray [["type", _type], ["position", _pos], ["object", _hq], ["objects", [_hq, _bunker, _tent]], ["officer", _officer], ["group", _group], ["background", true]];
    DRO2026_sites pushBack _record;
    _hq
};

private _safeAAClass = {
    params ["_class", "_fallback"];
    private _candidate = if (isClass (configFile >> "CfgVehicles" >> _class)) then {_class} else {_fallback};
    private _n = toLowerANSI _candidate;
    if ((_n find "pook_") == 0 || {(_n find "spawner") >= 0} || {(_n find "_root") >= 0}) then {_candidate = _fallback};
    if (!isClass (configFile >> "CfgVehicles" >> _candidate)) exitWith {""};
    _candidate
};

private _crewVehicle = {
    params ["_vehicle", "_side"];
    if (isNull _vehicle) exitWith {grpNull};
    private _grp = _side createVehicleCrew _vehicle;
    if (!isNull _grp) then {[_grp, false] call DRO2026_fnc_registerManagedGroup};
    DRO2026_managedVehicles pushBackUnique _vehicle;
    _grp
};

private _spawnLayeredAA = {
    params ["_siteType", "_side", "_longNode", "_shortNode", ["_withLongRange", true]];
    private _longPos = [_longNode] call DRO2026_fnc_getTheaterNode;
    private _shortPos = [_shortNode] call DRO2026_fnc_getTheaterNode;
    private _longRole = if (_side == west) then {"LONG_RANGE_AA_WEST"} else {"LONG_RANGE_AA_EAST"};
    private _radarRole = if (_side == west) then {"RADAR_WEST"} else {"RADAR_EAST"};
    private _shortRole = if (_side == west) then {"SHORAD_WEST"} else {"SHORAD_EAST"};
    private _longFallback = if (_side == west) then {"B_SAM_System_03_F"} else {"S300_F_UCG"};
    private _radarFallback = if (_side == west) then {"B_Radar_System_01_F"} else {"Land_Radar_F"};
    private _shortFallback = if (_side == west) then {"B_APC_Tracked_01_AA_F"} else {"O_APC_Tracked_02_AA_F"};

    private _lr = objNull;
    private _radar = objNull;
    if (_withLongRange) then {
        private _lrClass = [[_longRole, _longFallback] call DRO2026_fnc_getRoleClass, _longFallback] call _safeAAClass;
        private _radarClass = [[_radarRole, _radarFallback] call DRO2026_fnc_getRoleClass, _radarFallback] call _safeAAClass;
        if (_lrClass != "") then {_lr = createVehicle [_lrClass, _longPos, [], 0, "NONE"]};
        if (_radarClass != "") then {_radar = createVehicle [_radarClass, _longPos getPos [95, random 360], [], 0, "NONE"]};
    };
    private _shortClass = [[_shortRole, _shortFallback] call DRO2026_fnc_getRoleClass, _shortFallback] call _safeAAClass;
    private _short = if (_shortClass != "") then {createVehicle [_shortClass, _shortPos, [], 0, "NONE"]} else {objNull};

    private _objects = [];
    {
        if (!isNull _x) then {
            _objects pushBack _x;
            [_x, _side] call _crewVehicle;
            _x enableDynamicSimulation true;
        };
    } forEach [_lr, _radar, _short];
    if (count _objects > 0) then {
        private _primary = if (!isNull _lr) then {_lr} else {_short};
        private _record = createHashMapFromArray [["type", _siteType], ["position", if (!isNull _lr) then {_longPos} else {_shortPos}], ["object", _primary], ["radar", _radar], ["shorad", _short], ["objects", _objects], ["background", true], ["networked", _withLongRange]];
        DRO2026_sites pushBack _record;
        // If the radar is destroyed, explicitly suppress the long-range launcher even when a mod does not model datalink loss.
        if (!isNull _lr && {!isNull _radar}) then {
            [_lr, _radar] spawn {
                params ["_launcher", "_radar"];
                waitUntil {sleep 3; isNull _launcher || {!alive _launcher} || {isNull _radar} || {!alive _radar}};
                if (!isNull _launcher && {alive _launcher}) then {
                    _launcher setVehicleReceiveRemoteTargets false;
                    _launcher setVehicleReportRemoteTargets false;
                    _launcher setVehicleReportOwnPosition false;
                    if (!isNull gunner _launcher) then {(gunner _launcher) disableAI "AUTOTARGET"; (gunner _launcher) disableAI "TARGET"};
                };
            };
        };
    };
};

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_HQ"}) < 0) then {["ENEMY_HQ", enemySide, "ENEMY_HQ"] call _spawnHQ};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_HQ"}) < 0) then {["FRIENDLY_HQ", playersSide, "FRIENDLY_HQ"] call _spawnHQ};

// The AIR_DEFENCE objective already owns a complete LR radar/launcher/SHORAD network.
// Never stack a second background network on top of it. Outside that objective, keep only one light SHORAD per side.
private _hasEnemyObjectiveAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "AIR_DEFENCE_SITE"}) >= 0;
if (!_hasEnemyObjectiveAA && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_LAYERED_AA"}) < 0}) then {
    ["ENEMY_LAYERED_AA", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD", false] call _spawnLayeredAA;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_LAYERED_AA"}) < 0) then {
    ["FRIENDLY_LAYERED_AA", playersSide, "FRIENDLY_AA_LONG", "FRIENDLY_AA_SHORAD", false] call _spawnLayeredAA;
};

private _spawnDroneSite = {
    params ["_type", "_node", "_side"];
    private _pos = [_node] call DRO2026_fnc_getTheaterNode;
    private _team = [_pos, _side, _type] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    private _record = createHashMapFromArray [["type", _type], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["virtual", false], ["background", true]];
    DRO2026_sites pushBack _record;
};

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "STRATEGIC_DRONE_SITE"}) < 0) then {["STRATEGIC_DRONE_SITE", "ENEMY_DRONE_REAR", enemySide] call _spawnDroneSite};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FPV_TEAM"}) < 0) then {["FPV_TEAM", "ENEMY_DRONE_FORWARD", enemySide] call _spawnDroneSite};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE"}) < 0) then {["FRIENDLY_FPV_SITE", "FRIENDLY_DRONE_FORWARD", playersSide] call _spawnDroneSite};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE"}) < 0) then {["FRIENDLY_DRONE_SITE", "FRIENDLY_DRONE_REAR", playersSide] call _spawnDroneSite};

// Background artillery is optional. The objective version owns its own loop and will not duplicate this site.
if (DRO2026_ENABLE_BACKGROUND_ARTILLERY && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ARTILLERY_SITE"}) < 0}) then {
    private _pos = ["ENEMY_ARTILLERY"] call DRO2026_fnc_getTheaterNode;
    private _role = if (enemySide == west) then {"ARTILLERY_WEST"} else {"ARTILLERY_EAST"};
    private _fallback = if (enemySide == west) then {"B_MBT_01_arty_F"} else {"O_MBT_02_arty_F"};
    private _class = [_role, _fallback] call DRO2026_fnc_getRoleClass;
    private _arty = createVehicle [_class, _pos, [], 0, "NONE"];
    if (!isNull _arty && {count getArtilleryAmmo [_arty] > 0}) then {
        [_arty, enemySide] call _crewVehicle;
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
