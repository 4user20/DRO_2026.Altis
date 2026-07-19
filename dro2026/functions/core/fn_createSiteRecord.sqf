params [
    "_type",
    "_position",
    ["_object", objNull],
    ["_objects", []],
    ["_extra", createHashMap]
];

if !(_type isEqualType "") exitWith {createHashMap};
if (_type == "" || {!(_position isEqualType [])} || {count _position < 2}) exitWith {createHashMap};
if !(_objects isEqualType []) then {_objects = []};
if (!isNull _object) then {_objects pushBackUnique _object};

private _record = createHashMapFromArray [
    ["schema", 1],
    ["type", _type],
    ["position", +_position],
    ["object", _object],
    ["objects", _objects select {!isNull _x}],
    ["createdAt", time],
    ["background", false]
];

private _emptyMap = createHashMap;
if (_extra isEqualType _emptyMap) then {
    {
        _record set [_x, _extra get _x];
    } forEach keys _extra;
};
_record