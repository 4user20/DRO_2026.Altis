if (!isServer) exitWith {[]};

private _categories = missionNamespace getVariable ["DRO2026_supportCategories", ["UAV", "ARTY", "CAS"]];
if !(_categories isEqualType []) then {_categories = ["UAV", "ARTY", "CAS"]};
{_categories pushBackUnique _x} forEach ["UAV", "ARTY", "CAS"];
_categories = _categories apply {toUpperANSI _x};
private _exposeAllInstalled = missionNamespace getVariable ["DRO2026_SUPPORT_EXPOSE_ALL_INSTALLED", true];
private _sideSuffix = [playersSide] call DRO2026_fnc_getSideSuffix;
private _sideNumber = [playersSide] call DRO2026_fnc_getSideNumber;
private _selectedFactions = ([playersFaction] + (missionNamespace getVariable ["playersFactionAdv", []])) select {_x isEqualType "" && {_x != ""}};
_selectedFactions = _selectedFactions apply {toUpperANSI _x};
private _catalog = [];
private _seen = [];

private _displayName = {
    params ["_class"];
    private _name = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
    if (_name == "") then {_name = _class};
    _name
};
private _validVehicle = {
    params ["_class", ["_mustFly", false], ["_selectedFactionOnly", false], ["_matchPlayerSide", true]];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1}) exitWith {false};
    if (_mustFly && {!(_class isKindOf "Air")}) exitWith {false};
    if (_matchPlayerSide && {_sideNumber >= 0} && {getNumber (_cfg >> "side") != _sideNumber}) exitWith {false};
    if (_selectedFactionOnly && {count _selectedFactions > 0}) then {
        private _faction = toUpperANSI getText (_cfg >> "faction");
        if !(_faction in _selectedFactions) exitWith {false};
    };
    private _lower = toLowerANSI _class;
    private _blocked = ["spawner", "module", "logic", "dummy", "placeholder", "_root", "site_", "pook_sam", "azncontrol", "pook_tos1a"];
    (_blocked findIf {(_lower find _x) >= 0}) < 0
};
private _add = {
    params ["_category", "_mode", "_class", "_label", ["_tooltip", ""], ["_maxQuantity", 1]];
    private _key = format ["%1|%2|%3", _category, _mode, _class];
    if (_key in _seen) exitWith {};
    private _cfg = if (_class == "") then {configNull} else {configFile >> "CfgVehicles" >> _class};
    if (_class != "" && {!isClass _cfg}) exitWith {};
    _seen pushBack _key;
    _catalog pushBack createHashMapFromArray [
        ["schema", 1], ["category", _category],
        ["channel", switch _category do {case "ARTY": {"ARTILLERY"}; case "CAS": {"CAS"}; default {"UAV"}}],
        ["mode", _mode], ["assetClass", _class], ["label", _label], ["tooltip", _tooltip], ["maxQuantity", (_maxQuantity max 1) min 10]
    ];
};
private _roleClasses = {
    params ["_roles", ["_mustFly", false], ["_selectedFactionOnly", false], ["_matchPlayerSide", true]];
    private _classes = [];
    {_classes append (DRO2026_assetRegistry getOrDefault [_x, []])} forEach _roles;
    _classes = _classes arrayIntersect _classes;
    _classes select {[_x, _mustFly, _selectedFactionOnly, _matchPlayerSide] call _validVehicle}
};
private _launcherAvailable = {
    params ["_roles", ["_fallbackAmmoRole", ""]];
    private _launchers = [];
    {_launchers append (DRO2026_assetRegistry getOrDefault [_x, []])} forEach _roles;
    private _ok = (_launchers findIf {([_x] call DRO2026_fnc_resolveLauncherAmmo) != ""}) >= 0;
    if (!_ok && {_fallbackAmmoRole != ""}) then {_ok = count (DRO2026_ammoRegistry getOrDefault [_fallbackAmmoRole, []]) > 0};
    _ok
};
private _allSuffixes = if (_exposeAllInstalled) then {["WEST", "EAST", "GUER"]} else {[_sideSuffix]};

