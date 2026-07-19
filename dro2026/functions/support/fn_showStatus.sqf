params [["_requester", objNull], ["_rendered", ""]];

if (_rendered != "" && {hasInterface}) exitWith {
    hint parseText _rendered;
    ["STATUS_QUERY"] call DRO2026_fnc_hqVoice;
};
if (!isServer) exitWith {
    [player, ""] remoteExecCall ["DRO2026_fnc_showStatus", 2, false];
};
if (isNull _requester && {hasInterface}) then {_requester = player};
if (isNull _requester) exitWith {};

private _aar = [] call DRO2026_fnc_buildAAR;
private _phaseNames = createHashMapFromArray [
    ["RECON", "Разведка"], ["DISRUPTION", "Нарушение сети"],
    ["EXPLOITATION", "Развитие успеха"], ["COUNTERATTACK", "Контратака / выход"]
];
private _statusNames = createHashMapFromArray [
    ["ACTIVE", "боеспособен"], ["DEGRADED", "ограниченно боеспособен"],
    ["RELOCATING", "меняет позицию"], ["DISABLED", "подавлен"], ["DESTROYED", "уничтожен"],
    ["UNKNOWN", "состояние неясно"]
];
private _stockWord = {
    params ["_value", "_nominal"];
    private _ratio = _value / (_nominal max 1);
    if (_ratio <= 0.05) exitWith {"исчерпан"};
    if (_ratio < 0.32) exitWith {"критический дефицит"};
    if (_ratio < 0.68) exitWith {"ограничен"};
    "устойчив"
};
private _nodeLine = {
    params ["_nodeId", "_label", "_cargoType", "_nominal"];
    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
    if (count _node == 0) exitWith {format ["%1: данных нет", _label]};
    private _known = _node getOrDefault ["knownByPlayer", "UNKNOWN"];
    if (_known == "UNKNOWN") exitWith {format ["%1: точное состояние не установлено", _label]};
    private _status = _statusNames getOrDefault [_node getOrDefault ["status", "UNKNOWN"], "состояние неясно"];
    private _stocks = _node getOrDefault ["stocks", createHashMap];
    private _stock = [_stocks getOrDefault [_cargoType, 0], _nominal] call _stockWord;
    format ["%1: %2; запас %3", _label, _status, _stock]
};

private _activeDeliveries = count (DRO2026_supplyLanes select {(_x getOrDefault ["status", ""]) in ["VIRTUAL", "IN_TRANSIT", "EN_ROUTE"]});
private _knownDeliveries = count (DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" && {(_x getOrDefault ["classification", ""]) in ["КОЛОННА", "ЛОГИСТИКА", "ТЕХНИКА"]}
});
private _airWindow = [getPosATL _requester, playersSide] call DRO2026_fnc_getAirWindow;
private _windowText = switch (_airWindow getOrDefault ["state", "CLOSED"]) do {
    case "PERMISSIVE": {"благоприятное"};
    case "CONTESTED": {"оспариваемое"};
    default {"закрытое"};
};
private _networkHealth = _aar getOrDefault ["networkHealth", 1];
private _networkAssessment = if (_networkHealth > 0.78) then {"сеть противника в основном цела"} else {
    if (_networkHealth > 0.52) then {"сеть нарушена, но сохраняет ключевые возможности"} else {
        if (_networkHealth > 0.28) then {"сеть тяжело дезорганизована"} else {"организованная сеть близка к распаду"}
    }
};
private _intelAssessment = if ((_aar getOrDefault ["highQualityIntel", 0]) >= 4) then {"разведывательная картина устойчива"} else {
    if ((_aar getOrDefault ["highQualityIntel", 0]) >= 2) then {"данных достаточно для точечных действий"} else {"разведданные фрагментарны; требуется ISR"}
};
private _reserveAssessment = format [
    "FPV %1 · ISR %2 · дальние БПЛА %3 · артиллерия %4 · авиация %5",
    [DRO2026_resources getOrDefault ["friendlyFPVStock", 0], 18] call _stockWord,
    [DRO2026_resources getOrDefault ["friendlyISRStock", 0], 8] call _stockWord,
    [DRO2026_resources getOrDefault ["friendlyLongRangeStock", 0], 20] call _stockWord,
    [DRO2026_resources getOrDefault ["friendlyArtilleryStock", 0], 18] call _stockWord,
    [DRO2026_resources getOrDefault ["friendlyAirSorties", 0], 4] call _stockWord
];

private _text = format [
    "<t size='1.25' font='RobotoCondensedBold'>ОПЕРАТИВНАЯ СВОДКА</t><br/>" +
    "<t color='#9ed8ff'>Фаза:</t> %1 · <t color='#9ed8ff'>Доктрина противника:</t> %2<br/>" +
    "<t color='#9ed8ff'>Обстановка:</t> %3<br/>" +
    "<t color='#9ed8ff'>Разведка:</t> %4<br/>" +
    "<t color='#9ed8ff'>Воздушное окно:</t> %5<br/><br/>" +
    "<t font='RobotoCondensedBold'>ОЦЕНКА ВОЗМОЖНОСТЕЙ ПРОТИВНИКА</t><br/>" +
    "%6<br/>%7<br/>%8<br/>%9<br/>%10<br/>%11<br/><br/>" +
    "<t font='RobotoCondensedBold'>ЛОГИСТИКА И РЕЗУЛЬТАТЫ</t><br/>" +
    "В пути поставок: %12; обнаружено поставок: %13<br/>" +
    "Перехвачено / доставлено: %14 / %15<br/>" +
    "BDA подтверждено / вероятно: %16 / %17<br/>" +
    "Сохранённая история событий: %18<br/><br/>" +
    "<t font='RobotoCondensedBold'>НАШ РЕЗЕРВ</t><br/>%19<br/>" +
    "<t color='#b9e5ff'>Промежуточная оценка операции: %20</t>",
    _phaseNames getOrDefault [_aar getOrDefault ["phase", "RECON"], _aar getOrDefault ["phase", "RECON"]],
    _aar getOrDefault ["doctrine", "UNKNOWN"],
    _networkAssessment,
    _intelAssessment,
    _windowText,
    ["NODE_LOGISTICS_01", "Логистический узел", "FUEL", 36] call _nodeLine,
    ["NODE_ARTILLERY_01", "Артиллерия", "ARTILLERY_AMMO", 24] call _nodeLine,
    ["NODE_FPV_FORWARD_01", "Передовой FPV-контур", "FPV_KITS", 12] call _nodeLine,
    ["NODE_DRONE_REAR_01", "Дальние БПЛА", "LONG_RANGE_DRONES", 8] call _nodeLine,
    ["NODE_EW_01", "РЭБ", "EW_BATTERIES", 10] call _nodeLine,
    ["NODE_AA_LONG_01", "Дальняя ПВО", "AA_MISSILES", 10] call _nodeLine,
    _activeDeliveries,
    _knownDeliveries,
    _aar getOrDefault ["deliveriesInterdicted", 0],
    _aar getOrDefault ["deliveriesCompleted", 0],
    _aar getOrDefault ["confirmedBDA", 0],
    _aar getOrDefault ["probableBDA", 0],
    count DRO2026_eventLog,
    _reserveAssessment,
    _aar getOrDefault ["score", 0]
];
[objNull, _text] remoteExecCall ["DRO2026_fnc_showStatus", _requester, false];