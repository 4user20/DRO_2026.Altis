if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;
if (missionNamespace getVariable ["DRO2026_supportDialogOpen", false]) exitWith {};
missionNamespace setVariable ["DRO2026_supportDialogOpen", true];

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
_hint ctrlSetText "Выберите конкретное средство, количество и затем укажите район на карте.";
_hint ctrlSetTextColor [0.70, 0.76, 0.78, 1];
_hint ctrlSetFontHeight 0.025;
_hint ctrlCommit 0;

private _list = _display ctrlCreate ["RscListbox", 9410];
_list ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.285, safeZoneW * 0.37, safeZoneH * 0.36];
_list ctrlCommit 0;

private _addRow = {
    params ["_text", "_data", ["_tooltip", ""]];
    private _idx = _list lbAdd _text;
    _list lbSetData [_idx, _data];
    if (_tooltip != "") then {_list lbSetTooltip [_idx, _tooltip]};
    _idx
};
private _hasRole = {
    params ["_role"];
    count (DRO2026_assetRegistry getOrDefault [_role, []]) > 0
};
private _hasAmmo = {
    params ["_role"];
    count (DRO2026_ammoRegistry getOrDefault [_role, []]) > 0
};

["FPV — автоматическое наведение", "FPV_AUTO", "Только по свежему подтверждённому контакту."] call _addRow;
["FPV — передача управления игроку", "FPV_MANUAL", "После запуска появится действие подключения к терминалу БПЛА."] call _addRow;
["Разведка — автоматически выбрать БПЛА", "ISR_AUTO"] call _addRow;
["Разведка — микро-БПЛА", "ISR_MICRO"] call _addRow;
if (["ISR_TACTICAL_WEST"] call _hasRole) then {["Разведка — RQ-7 / тактический БПЛА", "ISR_RQ7"] call _addRow};
if (["ISR_HALE_WEST"] call _hasRole) then {["Разведка — MQ-4A / высотный БПЛА", "ISR_MQ4A"] call _addRow};

if (["LAUNCHER_FP1_WEST"] call _hasRole || {["STRIKE_AMMO_FP1"] call _hasAmmo}) then {["Дальний удар — FP-1", "STRIKE_FP1"] call _addRow};
if (["LONG_RANGE_WEST"] call _hasRole || {["LAUNCHER_FP2_WEST"] call _hasRole}) then {["Дальний удар — FP-2", "STRIKE_FP2"] call _addRow};
if (["LONG_RANGE_WEST"] call _hasRole || {["LAUNCHER_BM35_WEST"] call _hasRole}) then {["Дальний удар — BM-35 / Italmas", "STRIKE_BM35"] call _addRow};
if (["LAUNCHER_BULAVA_WEST"] call _hasRole) then {["Дальний удар — Bulava", "STRIKE_BULAVA"] call _addRow};
if (["LAUNCHER_FP5_WEST"] call _hasRole || {["STRIKE_AMMO_FP5"] call _hasAmmo}) then {["Дальний удар — FP-5 Flamingo (только одиночный)", "STRIKE_FP5"] call _addRow};
if (((DRO2026_assetRegistry getOrDefault ["LONG_RANGE_WEST", []]) findIf {(toLowerANSI _x find "shahed") >= 0 || {(toLowerANSI _x find "geran") >= 0}}) >= 0) then {["Дальний удар — Shahed / Geran", "STRIKE_SHAHED"] call _addRow};
if (count (DRO2026_assetRegistry getOrDefault ["LONG_RANGE_WEST", []]) > 0) then {["Дальний удар — смешанный пакет", "STRIKE_AUTO", "Каждый аппарат выбирается из доступных FP-2/BM-35/Shahed-подобных классов."] call _addRow};
["Дальний запуск — БПЛА-обманки", "STRIKE_DECOY"] call _addRow;

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

{
    private _cfg = configFile >> "CfgVehicles" >> _x;
    private _name = getText (_cfg >> "displayName");
    if (_name == "") then {_name = _x};
    [format ["Авиация — %1", _name], format ["AIR:%1", _x], "Самолёт или вертолёт использует штатное вооружение по подтверждённым целям."] call _addRow;
} forEach ((DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []]) select [0, (count (DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []])) min 8]);

if ((lbSize _list) > 0) then {_list lbSetCurSel 0};

private _qtyLabel = _display ctrlCreate ["RscText", 9420];
_qtyLabel ctrlSetPosition [safeZoneX + safeZoneW * 0.315, safeZoneY + safeZoneH * 0.662, safeZoneW * 0.15, safeZoneH * 0.035];
_qtyLabel ctrlSetText "Количество / выстрелы:";
_qtyLabel ctrlCommit 0;
private _qty = _display ctrlCreate ["RscCombo", 9421];
_qty ctrlSetPosition [safeZoneX + safeZoneW * 0.47, safeZoneY + safeZoneH * 0.662, safeZoneW * 0.12, safeZoneH * 0.04];
{
    private _idx = _qty lbAdd str _x;
    _qty lbSetValue [_idx, _x];
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
    private _qty = _display displayCtrl 9421;
    private _sel = lbCurSel _list;
    if (_sel < 0) exitWith {};
    private _mode = _list lbData _sel;
    private _qtySel = lbCurSel _qty;
    private _count = if (_qtySel >= 0) then {_qty lbValue _qtySel} else {1};
    _display closeDisplay 1;
    [_mode, _count] call DRO2026_fnc_beginSupportTargeting;
}];

private _cancel = _display ctrlCreate ["RscButton", 9431];
_cancel ctrlSetPosition [safeZoneX + safeZoneW * 0.51, safeZoneY + safeZoneH * 0.725, safeZoneW * 0.175, safeZoneH * 0.052];
_cancel ctrlSetText "ОТМЕНА";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", {private _display = ctrlParent (_this select 0); _display closeDisplay 2;}];
