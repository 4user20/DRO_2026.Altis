params ["_siteType","_side","_longNode","_shortNode",["_withLongRange",true]];
if (!isServer) exitWith {[]};
if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized",false]) then {[] call DRO2026_fnc_initStrategicOperationData};
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
    private _safe = [_candidate,0,35,12,0,0.28,0,[],[_candidate,_candidate]] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
    if (_class != "") then {
        private _empty = _candidate findEmptyPosition [0,15,_class];
        if (count _empty >= 2) then {_candidate = _empty};
    };
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
            if (local _x) then {deleteVehicleCrew _x; deleteVehicle _x};
        };
    } forEach _objects;
    {if (!isNull _x) then {deleteGroup _x}} forEach _groups;
};

private _objects = [];
private _launchers = [];
private _radar = objNull;
private _shortRange = objNull;
private _launcherPairDistance = -1;
private _radarMinDistance = -1;
if (_withLongRange) then {
    private _longClass = [format ["LONG_RANGE_AA_%1",_suffix],_longFallback] call _safeClass;
    private _radarClass = [format ["RADAR_%1",_suffix],_radarFallback,true] call _safeClass;
    if (_longClass != "") then {
        private _launcherCount = if (_side == east && {_longClass == "S300_F_UCG"}) then {2} else {1};
        private _baseBearing = [360,format ["AA_%1_LAUNCHER_BEARING",_siteType],0] call DRO2026_fnc_seededRandom;
        private _template = DRO2026_formationTemplates getOrDefault ["S300_BATTERY",createHashMap];
        private _spacingRange = _template getOrDefault ["launcherSpacing",[70,220]];
        private _spacingMin = (_spacingRange param [0,70,[0]]) max 70;
        private _spacingMax = (_spacingRange param [1,220,[0]]) max _spacingMin;
        private _bufferedMin = (_spacingMin + 30) min _spacingMax;
        private _bufferedMax = (_spacingMax - 30) max _bufferedMin;
        private _pairSpacing = _bufferedMin + ([_bufferedMax - _bufferedMin,format ["AA_%1_PAIR_SPACING",_siteType],0] call DRO2026_fnc_seededRandom);
        for "_index" from 0 to (_launcherCount - 1) do {
            private _bearing = _baseBearing + (_index * (360 / (_launcherCount max 1)));
            private _distance = if (_launcherCount > 1) then {_pairSpacing / 2} else {40};
            private _position = [_longPosition,_distance,_bearing,_longClass] call _safePosition;
            private _launcher = createVehicle [_longClass,_position,[],0,"NONE"];
            if (!isNull _launcher) then {_launchers pushBack _launcher};
        };
        if (count _launchers == 2) then {_launcherPairDistance = (_launchers select 0) distance2D (_launchers select 1)};
    };
    if (_radarClass != "") then {
        private _baseBearing = [360,format ["AA_%1_LAUNCHER_BEARING",_siteType],0] call DRO2026_fnc_seededRandom;
        private _template = DRO2026_formationTemplates getOrDefault ["S300_BATTERY",createHashMap];
        private _radarRange = _template getOrDefault ["radarSpacing",[90,260]];
        private _radarMin = (_radarRange param [0,90,[0]]) max 90;
        private _radarMax = (_radarRange param [1,260,[0]]) max _radarMin;
        private _radarPosition = [];
        for "_attempt" from 0 to 7 do {
            private _bearingJitter = [-25,format ["AA_%1_RADAR_JITTER_%2",_siteType,_attempt],25] call DRO2026_fnc_seededRandom;
            private _radarBearing = _baseBearing + 90 + _bearingJitter + (_attempt * 45);
            private _distance = (_radarMin + 45) + ([((_radarMax - _radarMin - 45) max 1),format ["AA_%1_RADAR_DISTANCE_%2",_siteType,_attempt],0] call DRO2026_fnc_seededRandom);
            private _candidate = [_longPosition,_distance,_radarBearing,_radarClass] call _safePosition;
            private _nearestLauncher = if (count _launchers == 0) then {1e9} else {selectMin (_launchers apply {_candidate distance2D _x})};
            if (_nearestLauncher >= _radarMin) exitWith {_radarPosition = _candidate; _radarMinDistance = _nearestLauncher};
        };
        if (count _radarPosition < 2) then {
            _radarPosition = [_longPosition,_radarMax,_baseBearing + 90,_radarClass] call _safePosition;
            _radarMinDistance = if (count _launchers == 0) then {1e9} else {selectMin (_launchers apply {_radarPosition distance2D _x})};
        };
        _radar = createVehicle [_radarClass,_radarPosition,[],0,"NONE"];
    };
};
private _shortClass = [format ["SHORAD_%1",_suffix],_shortFallback] call _safeClass;
if (_shortClass != "") then {
    private _shortAnchor = if (_withLongRange) then {_longPosition} else {_shortPosition};
    private _shortDistance = if (_withLongRange) then {450 + ([300,format ["AA_%1_SHORAD_DISTANCE",_siteType],0] call DRO2026_fnc_seededRandom)} else {30};
    private _shortBearing = [360,format ["AA_%1_SHORAD_BEARING",_siteType],0] call DRO2026_fnc_seededRandom;
    private _shortPositionSafe = [_shortAnchor,_shortDistance,_shortBearing,_shortClass] call _safePosition;
    _shortRange = createVehicle [_shortClass,_shortPositionSafe,[],0,"NONE"];
};

