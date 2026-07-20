params ["_position", ["_requestedType", "AUTO"], ["_requester", objNull]];

if (!isServer) exitWith {
    [player, "ISR", [_position, _requestedType]] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
};

[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: разведывательная поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};
if !(_requestedType isEqualType "") exitWith {
    ["Штаб: некорректный профиль разведывательной поддержки.", _requester] call DRO2026_fnc_supportMessage;
};

private _upperType = toUpperANSI _requestedType;
private _exactClass = if ((_upperType find "CLASS:") == 0) then {_requestedType select [6]} else {""};
private _knownTypes = ["AUTO", "MICRO", "RQ7", "MQ4A", "TACTICAL", "HALE"];
if (_exactClass == "" && {!(_upperType in _knownTypes)}) exitWith {
    [format ["Штаб: неизвестный профиль разведки %1.", _requestedType], _requester] call DRO2026_fnc_supportMessage;
};

private _classAllowed = true;
if ((_upperType find "CLASS:") == 0) then {
    private _catalogMode = format ["ISR_CLASS:%1", _exactClass];
    _classAllowed = _exactClass != "" && {
        ((missionNamespace getVariable ["DRO2026_supportCatalog", []]) findIf {
            (_x isEqualType []) &&
            {(_x param [1, ""]) == _catalogMode} &&
            {(_x param [2, ""]) == _exactClass}
        }) >= 0
    };
};
if (!_classAllowed) exitWith {
    [format ["Штаб: разведывательный БПЛА %1 отсутствует в каталоге выбранной фракции.", _exactClass], _requester] call DRO2026_fnc_supportMessage;
};

if ((time - DRO2026_lastISRRequest) < DRO2026_ISR_COOLDOWN) exitWith {
    [format ["Штаб: Разведывательный канал занят. Ожидайте %1 сек.", ceil (DRO2026_ISR_COOLDOWN - (time - DRO2026_lastISRRequest))], _requester] call DRO2026_fnc_supportMessage;
};
if ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) <= 0) exitWith {
    ["Штаб: Резерв разведывательных БПЛА исчерпан.", _requester] call DRO2026_fnc_supportMessage;
};
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _siteId = _x getOrDefault ["id", ""];
        _siteId != "" && {[_siteId] call DRO2026_fnc_isSiteOperational}
    }
};
if (count _sites == 0) exitWith {
    ["Штаб: Союзный расчёт БПЛА не отвечает или площадка недоступна.", _requester] call DRO2026_fnc_supportMessage;
};
private _site = _sites select 0;
private _siteId = _site getOrDefault ["id", ""];
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
DRO2026_resources set ["friendlyISRStock", ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) - 1) max 0];
DRO2026_lastISRRequest = time;
["DRONE_LAUNCH_RESERVED", createHashMapFromArray [
    ["role", "ISR"], ["count", 1], ["requestedType", _requestedType],
    ["siteId", _siteId], ["position", +_position]
], _siteId] call DRO2026_fnc_emitEvent;
[_position, _origin, _operator, _requestedType, _siteId] spawn DRO2026_fnc_launchISR;
private _profileLabel = if (_exactClass != "") then {_exactClass} else {_requestedType};
[
    "ACK",
    format ["Штаб: запрос на разведывательный БПЛА (%1) принят; расчёт выполняет materialization и выход в сектор.", _profileLabel],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;
