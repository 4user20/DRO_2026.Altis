params ["_position", ["_manualControl", false], ["_quantity", 1], ["_requester", objNull], ["_requestedClass", ""]];

if (!isServer) exitWith {
    [player, "FPV", [_position, _manualControl, _quantity, _requestedClass]] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
};

[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};
private _requestSide = if (!isNull _requester) then {side (group _requester)} else {playersSide};
_quantity = ((round _quantity) max 1) min 4;
if (_manualControl) then {_quantity = 1};

private _role = switch (_requestSide) do {case west: {"FPV_WEST"}; case resistance: {"FPV_GUER"}; default {"FPV_EAST"}};
private _allowedClasses = DRO2026_assetRegistry getOrDefault [_role, []];
if (_requestedClass != "" && {!(_requestedClass in _allowedClasses)}) exitWith {
    [format ["Штаб: FPV-класс %1 не входит в каталог выбранной стороны.", _requestedClass], _requester] call DRO2026_fnc_supportMessage;
};

if ((time - DRO2026_lastFPVRequest) < DRO2026_FPV_COOLDOWN) exitWith {
    [format ["Штаб: FPV-группа готовит следующий запуск. Ожидайте %1 сек.", ceil (DRO2026_FPV_COOLDOWN - (time - DRO2026_lastFPVRequest))], _requester] call DRO2026_fnc_supportMessage;
};
private _stock = DRO2026_resources getOrDefault ["friendlyFPVStock", 0];
private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
private _launchCount = (_quantity min _stock) min _slots;
if (_launchCount <= 0) exitWith {
    ["Штаб: Доступные FPV-аппараты израсходованы либо лимит активных БПЛА достигнут.", _requester] call DRO2026_fnc_supportMessage;
};

private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 210} &&
    {((_x getOrDefault ["positionMean", _x getOrDefault ["position", [0,0,0]]]) distance2D _position) < 320}
};
if (count _contacts == 0) exitWith {
    ["Штаб: В указанном районе нет свежей подтверждённой цели. Сначала получите разведданные.", _requester] call DRO2026_fnc_supportMessage;
};
_contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - (((_x getOrDefault ["positionMean", _x getOrDefault ["position", _position]]) distance2D _position) / 1200))}, "ASCEND"] call BIS_fnc_sortBy;
private _contact = _contacts select 0;
private _targetPosition = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", _position]];
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    } && {
        private _sitePosition = _x getOrDefault ["position", []];
        count _sitePosition > 1 && {_sitePosition distance2D _targetPosition <= 4800}
    }
};
if (count _sites == 0) exitWith {
    ["Штаб: В радиусе действия нет живого союзного расчёта FPV.", _requester] call DRO2026_fnc_supportMessage;
};
_sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPosition}, "ASCEND"] call BIS_fnc_sortBy;
private _site = _sites select 0;
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode];
private _operator = _site getOrDefault ["operator", objNull];

DRO2026_resources set ["friendlyFPVStock", (_stock - _launchCount) max 0];
DRO2026_lastFPVRequest = time;
[_origin, _contact, _operator, _manualControl, _launchCount, _requestSide, _requester, _requestedClass] spawn {
    params ["_origin", "_contact", "_operator", "_manualControl", "_count", "_requestSide", "_requester", "_requestedClass"];
    for "_index" from 0 to (_count - 1) do {
        private _launchOrigin = _origin getPos [4 + random 10, random 360];
        [_launchOrigin, _contact, _requestSide, _operator, _manualControl, _requester, _requestedClass] spawn DRO2026_fnc_launchFPVStrike;
        sleep (1.8 + random 2.4);
    };
};
[
    "ACK",
    if (_manualControl) then {"Штаб: FPV запущен. Управление доступно через действие игрока."} else {format ["Штаб: Цель подтверждена. Расчёт FPV запускает аппаратов: %1.", _launchCount]},
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;
