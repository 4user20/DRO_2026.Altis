params ["_role", "_fallback", "_side", ["_allowNeutral", false]];
private _expected = [_side] call DRO2026_fnc_getSideNumber;
private _selected = "";
{
    private _cfg = configFile >> "CfgVehicles" >> _x;
    if (_selected == "" && {isClass _cfg}) then {
        private _cfgSide = getNumber (_cfg >> "side");
        if (_expected < 0 || {_cfgSide == _expected} || {_allowNeutral && {_cfgSide == 3}}) then {
            _selected = _x;
        };
    };
} forEach [[_role, _fallback] call DRO2026_fnc_getRoleClass, _fallback];
_selected
