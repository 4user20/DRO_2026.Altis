params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {false};
private _inventory = (assignedItems _unit) + (items _unit);
private _known = switch (side (group _unit)) do {
    case west: {["B_UavTerminal", "I_UavTerminal", "O_UavTerminal"]};
    case resistance: {["I_UavTerminal", "B_UavTerminal", "O_UavTerminal"]};
    default {["O_UavTerminal", "B_UavTerminal", "I_UavTerminal"]};
};
(_inventory findIf {
    private _class = _x;
    if (_class in _known) exitWith {true};
    private _cfg = configFile >> "CfgWeapons" >> _class;
    if (!isClass _cfg) exitWith {false};
    private _itemType = getNumber (_cfg >> "ItemInfo" >> "type");
    private _parent = _cfg;
    private _isTerminal = _itemType == 621;
    for "_depth" from 0 to 12 do {
        if (_isTerminal) exitWith {};
        _parent = inheritsFrom _parent;
        if (isNull _parent) exitWith {};
        _isTerminal = (configName _parent) in _known;
    };
    _isTerminal
}) >= 0
