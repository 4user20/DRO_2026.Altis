if (!isServer) exitWith {};
private _previousOnline=false;
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    [] call DRO2026_fnc_readAIResponses;
    private _lastSeen = missionNamespace getVariable ["DRO2026_aiLastBridgeSeen",-1];
    private _online=_lastSeen >= 0 && {(diag_tickTime-_lastSeen)<30};
    missionNamespace setVariable ["DRO2026_aiBridgeOnline",_online,true];
    if (_online != _previousOnline) then {
        [if (_online) then {"AI_BACKEND_ONLINE"} else {"AI_BACKEND_OFFLINE"},createHashMap,"AI"] call DRO2026_fnc_emitEvent;
        _previousOnline=_online;
    };
    sleep 0.25;
};
