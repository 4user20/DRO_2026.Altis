params ["_type", "_node", "_side"];
if (!isServer) exitWith {createHashMap};
private _position = [_node] call DRO2026_fnc_getTheaterNode;
private _team = [_position, _side, _type] call DRO2026_fnc_createDroneTeam;
private _operator = _team getOrDefault ["operator", objNull];
if (isNull _operator) exitWith {createHashMap};
private _objects = [_operator];
{
    private _object = _team getOrDefault [_x, objNull];
    if (!isNull _object) then {_objects pushBackUnique _object};
} forEach ["assistant", "antenna", "tent"];
private _extra = createHashMapFromArray [
    ["operator", _operator], ["team", _team], ["virtual", false], ["background", true]
];
private _record = [_type, _position, _operator, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if ([_record, true, ["operator"]] call DRO2026_fnc_validateSiteRecord) then {
    DRO2026_sites pushBack _record;
    _record
} else {
    createHashMap
}
