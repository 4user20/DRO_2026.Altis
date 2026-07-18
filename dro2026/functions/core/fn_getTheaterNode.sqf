params ["_key", ["_fallback", []]];
[] call DRO2026_fnc_buildTheaterGraph;
private _value = DRO2026_theaterNodes getOrDefault [_key, _fallback];
if (_value isEqualType 0) exitWith {_fallback};
+_value
