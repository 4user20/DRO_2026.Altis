params ["_role", "_fallback", "_side", ["_allowNeutral", false]];
private _expected = [_side] call DRO2026_fnc_getSideNumber;
private _candidates = +(DRO2026_assetRegistry getOrDefault [_role, []]);
if (_fallback != "") then {_candidates pushBackUnique _fallback};
private _valid = _candidates select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    if (!isClass _cfg) exitWith {false};
    private _cfgSide = getNumber (_cfg >> "side");
    _expected < 0 || {_cfgSide == _expected} || {_allowNeutral && {_cfgSide == 3}}
};
if (count _valid == 0) exitWith {""};
selectRandom _valid
