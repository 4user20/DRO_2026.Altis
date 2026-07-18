params ["_class", ["_side", sideUnknown]];
private _cfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg) exitWith {false};
if !(_class isKindOf "Man") exitWith {false};
if (getNumber (_cfg >> "scope") < 2) exitWith {false};
private _name = toLowerANSI _class;
private _blockedTokens = ["spawner", "module", "logic", "dummy", "placeholder", "virtual", "_base", "curator", "uav_ai", "site_"];
if ((_blockedTokens findIf {(_name find _x) >= 0}) >= 0) exitWith {false};
if (_side != sideUnknown) then {
    private _expected = switch (_side) do {
        case east: {0};
        case west: {1};
        case resistance: {2};
        case civilian: {3};
        default {-1};
    };
    if (_expected >= 0 && {getNumber (_cfg >> "side") != _expected}) exitWith {false};
};
true
