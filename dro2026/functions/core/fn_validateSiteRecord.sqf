params ["_record", ["_requireAliveObject", false], ["_requiredKeys", []]];

private _emptyMap = createHashMap;
if !(_record isEqualType _emptyMap) exitWith {false};
private _type = _record getOrDefault ["type", ""];
private _position = _record getOrDefault ["position", []];
if !(_type isEqualType "") exitWith {false};
if (_type == "") exitWith {false};
if !(_position isEqualType []) exitWith {false};
if (count _position < 2) exitWith {false};
if ((_position select 0) < 0 || {(_position select 1) < 0}) exitWith {false};
if ((_position select 0) > worldSize || {(_position select 1) > worldSize}) exitWith {false};

if (_requireAliveObject) then {
    private _object = _record getOrDefault ["object", objNull];
    if (isNull _object || {!alive _object}) exitWith {false};
};

private _missing = _requiredKeys findIf {isNil {_record get _x}};
_missing < 0