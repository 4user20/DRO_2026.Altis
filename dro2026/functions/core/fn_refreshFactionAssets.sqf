private _enemySideNumber = switch (enemySide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _playerSideNumber = switch (playersSide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _appendFiltered = {
    params ["_role", "_classes", ["_mustBeArtillery", false], ["_sideNumber", -1], ["_mustFly", false]];
    private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        private _name = toLowerANSI _x;
        private _blockedTokens = ["spawner", "module", "logic", "dummy", "placeholder", "_root", "site_", "pook_sam"];
        private _blocked = (_blockedTokens findIf {(_name find _x) >= 0}) >= 0;
        private _valid = isClass _cfg && {getNumber (_cfg >> "scope") >= 2} && {!_blocked};
        if (_valid && {_sideNumber >= 0}) then {
            private _cfgSide = getNumber (_cfg >> "side");
            _valid = _cfgSide in [_sideNumber, 2];
        };
        if (_valid && {_mustBeArtillery}) then {
            _valid = (getNumber (_cfg >> "artilleryScanner") > 0) || {(_name find "mortar") >= 0} || {(_name find "arty") >= 0} || {(_name find "mrl") >= 0} || {count getArray (_cfg >> "availableForSupportTypes") > 0};
        };
        if (_valid && {_mustFly}) then {_valid = _x isKindOf "Air"};
        if (_valid) then {_pool pushBackUnique _x};
    } forEach _classes;
    DRO2026_assetRegistry set [_role, _pool];
};

private _enemyArtyRole = if (enemySide == west) then {"ARTILLERY_WEST"} else {"ARTILLERY_EAST"};
private _enemyLogRole = if (enemySide == west) then {"LOGISTICS_WEST"} else {"LOGISTICS_EAST"};
if (!isNil "eArtyClasses") then {[_enemyArtyRole, eArtyClasses, true, _enemySideNumber] call _appendFiltered};
if (!isNil "eMortarClasses") then {[_enemyArtyRole, eMortarClasses, true, _enemySideNumber] call _appendFiltered};
if (!isNil "eAmmoClasses") then {[_enemyLogRole, eAmmoClasses, false, _enemySideNumber] call _appendFiltered};
if (!isNil "eCarNoTurretClasses") then {[_enemyLogRole, eCarNoTurretClasses, false, _enemySideNumber] call _appendFiltered};
if (!isNil "eUAVClasses") then {["ENEMY_ISR_UAV", eUAVClasses, false, _enemySideNumber, true] call _appendFiltered};
if (!isNil "pUAVClasses") then {["PLAYER_ISR_UAV", pUAVClasses, false, _playerSideNumber, true] call _appendFiltered};

if (!isNil "pMortarClasses") then {["PLAYER_ARTILLERY_MORTAR", pMortarClasses, true, _playerSideNumber] call _appendFiltered};
if (!isNil "pArtyClasses") then {
    private _spg = pArtyClasses select {
        private _n = toLowerANSI _x;
        (_n find "mrl") < 0 && {(_n find "mlrs") < 0}
    };
    private _mlrs = pArtyClasses - _spg;
    ["PLAYER_ARTILLERY_SPG", _spg, true, _playerSideNumber] call _appendFiltered;
    ["PLAYER_ARTILLERY_MLRS", _mlrs, true, _playerSideNumber] call _appendFiltered;
};
if (!isNil "pPlaneClasses") then {["PLAYER_CAS_AIR", pPlaneClasses, false, _playerSideNumber, true] call _appendFiltered};
if (!isNil "pHeliClasses") then {["PLAYER_CAS_AIR", pHeliClasses, false, _playerSideNumber, true] call _appendFiltered};

[format ["Реестр техники обновлён: %1 ролей; player artillery=%2/%3/%4, CAS=%5", count DRO2026_assetRegistry, count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_MORTAR", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_SPG", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_MLRS", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []])]] call DRO2026_fnc_log;
