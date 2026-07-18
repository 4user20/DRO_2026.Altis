params ["_key", ["_fallback", []]];
if !(missionNamespace getVariable ["DRO2026_theaterBuilt", false]) then {[] call DRO2026_fnc_buildTheaterGraph};
private _value = DRO2026_theaterNodes getOrDefault [_key, _fallback];
if !(_value isEqualType []) exitWith {_fallback};
+_value
