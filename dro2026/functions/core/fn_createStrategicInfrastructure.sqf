if (!isServer) exitWith {};
[] call DRO2026_fnc_buildTheaterGraph;

private _spawnHQ = {
    params ["_nodeKey", "_side", "_type"];
    private _position = [_nodeKey] call DRO2026_fnc_getTheaterNode;
    private _hqClass = ["COMMAND", "Land_Cargo_HQ_V1_F"] call DRO2026_fnc_getRoleClass;
    private _hq = createVehicle [_hqClass, _position, [], 0, "NONE"];
    if (isNull _hq) exitWith {objNull};
    _hq setDir random 360;
    private _bunker = createVehicle ["Land_BagBunker_Tower_F", _position getPos [18, 55], [], 0, "CAN_COLLIDE"];
    private _tent = createVehicle ["Land_TentA_F", _position getPos [14, 215], [], 0, "CAN_COLLIDE"];
    private _officerClass = switch (_side) do {
        case west: {["OFFICER_WEST", "B_soldier_UAV_F"] call DRO2026_fnc_getRoleClass};
        case resistance: {"I_Soldier_F"};
        default {["OFFICER_EAST", "O_crew_F"] call DRO2026_fnc_getRoleClass};
    };
    private _group = createGroup [_side, true];
    private _officer = _group createUnit [_officerClass, _position getPos [3, random 360], [], 2, "NONE"];
    if (isNull _officer) exitWith {
        deleteVehicle _hq;
        deleteVehicle _bunker;
        deleteVehicle _tent;
        deleteGroup _group;
        objNull
    };
    _officer setRank "MAJOR";
    _officer setSkill 0.75;
    for "_index" from 1 to 2 do {
        private _guard = _group createUnit [_officerClass, _position getPos [8 + random 8, random 360], [], 3, "FORM"];
        if (!isNull _guard) then {_guard setSkill 0.56};
    };
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", true];
    _group setBehaviourStrong "AWARE";
    [_group, _position, 55] call BIS_fnc_taskDefend;
    private _extra = createHashMapFromArray [
        ["officer", _officer], ["group", _group], ["background", true]
    ];
    private _record = [_type, _position, _hq, [_hq, _bunker, _tent], _extra] call DRO2026_fnc_createSiteRecord;
    if ([_record, true, ["officer", "group"]] call DRO2026_fnc_validateSiteRecord) then {
        DRO2026_sites pushBack _record;
    };
    _hq
};

private _dangerousAATokens = [
    "spawner", "module", "logic", "_root", "site_", "samsite", "sam_site",
    "azncontrol", "unit_scanner", "pook_sam", "pook_azncontrol"
];
private _safeAAClass = {
    params ["_class", "_fallback"];
    private _candidate = if (isClass (configFile >> "CfgVehicles" >> _class)) then {_class} else {_fallback};
    private _name = toLowerANSI _candidate;
    if ((_dangerousAATokens findIf {(_name find _x) >= 0}) >= 0) then {_candidate = _fallback};
    if (!isClass (configFile >> "CfgVehicles" >> _candidate)) exitWith {""};
    _candidate
};

private _crewVehicle = {
    params ["_vehicle", "_side"];
    if (isNull _vehicle) exitWith {grpNull};
    if !((typeOf _vehicle) isKindOf "AllVehicles") exitWith {grpNull};
    private _group = _side createVehicleCrew _vehicle;
    if (!isNull _group) then {[_group, false] call DRO2026_fnc_registerManagedGroup};
    DRO2026_managedVehicles pushBackUnique _vehicle;
    _group
};

