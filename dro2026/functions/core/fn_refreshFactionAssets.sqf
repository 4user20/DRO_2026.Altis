private _sideNumber = switch (enemySide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _appendFiltered = {
    params ["_role", "_classes", ["_mustBeArtillery", false]];
    private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        private _name = toLowerANSI _x;
        private _blockedTokens = ["spawner", "module", "logic", "dummy", "placeholder", "_root", "site_"];
        private _blocked = (_blockedTokens findIf {(_name find _x) >= 0}) >= 0;
        private _valid = isClass _cfg && {getNumber (_cfg >> "scope") >= 2} && {!_blocked};
        if (_valid && {_sideNumber >= 0}) then {
            private _cfgSide = getNumber (_cfg >> "side");
            _valid = _cfgSide in [_sideNumber, 2];
        };
        if (_valid && {_mustBeArtillery}) then {
            _valid = (getNumber (_cfg >> "artilleryScanner") > 0) || {(_name find "mortar") >= 0} || {(_name find "arty") >= 0} || {(_name find "mrl") >= 0};
        };
        if (_valid) then {_pool pushBackUnique _x};
    } forEach _classes;
    DRO2026_assetRegistry set [_role, _pool];
};

private _artyRole = if (enemySide == west) then {"ARTILLERY_WEST"} else {"ARTILLERY_EAST"};
private _logRole = if (enemySide == west) then {"LOGISTICS_WEST"} else {"LOGISTICS_EAST"};
if (!isNil "eArtyClasses") then {[_artyRole, eArtyClasses, true] call _appendFiltered};
if (!isNil "eMortarClasses") then {[_artyRole, eMortarClasses, true] call _appendFiltered};
if (!isNil "eAmmoClasses") then {[_logRole, eAmmoClasses] call _appendFiltered};
if (!isNil "eCarNoTurretClasses") then {[_logRole, eCarNoTurretClasses] call _appendFiltered};
if (!isNil "eUAVClasses") then {["ENEMY_ISR_UAV", eUAVClasses] call _appendFiltered};
if (!isNil "pUAVClasses") then {["PLAYER_ISR_UAV", pUAVClasses] call _appendFiltered};

[format ["Реестр техники обновлён: %1 ролей", count DRO2026_assetRegistry]] call DRO2026_fnc_log;
