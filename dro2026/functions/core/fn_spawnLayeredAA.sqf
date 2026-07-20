params ["_siteType","_side","_longNode","_shortNode",["_withLongRange",true]];
if (!isServer) exitWith {[]};
private _longPosition = [_longNode] call DRO2026_fnc_getTheaterNode;
private _shortPosition = [_shortNode] call DRO2026_fnc_getTheaterNode;
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _longFallback = switch (_side) do {
    case west: {"B_SAM_System_03_F"};
    case resistance: {"I_E_SAM_System_03_F"};
    default {"S300_F_UCG"};
};
private _radarFallback = switch (_side) do {
    case west: {"B_Radar_System_01_F"};
    case resistance: {"I_E_Radar_System_01_F"};
    default {"S300_RS_F_UCG"};
};
private _shortFallback = switch (_side) do {
    case west: {"B_APC_Tracked_01_AA_F"};
    case resistance: {"I_LT_01_AA_F"};
    default {"O_APC_Tracked_02_AA_F"};
};
private _blocked = ["spawner","module","logic","site_","samsite","sam_site","azncontrol","unit_scanner","pook_sam","pook_azncontrol"];
private _safeClass = {
    params ["_role","_fallback",["_allowNeutral",false]];
    private _class = [_role,_fallback,_side,_allowNeutral] call DRO2026_fnc_getSideRoleClass;
    if (_class == "") exitWith {""};
    private _lower = toLowerANSI _class;
    if ((_blocked findIf {(_lower find _x) >= 0}) >= 0) exitWith {""};
    if !([_class,"AIR_DEFENCE_POOL"] call DRO2026_fnc_isAssetAllowedForRole) exitWith {""};
    _class
};
private _safePosition = {
    params ["_anchor","_distance","_bearing","_class"];
    private _candidate = _anchor getPos [_distance,_bearing];
    private _safe = [_candidate,0,100,12,0,0.28,0,[],[_candidate,_candidate]] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
    if (count _candidate == 2) then {_candidate pushBack 0};
    _candidate set [2,0];
    _candidate
};
private _deleteMaterialized = {
    params ["_objects"];
    private _groups = [];
    {
        if (!isNull _x) then {
            {if (!isNull _x) then {_groups pushBackUnique (group _x)}} forEach crew _x;
            deleteVehicleCrew _x;
            deleteVehicle _x;
        };
    } forEach _objects;
    {if (!isNull _x) then {deleteGroup _x}} forEach _groups;
};

private _objects = [];
private _launchers = [];
private _radar = objNull;
private _shortRange = objNull;
if (_withLongRange) then {
    private _longClass = [format ["LONG_RANGE_AA_%1",_suffix],_longFallback] call _safeClass;
    private _radarClass = [format ["RADAR_%1",_suffix],_radarFallback,true] call _safeClass;
    if (_longClass != "") then {
        private _launcherCount = if (_side == east && {_longClass == "S300_F_UCG"}) then {2} else {1};
        private _baseBearing = [360,format ["AA_%1_LAUNCHER_BEARING",_siteType],0] call DRO2026_fnc_seededRandom;
        for "_index" from 0 to (_launcherCount - 1) do {
            private _bearing = _baseBearing + (_index * (360 / _launcherCount));
            private _distance = 70 + ([100,format ["AA_%1_LAUNCHER_DISTANCE_%2",_siteType,_index],0] call DRO2026_fnc_seededRandom);
            private _position = [_longPosition,_distance,_bearing,_longClass] call _safePosition;
            private _launcher = createVehicle [_longClass,_position,[],0,"NONE"];
            if (!isNull _launcher) then {_launchers pushBack _launcher};
        };
    };
    if (_radarClass != "") then {
        private _radarBearing = [360,format ["AA_%1_RADAR_BEARING",_siteType],0] call DRO2026_fnc_seededRandom;
        private _radarDistance = 120 + ([100,format ["AA_%1_RADAR_DISTANCE",_siteType],0] call DRO2026_fnc_seededRandom);
        private _radarPosition = [_longPosition,_radarDistance,_radarBearing,_radarClass] call _safePosition;
        _radar = createVehicle [_radarClass,_radarPosition,[],0,"NONE"];
    };
};
private _shortClass = [format ["SHORAD_%1",_suffix],_shortFallback] call _safeClass;
if (_shortClass != "") then {
    private _shortPositionSafe = [_shortPosition,30,[360,format ["AA_%1_SHORAD",_siteType],0] call DRO2026_fnc_seededRandom,_shortClass] call _safePosition;
    _shortRange = createVehicle [_shortClass,_shortPositionSafe,[],0,"NONE"];
};

{
    if (!isNull _x && {[_x,_side] call DRO2026_fnc_crewManagedVehicle}) then {
        _objects pushBack _x;
        _x enableDynamicSimulation true;
    };
} forEach (_launchers + [_radar,_shortRange]);
if (count _objects == 0) exitWith {[]};

private _primary = if (count (_launchers select {_x in _objects}) > 0) then {
    (_launchers select {_x in _objects}) select 0
} else {
    if (_shortRange in _objects) then {_shortRange} else {_objects select 0}
};
private _recordPosition = if (_primary in _launchers) then {_longPosition} else {_shortPosition};
private _template = [_siteType,_recordPosition,_side,[360,format ["AA_%1_TEMPLATE",_siteType],0] call DRO2026_fnc_seededRandom] call DRO2026_fnc_createSiteComponents;
_objects append (_template getOrDefault ["objects",[]]);
private _components = _template getOrDefault ["components",createHashMap];
_components set ["launchers",_launchers select {_x in _objects}];
private _antennaComponents = +(_components getOrDefault ["antennas",[]]);
if (!isNull _radar && {_radar in _objects}) then {_antennaComponents pushBackUnique _radar};
_components set ["antennas",_antennaComponents];
private _crew = [];
{{_crew pushBackUnique _x} forEach crew _x} forEach _objects;
_components set ["crew",_crew];

private _extra = createHashMapFromArray [
    ["radar",if (_radar in _objects) then {_radar} else {objNull}],
    ["shorad",if (_shortRange in _objects) then {_shortRange} else {objNull}],
    ["side",_side],["components",_components],
    ["background",_siteType != "AIR_DEFENCE_SITE"],["networked",_withLongRange],
    ["formationTemplate","S300_BATTERY"],["operationSeed",missionNamespace getVariable ["DRO2026_operationSeed",1]]
];
private _record = [_siteType,_recordPosition,_primary,_objects,_extra] call DRO2026_fnc_createSiteRecord;
if !([_record,true] call DRO2026_fnc_validateSiteRecord) exitWith {
    [_objects] call _deleteMaterialized;
    []
};
DRO2026_sites pushBack _record;
["AIR_DEFENCE","FORMATION_MATERIALIZED",createHashMapFromArray [
    ["siteType",_siteType],["launchers",count (_components getOrDefault ["launchers",[]])],
    ["radar",!isNull _radar],["shorad",!isNull _shortRange],["position",_recordPosition]
],_siteType] call DRO2026_fnc_logStructured;
_objects
