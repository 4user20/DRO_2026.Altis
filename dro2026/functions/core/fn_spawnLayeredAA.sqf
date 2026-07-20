params ["_siteType", "_side", "_longNode", "_shortNode", ["_withLongRange", true]];
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
    default {"Land_Radar_F"};
};
private _shortFallback = switch (_side) do {
    case west: {"B_APC_Tracked_01_AA_F"};
    case resistance: {"I_LT_01_AA_F"};
    default {"O_APC_Tracked_02_AA_F"};
};
private _blocked = ["spawner", "module", "logic", "_root", "site_", "samsite", "sam_site", "azncontrol", "unit_scanner", "pook_sam", "pook_azncontrol"];
private _safeClass = {
    params ["_role", "_fallback", ["_allowNeutral", false]];
    private _class = [_role, _fallback, _side, _allowNeutral] call DRO2026_fnc_getSideRoleClass;
    if (_class == "") exitWith {""};
    private _lower = toLowerANSI _class;
    if ((_blocked findIf {(_lower find _x) >= 0}) >= 0) exitWith {""};
    _class
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
private _longRange = objNull;
private _radar = objNull;
if (_withLongRange) then {
    private _longClass = [format ["LONG_RANGE_AA_%1", _suffix], _longFallback] call _safeClass;
    private _radarClass = [format ["RADAR_%1", _suffix], _radarFallback, true] call _safeClass;
    if (_longClass != "") then {_longRange = createVehicle [_longClass, _longPosition, [], 0, "NONE"]};
    if (_radarClass != "") then {_radar = createVehicle [_radarClass, _longPosition getPos [95, random 360], [], 0, "NONE"]};
};
private _shortClass = [format ["SHORAD_%1", _suffix], _shortFallback] call _safeClass;
private _shortRange = if (_shortClass == "") then {objNull} else {createVehicle [_shortClass, _shortPosition, [], 0, "NONE"]};
private _objects = [];
{
    if (!isNull _x && {[_x, _side] call DRO2026_fnc_crewManagedVehicle}) then {
        _objects pushBack _x;
        _x enableDynamicSimulation true;
    };
} forEach [_longRange, _radar, _shortRange];
if (count _objects == 0) exitWith {[]};
private _primary = if (_longRange in _objects) then {_longRange} else {if (_shortRange in _objects) then {_shortRange} else {_objects select 0}};
private _recordPosition = if (_primary == _longRange) then {_longPosition} else {_shortPosition};
private _extra = createHashMapFromArray [
    ["radar", if (_radar in _objects) then {_radar} else {objNull}],
    ["shorad", if (_shortRange in _objects) then {_shortRange} else {objNull}],
    ["background", _siteType != "AIR_DEFENCE_SITE"], ["networked", _withLongRange]
];
private _record = [_siteType, _recordPosition, _primary, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if !([_record, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    [_objects] call _deleteMaterialized;
    []
};
DRO2026_sites pushBack _record;
if (_longRange in _objects && {_radar in _objects}) then {
    [_longRange, _radar] spawn {
        params ["_launcher", "_radar"];
        waitUntil {
            sleep 3;
            isNull _launcher || {!alive _launcher} || {isNull _radar} || {!alive _radar} ||
            {missionNamespace getVariable ["DRO2026_missionEnding", false]}
        };
        if (!isNull _launcher && {alive _launcher} && {isNull _radar || {!alive _radar}}) then {
            _launcher setVehicleReceiveRemoteTargets false;
            _launcher setVehicleReportRemoteTargets false;
            _launcher setVehicleReportOwnPosition false;
            if (!isNull (gunner _launcher)) then {
                (gunner _launcher) disableAI "AUTOTARGET";
                (gunner _launcher) disableAI "TARGET";
            };
        };
    };
};
_objects
