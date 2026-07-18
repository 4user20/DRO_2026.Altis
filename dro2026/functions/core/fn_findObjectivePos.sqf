params ["_AOIndex", ["_kind", "FLAT"], ["_minDist", 0]];
private _ao = AOLocations select _AOIndex;
private _aoCenter = _ao select 0;
private _data = _ao select 2;
private _candidates = switch (_kind) do {
    case "ROAD": {_data select 0};
    case "GROUND": {_data select 2};
    case "FAR": {_data select 3};
    case "FOREST": {_data select 6};
    case "BUILDING": {(_data select 7) apply {getPosATL _x}};
    default {_data select 4};
};
if (count _candidates == 0) then {_candidates = (_data select 2) + (_data select 3) + (_data select 4) + ((_data select 7) apply {getPosATL _x})};
if (count _candidates == 0) exitWith {_aoCenter};
private _reference = missionNamespace getVariable ["startPos", []];
if !(_reference isEqualType [] && {count _reference >= 2}) then {_reference = _aoCenter};
private _filtered = _candidates select {
    private _candidate = _x;
    if (_candidate isEqualType objNull) then {_candidate = getPosATL _candidate};
    _candidate isEqualType [] && {count _candidate >= 2} && {(_candidate distance2D _reference) > _minDist}
};
if (count _filtered == 0) then {_filtered = _candidates};
private _pos = selectRandom _filtered;
if (_pos isEqualType objNull) then {_pos = getPosATL _pos};
if !(_pos isEqualType [] && {count _pos >= 2}) exitWith {_aoCenter};
[_pos select 0, _pos select 1, 0]
