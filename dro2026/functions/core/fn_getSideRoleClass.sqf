params ["_role","_fallback","_side",["_allowNeutral",false]];
private _expected = [_side] call DRO2026_fnc_getSideNumber;
private _roleUpper = toUpperANSI _role;
if ((_roleUpper find "CONVOY_CARGO_") == 0) exitWith {
    [_role,_side,"GENERAL",_fallback,"CARGO",format ["ROLE_CLASS_%1_%2",_roleUpper,_expected]] call DRO2026_fnc_selectConvoyClass
};
if ((_roleUpper find "CONVOY_ESCORT_") == 0) exitWith {
    [_role,_side,"GENERAL",_fallback,"ESCORT",format ["ROLE_CLASS_%1_%2",_roleUpper,_expected]] call DRO2026_fnc_selectConvoyClass
};
private _candidates = +(DRO2026_assetRegistry getOrDefault [_role,[]]);
if (_fallback != "") then {_candidates pushBackUnique _fallback};
private _valid = _candidates select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1} || {getNumber (_cfg >> "isBackpack") > 0}) exitWith {false};
    private _cfgSide = getNumber (_cfg >> "side");
    _expected < 0 || {_cfgSide == _expected} || {_allowNeutral && {_cfgSide == 3}}
};
if (count _valid == 0) exitWith {""};
// Keep the source-backed legacy contract available as an explicit compatibility mode.
if (missionNamespace getVariable ["DRO2026_USE_LEGACY_ROLE_RANDOM",false]) exitWith {selectRandom _valid};
private _stream = format ["ROLE_CLASS_%1_%2",toUpperANSI _role,_expected];
private _index = floor ([count _valid,_stream,0] call DRO2026_fnc_seededRandom);
_valid param [_index,_valid select 0]
