params ["_position", ["_requestedType", "AUTO"]];
[] call DRO2026_fnc_initState;
if ((time - DRO2026_lastISRRequest) < DRO2026_ISR_COOLDOWN) exitWith {
    systemChat format ["Штаб: Разведывательный канал занят. Ожидайте %1 сек.", ceil (DRO2026_ISR_COOLDOWN - (time - DRO2026_lastISRRequest))];
};
if ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) <= 0) exitWith {
    systemChat "Штаб: Резерв разведывательных БПЛА исчерпан.";
};
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
if (count _sites == 0) exitWith {systemChat "Штаб: Союзный расчёт БПЛА не отвечает."};
private _site = _sites select 0;
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", getPosATL player];
DRO2026_resources set ["friendlyISRStock", ((DRO2026_resources getOrDefault ["friendlyISRStock", 0]) - 1) max 0];
DRO2026_lastISRRequest = time;
[_position, _origin, _operator, _requestedType] spawn DRO2026_fnc_launchISR;
["ACK", format ["Штаб: Разведывательный БПЛА (%1) направлен в сектор.", _requestedType]] call DRO2026_fnc_hqVoice;