{
    if (!isNull _x && {[_x,_side] call DRO2026_fnc_crewManagedVehicle}) then {
        _objects pushBack _x;
        _x enableDynamicSimulation true;
    };
} forEach (_launchers + [_radar,_shortRange]);
private _requiresFullS300 = _withLongRange && {_side == east} && {count _launchers > 0} && {typeOf (_launchers select 0) == "S300_F_UCG"};
if (_requiresFullS300 && {(count (_launchers select {_x in _objects}) < 2) || {isNull _radar} || {!(_radar in _objects)}}) exitWith {
    [_objects + _launchers + [_radar,_shortRange]] call _deleteMaterialized;
    ["AIR_DEFENCE","FORMATION_REJECTED",createHashMapFromArray [["reason","INCOMPLETE_S300_BATTERY"],["launchers",count _launchers],["radar",!isNull _radar]],_siteType] call DRO2026_fnc_logStructured;
    []
};
if (count _objects == 0) exitWith {[]};

private _primary = if (count (_launchers select {_x in _objects}) > 0) then {
    (_launchers select {_x in _objects}) select 0
} else {
    if (_shortRange in _objects) then {_shortRange} else {_objects select 0}
};
private _recordPosition = if (_primary in _launchers) then {_longPosition} else {_shortPosition};
private _siteTemplate = [_siteType,_recordPosition,_side,[360,format ["AA_%1_TEMPLATE",_siteType],0] call DRO2026_fnc_seededRandom] call DRO2026_fnc_createSiteComponents;
_objects append (_siteTemplate getOrDefault ["objects",[]]);
private _components = _siteTemplate getOrDefault ["components",createHashMap];
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
    ["formationTemplate","S300_BATTERY"],["operationSeed",missionNamespace getVariable ["DRO2026_operationSeed",1]],
    ["launcherPairDistance",_launcherPairDistance],["radarMinLauncherDistance",_radarMinDistance]
];
private _record = [_siteType,_recordPosition,_primary,_objects,_extra] call DRO2026_fnc_createSiteRecord;
if !([_record,true] call DRO2026_fnc_validateSiteRecord) exitWith {
    [_objects] call _deleteMaterialized;
    []
};
DRO2026_sites pushBack _record;
["AIR_DEFENCE","FORMATION_MATERIALIZED",createHashMapFromArray [
    ["siteType",_siteType],["launchers",count (_components getOrDefault ["launchers",[]])],
    ["radar",!isNull _radar],["shorad",!isNull _shortRange],["position",_recordPosition],
    ["launcherPairDistance",_launcherPairDistance],["radarMinLauncherDistance",_radarMinDistance]
],_siteType] call DRO2026_fnc_logStructured;
_objects
