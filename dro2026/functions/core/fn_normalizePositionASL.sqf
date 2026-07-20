params [
    ["_position",[],[[]]],
    ["_space","ASL",[""]],
    ["_fallbackObject",objNull,[objNull]]
];

if (count _position < 2 && {!isNull _fallbackObject}) exitWith {getPosASL _fallbackObject};
if !(_position isEqualType [] && {count _position in [2,3]}) exitWith {[]};
if ((_position findIf {!(_x isEqualType 0)}) >= 0) exitWith {[]};

private _x = _position param [0,0,[0]];
private _y = _position param [1,0,[0]];
private _spaceUpper = toUpperANSI _space;

switch _spaceUpper do {
    case "ASL": {
        [_x,_y,if (count _position > 2) then {_position param [2,0,[0]]} else {getTerrainHeightASL [_x,_y]}]
    };
    case "ATL": {
        ATLToASL [_x,_y,if (count _position > 2) then {_position param [2,0,[0]]} else {0}]
    };
    case "AGL": {
        AGLToASL [_x,_y,if (count _position > 2) then {_position param [2,0,[0]]} else {0}]
    };
    default {[]};
}
