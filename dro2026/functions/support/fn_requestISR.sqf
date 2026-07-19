params ["_position", ["_requestedType", "AUTO"], ["_requester", objNull]];

if (!isServer) exitWith {
    [player, "ISR", [_position, _requestedType]] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
};

[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: разведывательная поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};

private _upperType = toUpperANSI _requestedType;
if ((_upperType find "CLASS:") == 0) then {
    private _class = _requestedType select [6];
    private _catalogMode = format ["ISR_CLASS:%1", _class];
    private _allowed = (missionNamespace getVariable ["DRO2026_supportCatalog", []]) findIf {
        (_x param [1, ""]) == _catalogMode && {(_x param [2, ""]) == _class}
    };
    if (_allowed < 0) exitWith {
        [format ["Штаб: разведывательный БПЛА %1 отсутствует в каталоге выбранной фракции.", _class], _requester] call DRO2026_fnc_supportMessage;
    };
};

if ((time - DRO2026_lastISRRequest) < DRO2026_ISR_COOLDOWN) exitWith {
    [format ["Штаб: Разведывательный канал занят. Ожидайте %1 сек.", ceil (DRO2026_ISR_COOLDOWN - (time - DRO2026_lastISRRequest))], _requester] call DRO2026_fnc_supportMessage;
};
if ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) <= 0) exitWith {
    ["Штаб: Резерв разведывательных БПЛА исчерпан.", _requester] call DRO2026_fnc_supportMessage;
};
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
if (count _sites == 0) exitWith {
    ["Штаб: Союзный расчёт БПЛА не отвечает.", _requester] call DRO2026_fnc_supportMessage;
};
private _site = _sites select 0;
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
DRO2026_resources set ["friendlyISRStock", ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) - 1) max 0];
DRO2026_lastISRRequest = time;
[_position, _origin, _operator, _requestedType] spawn DRO2026_fnc_launchISR;
[
    "ACK",
    format ["Штаб: Разведывательный БПЛА (%1) направлен в сектор.", if ((_upperType find "CLASS:") == 0) then {_requestedType select [6]} else {_requestedType}],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;