if ("UAV" in _categories) then {
    private _fpvRoles = _allSuffixes apply {format ["FPV_%1", _x]};
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["FPV_CLASS_AUTO:%1", _x], _x, format ["FPV — %1 (авто)", _name], "Любой установленный зарегистрированный FPV-класс; экипаж создаётся на стороне игрока.", 4] call _add;
        ["UAV", format ["FPV_CLASS_MANUAL:%1", _x], _x, format ["FPV — %1 (ручное управление)", _name], "После запуска появится действие подключения к UAV Terminal.", 1] call _add;
    } forEach ([_fpvRoles, true, false, !_exposeAllInstalled] call _roleClasses);

    private _isrRoles = ["PLAYER_ISR_UAV", "ENEMY_ISR_UAV"];
    {_isrRoles pushBackUnique format ["ISR_MICRO_%1", _x]; _isrRoles pushBackUnique format ["ISR_TACTICAL_%1", _x]; _isrRoles pushBackUnique format ["ISR_HALE_%1", _x]} forEach _allSuffixes;
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["ISR_CLASS:%1", _x], _x, format ["Разведка — %1", _name], "Установленный БПЛА независимо от выбранной фракции.", 1] call _add;
    } forEach ([_isrRoles, true, false, !_exposeAllInstalled] call _roleClasses);

    private _longRoles = _allSuffixes apply {format ["LONG_RANGE_%1", _x]};
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["STRIKE_CLASS:%1", _x], _x, format ["Дальний удар — %1", _name], "Физический ударный аппарат установленного класса.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
    } forEach ([_longRoles, true, false, !_exposeAllInstalled] call _roleClasses);

    private _profile = {
        params ["_mode", "_label", "_available", ["_maxQuantity", 10]];
        if (_available) then {["UAV", _mode, "", _label, "Профиль доступен, если в загруженных модах найден аппарат, пусковая или штатный боеприпас.", _maxQuantity] call _add};
    };
    private _rolesFor = {params ["_system"]; _allSuffixes apply {format ["LAUNCHER_%1_%2", _system, _x]}};
    private _fp1Roles = ["FP1"] call _rolesFor;
    private _fp2Roles = ["FP2"] call _rolesFor;
    private _bm35Roles = ["BM35"] call _rolesFor;
    private _bulavaRoles = ["BULAVA"] call _rolesFor;
    private _fp5Roles = ["FP5"] call _rolesFor;
    ["STRIKE_FP1", "Дальний удар — FP-1", [_fp1Roles, "STRIKE_AMMO_FP1"] call _launcherAvailable, 6] call _profile;
    ["STRIKE_FP2", "Дальний удар — FP-2", [_fp2Roles, "STRIKE_AMMO_FP2"] call _launcherAvailable, 6] call _profile;
    ["STRIKE_BM35", "Дальний удар — BM-35 / Italmas", [_bm35Roles, "STRIKE_AMMO_BM35"] call _launcherAvailable, 6] call _profile;
    ["STRIKE_BULAVA", "Дальний удар — Bulava", [_bulavaRoles, ""] call _launcherAvailable, 4] call _profile;
    ["STRIKE_FP5", "Дальний удар — FP-5 Flamingo", [_fp5Roles, "STRIKE_AMMO_FP5"] call _launcherAvailable, 1] call _profile;
    if (count ([_longRoles, true, false, !_exposeAllInstalled] call _roleClasses) > 0) then {
        ["UAV", "STRIKE_AUTO", "", "Дальний удар — смешанный пакет", "Автоматический выбор из всех установленных зарегистрированных аппаратов.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
        ["UAV", "STRIKE_DECOY", "", "Дальний запуск — БПЛА-обманки", "Провоцирует работу ПВО и занимает каналы сопровождения.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
    };
};

if ("ARTY" in _categories) then {
    private _artyRoles = ["PLAYER_ARTILLERY_MORTAR", "PLAYER_ARTILLERY_SPG", "PLAYER_ARTILLERY_MLRS"] + (_allSuffixes apply {format ["ARTILLERY_%1", _x]});
    {
        private _name = [_x] call _displayName;
        ["ARTY", format ["ARTY:%1", _x], _x, format ["Артиллерия — %1", _name], "Установленная штатная артсистема; проблемные Pook TOS/SAM классы исключены.", 10] call _add;
    } forEach ([_artyRoles, false, false, !_exposeAllInstalled] call _roleClasses);
};

if ("CAS" in _categories) then {
    {
        private _name = [_x] call _displayName;
        ["CAS", format ["AIR:%1", _x], _x, format ["Авиация — %1", _name], "Самолёт или вертолёт с реальным standoff-вооружением; экипаж создаётся на стороне игрока.", 2] call _add;
    } forEach ([["PLAYER_CAS_AIR", "ENEMY_CAS_AIR"], true, false, !_exposeAllInstalled] call _roleClasses);
};

private _validCatalog = _catalog select {
    _x isEqualType createHashMap && {(_x getOrDefault ["category", ""]) != ""} && {(_x getOrDefault ["mode", ""]) != ""} && {(_x getOrDefault ["maxQuantity", 0]) isEqualType 0}
};
private _channels = (_validCatalog apply {_x getOrDefault ["channel", ""]}) select {_x != ""};
_channels = _channels arrayIntersect _channels;
private _signature = str [_sideSuffix, _selectedFactions, _categories, _exposeAllInstalled, _validCatalog apply {_x getOrDefault ["mode", ""]}];
private _currentSignature = missionNamespace getVariable ["DRO2026_supportCatalogSignature", ""];
if ((missionNamespace getVariable ["DRO2026_supportCatalogReady", false]) && {_signature == _currentSignature}) exitWith {missionNamespace getVariable ["DRO2026_supportCatalog", []]};
missionNamespace setVariable ["DRO2026_supportCatalog", _validCatalog, true];
missionNamespace setVariable ["DRO2026_supportChannels", _channels, true];
missionNamespace setVariable ["DRO2026_supportCatalogSignature", _signature, true];
missionNamespace setVariable ["DRO2026_supportCatalogReady", true, true];
missionNamespace setVariable ["DRO2026_supportCatalogVersion", (missionNamespace getVariable ["DRO2026_supportCatalogVersion", 0]) + 1, true];
["SUPPORT", "CATALOG_PUBLISHED", createHashMapFromArray [["entries", count _validCatalog], ["channels", _channels], ["allInstalled", _exposeAllInstalled], ["version", missionNamespace getVariable ["DRO2026_supportCatalogVersion", 0]]], _signature] call DRO2026_fnc_logStructured;
_validCatalog
