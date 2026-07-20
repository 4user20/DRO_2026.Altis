private _enemySideNumber = switch (enemySide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _playerSideNumber = switch (playersSide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _appendFiltered = {
    params ["_role", "_classes", ["_mustBeArtillery", false], ["_sideNumber", -1], ["_mustFly", false]];
    private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        private _name = toLowerANSI _x;
        private _blockedTokens = ["spawner", "module", "logic", "dummy", "placeholder", "_root", "site_", "pook_sam", "pook_tos1a"];
        private _blocked = (_blockedTokens findIf {(_name find _x) >= 0}) >= 0;
        private _valid = isClass _cfg && {getNumber (_cfg >> "scope") >= 2} && {!_blocked};
        if (_valid && {_sideNumber >= 0}) then {
            private _cfgSide = getNumber (_cfg >> "side");
            _valid = _cfgSide == _sideNumber;
        };
        if (_valid && {_mustBeArtillery}) then {
            _valid = (getNumber (_cfg >> "artilleryScanner") > 0) || {(_name find "mortar") >= 0} || {(_name find "arty") >= 0} || {(_name find "mrl") >= 0} || {count getArray (_cfg >> "availableForSupportTypes") > 0};
        };
        if (_valid && {_mustFly}) then {_valid = _x isKindOf "Air"};
        if (_valid) then {_pool pushBackUnique _x};
    } forEach _classes;
    DRO2026_assetRegistry set [_role, _pool];
};

{
    DRO2026_assetRegistry set [_x, []];
} forEach ["PLAYER_ISR_UAV", "ENEMY_ISR_UAV", "ENEMY_CAS_AIR", "PLAYER_ARTILLERY_MORTAR", "PLAYER_ARTILLERY_SPG", "PLAYER_ARTILLERY_MLRS", "PLAYER_CAS_AIR", "PLAYER_LOGISTICS"];

private _enemySuffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _enemyArtyRole = format ["ARTILLERY_%1", _enemySuffix];
private _enemyLogRole = format ["LOGISTICS_%1", _enemySuffix];
if (!isNil "eArtyClasses") then {[_enemyArtyRole, eArtyClasses, true, _enemySideNumber] call _appendFiltered};
if (!isNil "eMortarClasses") then {[_enemyArtyRole, eMortarClasses, true, _enemySideNumber] call _appendFiltered};
if (!isNil "eAmmoClasses") then {[_enemyLogRole, eAmmoClasses, false, _enemySideNumber] call _appendFiltered};
if (!isNil "eCarNoTurretClasses") then {[_enemyLogRole, eCarNoTurretClasses, false, _enemySideNumber] call _appendFiltered};
if (!isNil "eUAVClasses") then {["ENEMY_ISR_UAV", eUAVClasses, false, _enemySideNumber, true] call _appendFiltered};
if (!isNil "ePlaneClasses") then {["ENEMY_CAS_AIR", ePlaneClasses, false, _enemySideNumber, true] call _appendFiltered};
if (!isNil "eHeliClasses") then {["ENEMY_CAS_AIR", eHeliClasses, false, _enemySideNumber, true] call _appendFiltered};
if (!isNil "pUAVClasses") then {["PLAYER_ISR_UAV", pUAVClasses, false, _playerSideNumber, true] call _appendFiltered};

if (!isNil "pAmmoClasses") then {["PLAYER_LOGISTICS", pAmmoClasses, false, _playerSideNumber] call _appendFiltered};
if (!isNil "pCarNoTurretClasses") then {["PLAYER_LOGISTICS", pCarNoTurretClasses, false, _playerSideNumber] call _appendFiltered};
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

private _explicitPlayerISR = switch (playersSide) do {
    case west: {["rksla3_uav_rq7shadow_01_blufor", "HE_MQ4A_Blufor", "B_UAV_02_dynamicLoadout_F"]};
    case resistance: {["I_UAV_02_dynamicLoadout_F"]};
    default {["RUS_VKS_forpostru", "O_UAV_02_dynamicLoadout_F"]};
};
["PLAYER_ISR_UAV", _explicitPlayerISR, false, _playerSideNumber, true] call _appendFiltered;
private _explicitEnemyISR = switch (enemySide) do {
    case east: {["RUS_VKS_forpostru", "O_UAV_02_dynamicLoadout_F"]};
    case west: {["rksla3_uav_rq7shadow_01_blufor", "HE_MQ4A_Blufor", "B_UAV_02_dynamicLoadout_F"]};
    case resistance: {["I_UAV_02_dynamicLoadout_F"]};
    default {[]};
};
["ENEMY_ISR_UAV", _explicitEnemyISR, false, _enemySideNumber, true] call _appendFiltered;

private _explicitEnemyAir = switch (enemySide) do {
    case east: {["RUS_VKS_su57", "RUS_VKS_mi8t", "RUS_VKS_l39", "O_Plane_CAS_02_dynamicLoadout_F", "O_Heli_Attack_02_dynamicLoadout_F"]};
    case west: {["B_Plane_CAS_01_dynamicLoadout_F", "B_Heli_Attack_01_dynamicLoadout_F"]};
    case resistance: {["I_Plane_Fighter_03_dynamicLoadout_F", "I_Heli_light_03_dynamicLoadout_F"]};
    default {[]};
};
["ENEMY_CAS_AIR", _explicitEnemyAir, false, _enemySideNumber, true] call _appendFiltered;

[format ["Реестр техники обновлён: %1 ролей; player artillery=%2/%3/%4, CAS=%5, ISR=%6, logistics=%7; enemy ISR=%8, CAS=%9", count DRO2026_assetRegistry, count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_MORTAR", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_SPG", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_ARTILLERY_MLRS", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_ISR_UAV", []]), count (DRO2026_assetRegistry getOrDefault ["PLAYER_LOGISTICS", []]), count (DRO2026_assetRegistry getOrDefault ["ENEMY_ISR_UAV", []]), count (DRO2026_assetRegistry getOrDefault ["ENEMY_CAS_AIR", []])]] call DRO2026_fnc_log;
if (isServer) then {[] call DRO2026_fnc_publishSupportCatalog};
