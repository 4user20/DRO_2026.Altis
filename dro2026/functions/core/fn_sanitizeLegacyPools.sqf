private _blockedTokens = ["spawner", "module", "logic", "dummy", "placeholder", "virtual", "_base", "curator", "site_", "_root"];
private _safeConfigClass = {
    params ["_class", ["_mustBeMan", false]];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith {false};
    if (getNumber (_cfg >> "scope") < 2) exitWith {false};
    if (_mustBeMan && {!(_class isKindOf "Man")}) exitWith {false};
    private _name = toLowerANSI _class;
    if ((_blockedTokens findIf {(_name find _x) >= 0}) >= 0) exitWith {false};
    true
};

private _infantryPools = ["pInfClasses", "eInfClasses", "civClasses"];
{
    private _name = _x;
    private _pool = missionNamespace getVariable [_name, []];
    private _before = count _pool;
    _pool = _pool select {[_x, true] call _safeConfigClass};
    missionNamespace setVariable [_name, _pool];
    if (_before != count _pool) then {[format ["Очищен пул %1: %2 -> %3", _name, _before, count _pool]] call DRO2026_fnc_log};
} forEach _infantryPools;

private _vehiclePools = [
    "pCarClasses", "pCarNoTurretClasses", "pCarTurretClasses", "pTankClasses", "pAAClasses", "pStaticClasses",
    "pHeliClasses", "pPlaneClasses", "pUAVClasses", "pArtyClasses", "pMortarClasses", "pAmmoClasses",
    "eCarClasses", "eCarNoTurretClasses", "eCarTurretClasses", "eTankClasses", "eAAClasses", "eStaticClasses",
    "eHeliClasses", "ePlaneClasses", "eUAVClasses", "eArtyClasses", "eMortarClasses", "eAmmoClasses"
];
{
    private _name = _x;
    private _pool = missionNamespace getVariable [_name, []];
    private _before = count _pool;
    _pool = _pool select {[_x, false] call _safeConfigClass};
    missionNamespace setVariable [_name, _pool];
    if (_before != count _pool) then {[format ["Очищен пул %1: %2 -> %3", _name, _before, count _pool]] call DRO2026_fnc_log};
} forEach _vehiclePools;
true
