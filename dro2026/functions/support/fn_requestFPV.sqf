params ["_position"];
[] call DRO2026_fnc_initState;

if ((time - DRO2026_lastFPVRequest) < DRO2026_FPV_COOLDOWN) exitWith {
    systemChat format ["Штаб: FPV-группа готовит следующий аппарат. Ожидайте %1 сек.", ceil (DRO2026_FPV_COOLDOWN - (time - DRO2026_lastFPVRequest))];
};
if ((DRO2026_resources getOrDefault ["friendlyFPVStock", 0]) <= 0) exitWith {
    systemChat "Штаб: Доступные FPV-аппараты израсходованы.";
};

private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 240} &&
    {((_x getOrDefault ["position", [0,0,0]]) distance2D _position) < 260}
};
if (count _contacts == 0) exitWith {
    systemChat "Штаб: В указанном районе нет свежей подтверждённой цели. Сначала получите разведданные.";
};

private _contact = _contacts select 0;
private _bestScore = -1;
{
    private _score = (_x getOrDefault ["confidence", 0]) - (((_x getOrDefault ["position", _position]) distance2D _position) / 1000);
    if (_score > _bestScore) then {_bestScore = _score; _contact = _x};
} forEach _contacts;

private _targetPos = _contact getOrDefault ["position", _position];
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    } && {
        private _sitePos = _x getOrDefault ["position", []];
        count _sitePos > 1 && {_sitePos distance2D _targetPos <= 4800}
    }
};
if (count _sites == 0) exitWith {
    systemChat "Штаб: В радиусе действия нет живого союзного расчёта FPV.";
};
_sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
private _site = _sites select 0;
private _origin = _site getOrDefault ["position", getPosATL player];
private _operator = _site getOrDefault ["operator", objNull];

DRO2026_resources set ["friendlyFPVStock", ((DRO2026_resources getOrDefault ["friendlyFPVStock", 0]) - 1) max 0];
DRO2026_lastFPVRequest = time;
[_origin, _contact, playersSide, _operator] spawn DRO2026_fnc_launchFPVStrike;
["ACK", "Штаб: Цель подтверждена. Расчёт FPV начал работу."] call DRO2026_fnc_hqVoice;
