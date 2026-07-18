if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;
if (missionNamespace getVariable ["DRO2026_supportDialogOpen", false]) exitWith {};
missionNamespace setVariable ["DRO2026_supportDialogOpen", true];

private _sideSuffix = switch (playersSide) do {
    case west: {"WEST"};
    case resistance: {"GUER"};
    default {"EAST"};
};
private _longRole = format ["LONG_RANGE_%1", _sideSuffix];
private _launcherRole = {
    params ["_system"];
    format ["LAUNCHER_%1_%2", _system, _sideSuffix]
};
private _isWest = playersSide == west;

private _parent = findDisplay 46;
if (isNull _parent) exitWith {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]};
private _display = _parent createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]};
_display displayAddEventHandler ["Unload", {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]}];

private _bg = _display ctrlCreate ["RscText", 9400];
_bg ctrlSetPosition [safeZoneX + safeZoneW * 0.30, safeZoneY + safeZoneH * 0.18, safeZoneW * 0.40, safeZoneH * 0.64];
_bg ctrlSetBackgroundColor [0.02, 0.035, 0.045, 0.94];
_bg ctrlCommit 0;

private _title = _display ctrlCreate ["RscText", 9401];
_title ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.195, safeZoneW * 0.37, safeZoneH * 0.045];
_title ctrlSetText "ШТАБ — ВЫБОР ПОДДЕРЖКИ";
_title ctrlSetTextColor [0.82, 0.94, 0.90, 1];
_title ctrlSetFontHeight 0.035;
_title ctrlCommit 0;

private _hint = _display ctrlCreate ["RscText", 9402];
_hint ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.238, safeZoneW * 0.37, safeZoneH * 0.038];
_hint ctrlSetText "Показаны только средства выбранной стороны. Выберите тип, количество и точку на карте.";
_hint ctrlSetTextColor [0.70, 0.76, 0.78, 1];
_hint ctrlSetFontHeight 0.025;
_hint ctrlCommit 0;

private _list = _display ctrlCreate ["RscListbox", 9410];
_list ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.285, safeZoneW * 0.37, safeZoneH * 0.36];
_list ctrlCommit 0;

private _addRow = {
    params ["_text", "_data", ["_tooltip", ""]];
    private _index = _list lbAdd _text;
    _list lbSetData [_index, _data];
    if (_tooltip != "") then {_list lbSetTooltip [_index, _tooltip]};
    _index
};
private _hasRole = {
    params ["_role"];
    count (DRO2026_assetRegistry getOrDefault [_role, []]) > 0
};
private _hasAmmo = {
    params ["_role"];
    count (DRO2026_ammoRegistry getOrDefault [_role, []]) > 0
};
private _roleContains = {
    params ["_role", "_tokens"];
    ((DRO2026_assetRegistry getOrDefault [_role, []]) findIf {
        private _name = toLowerANSI _x;
        (_tokens findIf {(_name find _x) >= 0}) >= 0
    }) >= 0
};

["FPV — автоматическое наведение", "FPV_AUTO", "Только по свежему подтверждённому контакту."] call _addRow;
["FPV — передача управления игроку", "FPV_MANUAL", "Потребуется UAV Terminal, после запуска появится действие подключения."] call _addRow;
["Разведка — автоматически выбрать БПЛА", "ISR_AUTO"] call _addRow;
if ([format ["ISR_MICRO_%1", _sideSuffix]] call _hasRole) then {
    ["Разведка — микро-БПЛА", "ISR_MICRO"] call _addRow;
};
private _tacticalRole = format ["ISR_TACTICAL_%1", _sideSuffix];
private _haleRole = format ["ISR_HALE_%1", _sideSuffix];
if ([_tacticalRole, ["rq7", "shadow"]] call _roleContains) then {
    ["Разведка — RQ-7 Shadow", "ISR_RQ7"] call _addRow;
} else {
    if ([_tacticalRole] call _hasRole) then {["Разведка — тактический БПЛА", "ISR_RQ7"] call _addRow};
};
if ([_haleRole, ["mq4"]] call _roleContains) then {
    ["Разведка — MQ-4A", "ISR_MQ4A"] call _addRow;
};

