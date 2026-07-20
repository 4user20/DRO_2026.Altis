params ["_type", "_node", "_side"];
if (!isServer) exitWith {createHashMap};
private _position = [_node] call DRO2026_fnc_getTheaterNode;
private _team = [_position, _side, _type] call DRO2026_fnc_createDroneTeam;
if (count _team == 0) exitWith {createHashMap};
private _operator = _team getOrDefault ["operator", objNull];
private _group = _team getOrDefault ["group", grpNull];
if (isNull _operator || {isNull _group}) exitWith {createHashMap};
private _objects = [_operator];
{
    private _object = _team getOrDefault [_x, objNull];
    if (!isNull _object) then {_objects pushBackUnique _object};
} forEach ["assistant", "antenna", "tent"];
private _extra = createHashMapFromArray [
    ["operator", _operator], ["team", _team], ["virtual", false], ["background", true]
];
private _record = [_type, _position, _operator, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if !([_record, true, ["operator"]] call DRO2026_fnc_validateSiteRecord) exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
    if (!isNull _group) then {deleteGroup _group};
    {
        private _object = _team getOrDefault [_x, objNull];
        if (!isNull _object) then {deleteVehicle _object};
    } forEach ["antenna", "tent"];
    createHashMap
};
DRO2026_sites pushBack _record;
_record
