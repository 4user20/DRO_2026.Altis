if (!isServer) exitWith {[]};

private _categories = missionNamespace getVariable ["DRO2026_supportCategories", ["UAV", "ARTY", "CAS"]];
if !(_categories isEqualType []) then {_categories = ["UAV", "ARTY", "CAS"]};
_categories = _categories apply {toUpperANSI _x};
_categories = _categories arrayIntersect _categories;

private _sideSuffix = switch (playersSide) do {case west: {"WEST"}; case resistance: {"GUER"}; default {"EAST"}};
private _sideNumber = switch (playersSide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
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
    params ["_class", ["_mustFly", false], ["_selectedFactionOnly", false]];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1}) exitWith {false};
    if (_mustFly && {!(_class isKindOf "Air")}) exitWith {false};
    private _cfgSide = getNumber (_cfg >> "side");
    if (_sideNumber >= 0 && {!(_cfgSide in [_sideNumber, 2])}) exitWith {false};
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
    _seen pushBack _key;
    _catalog pushBack [_category, _mode, _class, _label, _tooltip, _maxQuantity];
};
private _roleClasses = {
    params ["_roles", ["_mustFly", false], ["_selectedFactionOnly", false]];
    private _classes = [];
    {_classes append (DRO2026_assetRegistry getOrDefault [_x, []])} forEach _roles;
    _classes = _classes arrayIntersect _classes;
    _classes select {[_x, _mustFly, _selectedFactionOnly] call _validVehicle}
};
private _hasUsableLauncher = {
    params ["_role", ["_fallbackAmmoRole", ""]];
    private _launchers = DRO2026_assetRegistry getOrDefault [_role, []];
    private _available = (_launchers findIf {([_x] call DRO2026_fnc_resolveLauncherAmmo) != ""}) >= 0;
    if (!_available && {_fallbackAmmoRole != ""}) then {
        _available = count (DRO2026_ammoRegistry getOrDefault [_fallbackAmmoRole, []]) > 0;
    };
    _available
};

if ("UAV" in _categories) then {
    private _fpvRole = format ["FPV_%1", _sideSuffix];
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["FPV_CLASS_AUTO:%1", _x], _x, format ["FPV — %1 (авто)", _name], "Удар только по свежему подтверждённому контакту.", 4] call _add;
        ["UAV", format ["FPV_CLASS_MANUAL:%1", _x], _x, format ["FPV — %1 (ручное управление)", _name], "После запуска появится действие подключения к UAV Terminal.", 1] call _add;
    } forEach ([[_fpvRole], true, false] call _roleClasses);

    private _isrClasses = [["PLAYER_ISR_UAV"], true, true] call _roleClasses;
    _isrClasses append ([[format ["ISR_MICRO_%1", _sideSuffix], format ["ISR_TACTICAL_%1", _sideSuffix], format ["ISR_HALE_%1", _sideSuffix]], true, false] call _roleClasses);
    _isrClasses = _isrClasses arrayIntersect _isrClasses;
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["ISR_CLASS:%1", _x], _x, format ["Разведка — %1", _name], "Конкретный БПЛА выбранной стороны; самолётный класс стартует из глубокого тыла.", 1] call _add;
    } forEach _isrClasses;

    private _longRole = format ["LONG_RANGE_%1", _sideSuffix];
    {
        private _name = [_x] call _displayName;
        ["UAV", format ["STRIKE_CLASS:%1", _x], _x, format ["Дальний удар — %1", _name], "Физический ударный аппарат выбранного класса.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
    } forEach ([[_longRole], true, false] call _roleClasses);

    private _profile = {
        params ["_mode", "_label", "_available", ["_maxQuantity", 10]];
        if (_available) then {["UAV", _mode, "", _label, "Профиль использует штатный боеприпас соответствующей пусковой.", _maxQuantity] call _add};
    };
    ["STRIKE_FP1", "Дальний удар — FP-1", [format ["LAUNCHER_FP1_%1", _sideSuffix], "STRIKE_AMMO_FP1"] call _hasUsableLauncher, 10] call _profile;
    ["STRIKE_FP2", "Дальний удар — FP-2", [format ["LAUNCHER_FP2_%1", _sideSuffix], "STRIKE_AMMO_FP2"] call _hasUsableLauncher, 10] call _profile;
    ["STRIKE_BM35", "Дальний удар — BM-35 / Italmas", [format ["LAUNCHER_BM35_%1", _sideSuffix], "STRIKE_AMMO_BM35"] call _hasUsableLauncher, 10] call _profile;
    ["STRIKE_BULAVA", "Дальний удар — Bulava", [format ["LAUNCHER_BULAVA_%1", _sideSuffix], ""] call _hasUsableLauncher, 10] call _profile;
    ["STRIKE_FP5", "Дальний удар — FP-5 Flamingo", playersSide == west && {["LAUNCHER_FP5_WEST", "STRIKE_AMMO_FP5"] call _hasUsableLauncher}, 1] call _profile;
    if (count (DRO2026_assetRegistry getOrDefault [_longRole, []]) > 0) then {
        ["UAV", "STRIKE_AUTO", "", "Дальний удар — смешанный пакет", "Автоматический выбор из доступного пула выбранной стороны.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
        ["UAV", "STRIKE_DECOY", "", "Дальний запуск — БПЛА-обманки", "Провоцирует работу ПВО и занимает каналы сопровождения.", DRO2026_MAX_DRONES_PER_SALVO] call _add;
    };
};

if ("ARTY" in _categories) then {
    {
        private _name = [_x] call _displayName;
        ["ARTY", format ["ARTY:%1", _x], _x, format ["Артиллерия — %1", _name], "Физическая система применяет только штатные артиллерийские магазины.", 10] call _add;
    } forEach ([["PLAYER_ARTILLERY_MORTAR", "PLAYER_ARTILLERY_SPG", "PLAYER_ARTILLERY_MLRS"], false, true] call _roleClasses);
};

if ("CAS" in _categories) then {
    {
        private _name = [_x] call _displayName;
        ["CAS", format ["AIR:%1", _x], _x, format ["Авиация — %1", _name], "Самолёт или вертолёт использует штатное вооружение по подтверждённой цели.", 2] call _add;
    } forEach ([["PLAYER_CAS_AIR"], true, true] call _roleClasses);
};

missionNamespace setVariable ["DRO2026_supportCatalog", _catalog, true];
missionNamespace setVariable ["DRO2026_supportCatalogReady", true, true];
missionNamespace setVariable ["DRO2026_supportCatalogVersion", (missionNamespace getVariable ["DRO2026_supportCatalogVersion", 0]) + 1, true];
[format ["Каталог поддержки опубликован: записей %1, категории %2", count _catalog, _categories]] call DRO2026_fnc_log;
_catalog
