params [["_drone", objNull, [objNull]]];
if (!hasInterface || {isNull _drone}) exitWith {};
private _authorizedUid = _drone getVariable ["DRO2026_authorizedControllerUid", ""];
if (_authorizedUid == "" || {_authorizedUid != getPlayerUID player}) exitWith {};
private _actionId = player addAction [
    "<t color='#80d8ff'>Подключить вызванный FPV к UAV Terminal</t>",
    {
        params ["_targetObject", "_caller", "_actionId", "_arguments"];
        _arguments params ["_uav"];
        if (isNull _uav || {!alive _uav}) exitWith {_caller removeAction _actionId};
        _caller enableUAVConnectability [_uav, true];
        private _connected = _caller connectTerminalToUAV _uav;
        if (!_connected || {getConnectedUAV _caller != _uav}) exitWith {
            systemChat "Штаб: подключение не удалось. Назначьте совместимый UAV Terminal в слот навигации.";
        };
        private _control = UAVControl _uav;
        if (count _control < 2 || {(_control select 0) != _caller}) exitWith {
            systemChat "Штаб: terminal link не подтверждён локальным UAVControl.";
        };
        [netId _uav, getPlayerUID _caller, true] remoteExecCall ["DRO2026_fnc_confirmUAVControl", 2, false];
        _caller action ["UAVTerminalOpen", _caller];
        [_uav, _caller, _actionId] spawn {
            params ["_uav", "_caller", "_actionId"];
            private _deadline = time + 210;
            waitUntil {uiSleep 0.25; isNull _uav || {!alive _uav} || {getConnectedUAV _caller != _uav} || {time > _deadline}};
            if (!isNull _uav) then {[netId _uav, getPlayerUID _caller, false] remoteExecCall ["DRO2026_fnc_confirmUAVControl", 2, false]};
            _caller removeAction _actionId;
        };
    },
    [_drone], 8, false, true, "", "alive _target", 8
];
[_drone, player, _actionId] spawn {
    params ["_drone", "_player", "_actionId"];
    waitUntil {uiSleep 0.5; isNull _drone || {!alive _drone} || {time > (_drone getVariable ["DRO2026_controlOfferExpiry", time + 90])}};
    _player removeAction _actionId;
};
_drone setVariable ["DRO2026_controlOfferExpiry", time + 90];