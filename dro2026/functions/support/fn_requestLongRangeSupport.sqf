params ["_position", ["_requestedType", "AUTO"], ["_decoy", false]];
[] call DRO2026_fnc_initState;
if ((time - DRO2026_lastLongSupportRequest) < DRO2026_LONG_SUPPORT_COOLDOWN) exitWith {
    systemChat format ["Штаб: Канал дальнего удара занят. Ожидайте %1 сек.", ceil (DRO2026_LONG_SUPPORT_COOLDOWN - (time - DRO2026_lastLongSupportRequest))];
};
private _costPool = if (_decoy) then {"friendlyDecoyStock"} else {"friendlyLongRangeStock"};
if ((toUpperANSI _requestedType) == "FP5" && {(DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) <= 0}) exitWith {
    systemChat "Штаб: FP-5 для этой миссии больше недоступен.";
};
if ((DRO2026_resources getOrDefault [_costPool, 0]) <= 0) exitWith {
    systemChat (if (_decoy) then {"Штаб: Доступные БПЛА-обманки исчерпаны."} else {"Штаб: Дальние ударные БПЛА израсходованы."});
};
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
if (count _sites == 0) exitWith {systemChat "Штаб: Дальний расчёт БПЛА не отвечает."};
private _site = _sites select 0;
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];

private _contact = objNull;
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.45} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 360} &&
    {((_x getOrDefault ["position", [0,0,0]]) distance2D _position) < 500}
};
if (count _contacts > 0) then {
    _contact = _contacts select 0;
};
if (_contact isEqualType objNull) then {
    private _siteContacts = DRO2026_sites select {
        private _p = _x getOrDefault ["position", []];
        count _p > 1 && {_p distance2D _position < 550} && {(_x getOrDefault ["type", ""]) in ["ENEMY_HQ", "STRATEGIC_DRONE_SITE", "FPV_TEAM", "ARTILLERY_SITE", "AIR_DEFENCE_SITE", "CONVOY", "LOGISTICS_RUN"]}
    };
    if (count _siteContacts > 0) then {
        private _siteRec = _siteContacts select 0;
        _contact = createHashMapFromArray [["owner", "PLAYER"], ["target", _siteRec getOrDefault ["object", objNull]], ["position", _siteRec getOrDefault ["position", _position]], ["confidence", 0.92], ["kind", _siteRec getOrDefault ["type", "ЦЕЛЬ"]], ["lastSeen", time]];
    } else {
        _contact = createHashMapFromArray [["owner", "PLAYER"], ["target", objNull], ["position", _position], ["confidence", 0.76], ["kind", "НАЗНАЧЕННАЯ_ТОЧКА"], ["lastSeen", time]];
    };
};

private _preferFP5 = (toUpperANSI _requestedType) == "FP5";
DRO2026_lastLongSupportRequest = time;
DRO2026_resources set [_costPool, ((DRO2026_resources getOrDefault [_costPool, 0]) - 1) max 0];
if (_preferFP5) then {
    DRO2026_resources set ["friendlyFP5Stock", ((DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) - 1) max 0];
    DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
};
[_origin, _contact, playersSide, _preferFP5, _operator, _requestedType, _decoy] spawn DRO2026_fnc_launchLongRangeStrike;
["ACK", format ["Штаб: %1 запущен по назначенному району.", if (_decoy) then {"БПЛА-обманка"} else {_requestedType}]] call DRO2026_fnc_hqVoice;