private _fp1Launcher = ["FP1"] call _launcherRole;
private _fp2Launcher = ["FP2"] call _launcherRole;
private _bm35Launcher = ["BM35"] call _launcherRole;
private _bulavaLauncher = ["BULAVA"] call _launcherRole;
if ([_fp1Launcher] call _hasRole || {_isWest && {(["STRIKE_AMMO_FP1"] call _hasAmmo)}}) then {
    ["Дальний удар — FP-1", "STRIKE_FP1"] call _addRow;
};
if ([_longRole, ["fp2"]] call _roleContains || {[_fp2Launcher] call _hasRole}) then {
    ["Дальний удар — FP-2", "STRIKE_FP2"] call _addRow;
};
if ([_longRole, ["bm35"]] call _roleContains || {[_bm35Launcher] call _hasRole}) then {
    ["Дальний удар — BM-35 / Italmas", "STRIKE_BM35"] call _addRow;
};
if ([_bulavaLauncher] call _hasRole) then {
    ["Дальний удар — Bulava", "STRIKE_BULAVA"] call _addRow;
};
if (_isWest && {(["LAUNCHER_FP5_WEST"] call _hasRole) || {(["STRIKE_AMMO_FP5"] call _hasAmmo)}}) then {
    ["Дальний удар — FP-5 Flamingo (только одиночный)", "STRIKE_FP5"] call _addRow;
};
if ([_longRole, ["shahed", "geran"]] call _roleContains) then {
    ["Дальний удар — Shahed / Geran", "STRIKE_SHAHED"] call _addRow;
};
if ([_longRole] call _hasRole) then {
    ["Дальний удар — смешанный пакет", "STRIKE_AUTO", "Аппараты выбираются из реально доступного пула стороны."] call _addRow;
    ["Дальний запуск — БПЛА-обманки", "STRIKE_DECOY"] call _addRow;
};

{
    private _role = _x select 0;
    private _prefix = _x select 1;
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        private _name = getText (_cfg >> "displayName");
        if (_name == "") then {_name = _x};
        [format ["%1 — %2", _prefix, _name], format ["ARTY:%1", _x], "Физическая артсистема применяет штатные магазины и боеприпасы."] call _addRow;
    } forEach (DRO2026_assetRegistry getOrDefault [_role, []]);
} forEach [
    ["PLAYER_ARTILLERY_MORTAR", "Артиллерия: миномёт"],
    ["PLAYER_ARTILLERY_SPG", "Артиллерия: САУ"],
    ["PLAYER_ARTILLERY_MLRS", "Артиллерия: РСЗО"]
];

private _airPool = DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []];
{
    private _cfg = configFile >> "CfgVehicles" >> _x;
    private _name = getText (_cfg >> "displayName");
    if (_name == "") then {_name = _x};
    [format ["Авиация — %1", _name], format ["AIR:%1", _x], "Самолёт или вертолёт использует штатное вооружение по подтверждённой физической цели."] call _addRow;
} forEach (_airPool select [0, (count _airPool) min 8]);

if ((lbSize _list) > 0) then {_list lbSetCurSel 0};

private _qtyLabel = _display ctrlCreate ["RscText", 9420];
_qtyLabel ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.662, safeZoneW * 0.15, safeZoneH * 0.035];
_qtyLabel ctrlSetText "Количество / выстрелы:";
_qtyLabel ctrlCommit 0;
private _qty = _display ctrlCreate ["RscCombo", 9421];
_qty ctrlSetPosition [safeZoneX + safeZoneW * 0.47, safeZoneY + safeZoneH * 0.662, safeZoneW * 0.12, safeZoneH * 0.04];
{
    private _index = _qty lbAdd str _x;
    _qty lbSetValue [_index, _x];
} forEach [1, 2, 3, 5, 10];
_qty lbSetCurSel 0;
_qty ctrlCommit 0;

private _confirm = _display ctrlCreate ["RscButton", 9430];
_confirm ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.725, safeZoneW * 0.175, safeZoneH * 0.052];
_confirm ctrlSetText "ВЫБРАТЬ ТОЧКУ";
_confirm ctrlCommit 0;
_confirm ctrlAddEventHandler ["ButtonClick", {
    private _display = ctrlParent (_this select 0);
    private _list = _display displayCtrl 9410;
    private _quantityControl = _display displayCtrl 9421;
    private _selected = lbCurSel _list;
    if (_selected < 0) exitWith {};
    private _mode = _list lbData _selected;
    private _quantitySelection = lbCurSel _quantityControl;
    private _count = if (_quantitySelection >= 0) then {_quantityControl lbValue _quantitySelection} else {1};
    _display closeDisplay 1;
    [_mode, _count] call DRO2026_fnc_beginSupportTargeting;
}];

private _cancel = _display ctrlCreate ["RscButton", 9431];
_cancel ctrlSetPosition [safeZoneX + safeZoneW * 0.51, safeZoneY + safeZoneH * 0.725, safeZoneW * 0.175, safeZoneH * 0.052];
_cancel ctrlSetText "ОТМЕНА";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", {
    private _display = ctrlParent (_this select 0);
    _display closeDisplay 2;
}];
