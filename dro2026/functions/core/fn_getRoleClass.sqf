params ["_role", ["_fallback", ""]];
private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
if (count _pool == 0) exitWith {_fallback};
selectRandom _pool
