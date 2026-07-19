if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["DRO2026_supportDialogOpen", false]) exitWith {};
missionNamespace setVariable ["DRO2026_supportDialogOpen", true];

private _parent = findDisplay 46;
if (isNull _parent) exitWith {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]};
private _display = _parent createDisplay "RscDisplayEmpty";
if (isNull _display) exitWith {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]};
_display displayAddEventHandler ["Unload", {missionNamespace setVariable ["DRO2026_supportDialogOpen", false]}];

private _catalog = missionNamespace getVariable ["DRO2026_supportCatalog", []];
if !(_catalog isEqualType []) then {_catalog = []};
_display setVariable ["DRO2026_supportCatalog", _catalog];

private _bg = _display ctrlCreate ["RscText", 9400];
_bg ctrlSetPosition [safeZoneX + safeZoneW * 0.27, safeZoneY + safeZoneH * 0.14, safeZoneW * 0.46, safeZoneH * 0.72];
_bg ctrlSetBackgroundColor [0.02, 0.035, 0.045, 0.96];
_bg ctrlCommit 0;

private _title = _display ctrlCreate ["RscText", 9401];
_title ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.16, safeZoneW * 0.42, safeZoneH * 0.045];
_title ctrlSetText "ШТАБ — КОНКРЕТНЫЙ ВЫБОР ПОДДЕРЖКИ";
_title ctrlSetTextColor [0.82, 0.94, 0.90, 1];
_title ctrlSetFontHeight 0.034;
_title ctrlCommit 0;

private _hint = _display ctrlCreate ["RscText", 9402];
_hint ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.205, safeZoneW * 0.42, safeZoneH * 0.052];
_hint ctrlSetText "Каталог сформирован сервером из фракций, выбранных в лобби. Сначала выберите категорию, затем конкретную систему.";
_hint ctrlSetTextColor [0.70, 0.76, 0.78, 1];
_hint ctrlSetFontHeight 0.023;
_hint ctrlCommit 0;

private _category = _display ctrlCreate ["RscCombo", 9405];
_category ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.265, safeZoneW * 0.42, safeZoneH * 0.042];
{
    _x params ["_label", "_data"];
    private _index = _category lbAdd _label;
    _category lbSetData [_index, _data];
} forEach [["Все доступные средства", "ALL"], ["БПЛА и беспилотные удары", "UAV"], ["Артиллерия", "ARTY"], ["Авиация", "CAS"]];
_category lbSetCurSel 0;
_category ctrlCommit 0;

private _list = _display ctrlCreate ["RscListbox", 9410];
_list ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.318, safeZoneW * 0.42, safeZoneH * 0.355];
_list ctrlCommit 0;

private _qtyLabel = _display ctrlCreate ["RscText", 9420];
_qtyLabel ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.685, safeZoneW * 0.17, safeZoneH * 0.035];
_qtyLabel ctrlSetText "Количество / выстрелы:";
_qtyLabel ctrlCommit 0;
private _qty = _display ctrlCreate ["RscCombo", 9421];
_qty ctrlSetPosition [safeZoneX + safeZoneW * 0.46, safeZoneY + safeZoneH * 0.682, safeZoneW * 0.11, safeZoneH * 0.042];
_qty ctrlCommit 0;

private _populateQuantities = {
    params ["_display", ["_maxQuantity", 1]];
    private _qty = _display displayCtrl 9421;
    lbClear _qty;
    private _values = [1, 2, 3, 5, 10] select {_x <= _maxQuantity};
    if (count _values == 0) then {_values = [1]};
    {
        private _index = _qty lbAdd str _x;
        _qty lbSetValue [_index, _x];
    } forEach _values;
    _qty lbSetCurSel 0;
};
_display setVariable ["DRO2026_populateQuantities", _populateQuantities];

private _populate = {
    params ["_display", ["_filter", "ALL"]];
    private _list = _display displayCtrl 9410;
    lbClear _list;
    private _catalog = _display getVariable ["DRO2026_supportCatalog", []];
    private _shown = 0;
    {
        _x params ["_category", "_mode", "_class", "_label", ["_tooltip", ""], ["_maxQuantity", 1]];
        if (_filter == "ALL" || {_category == _filter}) then {
            private _index = _list lbAdd _label;
            _list lbSetData [_index, _mode];
            _list lbSetValue [_index, _maxQuantity];
            if (_tooltip != "") then {_list lbSetTooltip [_index, format ["%1\nКласс: %2", _tooltip, if (_class == "") then {"профиль пусковой"} else {_class}]]};
            _shown = _shown + 1;
        };
    } forEach _catalog;
    if (_shown == 0) then {
        private _index = _list lbAdd (if (missionNamespace getVariable ["DRO2026_supportCatalogReady", false]) then {"Для этой категории нет совместимых классов выбранной фракции"} else {"Каталог поддержки ещё не получен от сервера"});
        _list lbSetData [_index, ""];
        _list lbSetValue [_index, 1];
    };
    _list lbSetCurSel 0;
    private _max = if (lbSize _list > 0) then {_list lbValue 0} else {1};
    [_display, _max] call (_display getVariable "DRO2026_populateQuantities");
};
_display setVariable ["DRO2026_populate", _populate];
[_display, "ALL"] call _populate;

_category ctrlAddEventHandler ["LBSelChanged", {
    params ["_control", "_index"];
    private _display = ctrlParent _control;
    private _filter = _control lbData _index;
    [_display, _filter] call (_display getVariable "DRO2026_populate");
}];
_list ctrlAddEventHandler ["LBSelChanged", {
    params ["_control", "_index"];
    private _display = ctrlParent _control;
    private _max = if (_index >= 0) then {_control lbValue _index} else {1};
    [_display, _max] call (_display getVariable "DRO2026_populateQuantities");
}];

private _confirm = _display ctrlCreate ["RscButton", 9430];
_confirm ctrlSetPosition [safeZoneX + safeZoneW * 0.29, safeZoneY + safeZoneH * 0.755, safeZoneW * 0.195, safeZoneH * 0.052];
_confirm ctrlSetText "ВЫБРАТЬ ТОЧКУ";
_confirm ctrlCommit 0;
_confirm ctrlAddEventHandler ["ButtonClick", {
    private _display = ctrlParent (_this select 0);
    private _list = _display displayCtrl 9410;
    private _quantityControl = _display displayCtrl 9421;
    private _selected = lbCurSel _list;
    if (_selected < 0) exitWith {};
    private _mode = _list lbData _selected;
    if (_mode == "") exitWith {systemChat "Штаб: выбранная категория не содержит доступных средств."};
    private _quantitySelection = lbCurSel _quantityControl;
    private _count = if (_quantitySelection >= 0) then {_quantityControl lbValue _quantitySelection} else {1};
    _display closeDisplay 1;
    [_mode, _count] call DRO2026_fnc_beginSupportTargeting;
}];

private _cancel = _display ctrlCreate ["RscButton", 9431];
_cancel ctrlSetPosition [safeZoneX + safeZoneW * 0.515, safeZoneY + safeZoneH * 0.755, safeZoneW * 0.195, safeZoneH * 0.052];
_cancel ctrlSetText "ОТМЕНА";
_cancel ctrlCommit 0;
_cancel ctrlAddEventHandler ["ButtonClick", {
    private _display = ctrlParent (_this select 0);
    _display closeDisplay 2;
}];
