params ["_nodeKey", "_side", "_type"];
if (!isServer) exitWith {objNull};
private _position = [_nodeKey] call DRO2026_fnc_getTheaterNode;
private _hqClass = ["COMMAND", "Land_Cargo_HQ_V1_F"] call DRO2026_fnc_getRoleClass;
private _hq = createVehicle [_hqClass, _position, [], 0, "NONE"];
if (isNull _hq) exitWith {objNull};
_hq setDir random 360;
private _bunker = createVehicle ["Land_BagBunker_Tower_F", _position getPos [18, 55], [], 0, "CAN_COLLIDE"];
private _tent = createVehicle ["Land_TentA_F", _position getPos [14, 215], [], 0, "CAN_COLLIDE"];
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _fallback = switch (_side) do {
    case west: {"B_soldier_UAV_F"};
    case resistance: {"I_soldier_UAV_F"};
    default {"O_soldier_UAV_F"};
};
private _officerClass = [format ["OFFICER_%1", _suffix], _fallback, _side] call DRO2026_fnc_getSideRoleClass;
if (_officerClass == "") exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach [_hq, _bunker, _tent];
    objNull
};
private _group = createGroup [_side, true];
private _officer = _group createUnit [_officerClass, _position getPos [3, random 360], [], 2, "NONE"];
if (isNull _officer) exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach [_hq, _bunker, _tent];
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
private _extra = createHashMapFromArray [["officer", _officer], ["group", _group], ["background", true]];
private _record = [_type, _position, _hq, [_hq, _bunker, _tent], _extra] call DRO2026_fnc_createSiteRecord;
if ([_record, true, ["officer", "group"]] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _record};
_hq