private _spawnLayeredAA = {
    params ["_siteType", "_side", "_longNode", "_shortNode", ["_withLongRange", true]];
    private _longPosition = [_longNode] call DRO2026_fnc_getTheaterNode;
    private _shortPosition = [_shortNode] call DRO2026_fnc_getTheaterNode;
    private _isWest = _side == west;
    private _longRole = if (_isWest) then {"LONG_RANGE_AA_WEST"} else {"LONG_RANGE_AA_EAST"};
    private _radarRole = if (_isWest) then {"RADAR_WEST"} else {"RADAR_EAST"};
    private _shortRole = if (_isWest) then {"SHORAD_WEST"} else {"SHORAD_EAST"};
    private _longFallback = if (_isWest) then {"B_SAM_System_03_F"} else {"S300_F_UCG"};
    private _radarFallback = if (_isWest) then {"B_Radar_System_01_F"} else {"Land_Radar_F"};
    private _shortFallback = if (_isWest) then {"B_APC_Tracked_01_AA_F"} else {"O_APC_Tracked_02_AA_F"};

    private _longRange = objNull;
    private _radar = objNull;
    if (_withLongRange) then {
        private _longClass = [[_longRole, _longFallback] call DRO2026_fnc_getRoleClass, _longFallback] call _safeAAClass;
        private _radarClass = [[_radarRole, _radarFallback] call DRO2026_fnc_getRoleClass, _radarFallback] call _safeAAClass;
        if (_longClass != "") then {_longRange = createVehicle [_longClass, _longPosition, [], 0, "NONE"]};
        if (_radarClass != "") then {_radar = createVehicle [_radarClass, _longPosition getPos [95, random 360], [], 0, "NONE"]};
    };
    private _shortClass = [[_shortRole, _shortFallback] call DRO2026_fnc_getRoleClass, _shortFallback] call _safeAAClass;
    private _shortRange = if (_shortClass != "") then {createVehicle [_shortClass, _shortPosition, [], 0, "NONE"]} else {objNull};

    private _objects = [];
    {
        if (!isNull _x) then {
            _objects pushBack _x;
            [_x, _side] call _crewVehicle;
            _x enableDynamicSimulation true;
        };
    } forEach [_longRange, _radar, _shortRange];
    if (count _objects > 0) then {
        private _primary = if (!isNull _longRange) then {_longRange} else {_shortRange};
        private _recordPosition = if (!isNull _longRange) then {_longPosition} else {_shortPosition};
        private _extra = createHashMapFromArray [
            ["radar", _radar], ["shorad", _shortRange],
            ["background", true], ["networked", _withLongRange]
        ];
        private _record = [_siteType, _recordPosition, _primary, _objects, _extra] call DRO2026_fnc_createSiteRecord;
        if ([_record, true] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _record};
        if (!isNull _longRange && {!isNull _radar}) then {
            [_longRange, _radar] spawn {
                params ["_launcher", "_radar"];
                waitUntil {
                    sleep 3;
                    isNull _launcher || {!alive _launcher} ||
                    {isNull _radar} || {!alive _radar} ||
                    {missionNamespace getVariable ["DRO2026_missionEnding", false]}
                };
                if (!isNull _launcher && {alive _launcher} && {isNull _radar || {!alive _radar}}) then {
                    _launcher setVehicleReceiveRemoteTargets false;
                    _launcher setVehicleReportRemoteTargets false;
                    _launcher setVehicleReportOwnPosition false;
                    if (!isNull gunner _launcher) then {
                        (gunner _launcher) disableAI "AUTOTARGET";
                        (gunner _launcher) disableAI "TARGET";
                    };
                };
            };
        };
    };
};

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_HQ"}) < 0) then {
    ["ENEMY_HQ", enemySide, "ENEMY_HQ"] call _spawnHQ;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_HQ"}) < 0) then {
    ["FRIENDLY_HQ", playersSide, "FRIENDLY_HQ"] call _spawnHQ;
};

private _hasEnemyObjectiveAA = (DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "AIR_DEFENCE_SITE"}) >= 0;
if (!_hasEnemyObjectiveAA && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ENEMY_LAYERED_AA"}) < 0}) then {
    ["ENEMY_LAYERED_AA", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD", false] call _spawnLayeredAA;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_LAYERED_AA"}) < 0) then {
    [
        "FRIENDLY_LAYERED_AA", playersSide,
        "FRIENDLY_AA_LONG", "FRIENDLY_AA_SHORAD",
        DRO2026_ENABLE_FRIENDLY_LONG_RANGE_AA
    ] call _spawnLayeredAA;
};

private _spawnDroneSite = {
    params ["_type", "_node", "_side"];
    private _position = [_node] call DRO2026_fnc_getTheaterNode;
    private _team = [_position, _side, _type] call DRO2026_fnc_createDroneTeam;
    private _operator = _team getOrDefault ["operator", objNull];
    if (isNull _operator) exitWith {};
    private _extra = createHashMapFromArray [
        ["operator", _operator], ["team", _team], ["virtual", false], ["background", true]
    ];
    private _record = [_type, _position, _operator, [_operator], _extra] call DRO2026_fnc_createSiteRecord;
    if ([_record, true, ["operator"]] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _record};
};

if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "STRATEGIC_DRONE_SITE"}) < 0) then {
    ["STRATEGIC_DRONE_SITE", "ENEMY_DRONE_REAR", enemySide] call _spawnDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FPV_TEAM"}) < 0) then {
    ["FPV_TEAM", "ENEMY_DRONE_FORWARD", enemySide] call _spawnDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE"}) < 0) then {
    ["FRIENDLY_FPV_SITE", "FRIENDLY_DRONE_FORWARD", playersSide] call _spawnDroneSite;
};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE"}) < 0) then {
    ["FRIENDLY_DRONE_SITE", "FRIENDLY_DRONE_REAR", playersSide] call _spawnDroneSite;
};

if (DRO2026_ENABLE_BACKGROUND_ARTILLERY && {(DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "ARTILLERY_SITE"}) < 0}) then {
    private _position = ["ENEMY_ARTILLERY"] call DRO2026_fnc_getTheaterNode;
    private _role = if (enemySide == west) then {"ARTILLERY_WEST"} else {"ARTILLERY_EAST"};
    private _fallback = if (enemySide == west) then {"B_MBT_01_arty_F"} else {"O_MBT_02_arty_F"};
    private _class = [_role, _fallback] call DRO2026_fnc_getRoleClass;
    private _artillery = createVehicle [_class, _position, [], 0, "NONE"];
    if (!isNull _artillery && {count getArtilleryAmmo [_artillery] > 0}) then {
        [_artillery, enemySide] call _crewVehicle;
        private _positions = [_position];
        for "_index" from 1 to 2 do {
            private _alternate = [_position, 350, 900, 8, 0, 0.3, 0, [], [_position, _position]] call BIS_fnc_findSafePos;
            if !(_alternate isEqualTo [0,0,0]) then {_positions pushBack _alternate};
        };
        private _extra = createHashMapFromArray [["positions", _positions], ["background", true]];
        private _record = ["ARTILLERY_SITE", _position, _artillery, [_artillery], _extra] call DRO2026_fnc_createSiteRecord;
        if ([_record, true] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _record};
        [_artillery, _positions, "", ""] spawn DRO2026_fnc_artilleryLoop;
    } else {
        if (!isNull _artillery) then {deleteVehicle _artillery};
    };
};