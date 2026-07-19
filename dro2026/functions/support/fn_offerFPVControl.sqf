params ["_drone"];
if (!hasInterface || {isNull _drone}) exitWith {};

private _actionId = player addAction [
    "<t color='#80d8ff'>Взять вызванный FPV под управление</t>",
    {
        params ["_targetObject", "_caller", "_actionId", "_arguments"];
        _arguments params ["_uav"];
        if (isNull _uav || {!alive _uav}) exitWith {
            _caller removeAction _actionId;
        };
        private _connected = _caller connectTerminalToUAV _uav;
        if (!_connected) exitWith {
            systemChat "Штаб: подключение не удалось. Установите совместимый UAV Terminal в слот навигации.";
        };
        _uav setVariable ["DRO2026_manualControl", true, true];
        _caller action ["UAVTerminalOpen", _caller];
        systemChat "Штаб: Управление FPV передано оператору. После выхода из терминала автопилот продолжит полёт.";
        [_uav, _caller, _actionId] spawn {
            params ["_uav", "_caller", "_actionId"];
            private _deadline = time + 210;
            waitUntil {
                uiSleep 0.25;
                isNull _uav || {!alive _uav} ||
                {getConnectedUAV _caller != _uav} ||
                {time > _deadline}
            };
            if (!isNull _uav) then {_uav setVariable ["DRO2026_manualControl", false, true]};
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