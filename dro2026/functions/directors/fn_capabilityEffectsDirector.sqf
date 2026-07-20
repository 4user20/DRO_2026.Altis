if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_capabilityEffectsDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_capabilityEffectsDirectorStarted",true];
private _lastSnapshot = createHashMap;
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _enemy = [enemySide] call DRO2026_fnc_getOperationalEffects;
    private _friendly = [playersSide] call DRO2026_fnc_getOperationalEffects;
    missionNamespace setVariable ["DRO2026_enemyDecisionIntervalMultiplier",_enemy getOrDefault ["decisionIntervalMultiplier",1]];
    missionNamespace setVariable ["DRO2026_enemySensorIntervalMultiplier",_enemy getOrDefault ["sensorIntervalMultiplier",1]];
    missionNamespace setVariable ["DRO2026_enemyDispatchIntervalMultiplier",_enemy getOrDefault ["dispatchIntervalMultiplier",1]];
    missionNamespace setVariable ["DRO2026_friendlyDecisionIntervalMultiplier",_friendly getOrDefault ["decisionIntervalMultiplier",1]];
    missionNamespace setVariable ["DRO2026_friendlyDispatchIntervalMultiplier",_friendly getOrDefault ["dispatchIntervalMultiplier",1]];
    {
        private _edgeId = _x;
        private _edge = DRO2026_networkEdges get _edgeId;
        private _fromId = _edge getOrDefault ["from",""];
        private _from = DRO2026_networkNodes getOrDefault [_fromId,createHashMap];
        private _side = _from getOrDefault ["side",enemySide];
        private _effects = if (_side == enemySide) then {_enemy} else {_friendly};
        private _nominalCapacity = _edge getOrDefault ["nominalCapacity",_edge getOrDefault ["capacity",1]];
        private _nominalTravel = _edge getOrDefault ["nominalTravelTime",_edge getOrDefault ["travelTime",600]];
        _edge set ["nominalCapacity",_nominalCapacity];
        _edge set ["nominalTravelTime",_nominalTravel];
        private _logistics = _effects getOrDefault ["logisticsFactor",1];
        private _command = _effects getOrDefault ["commandFactor",1];
        private _effectiveCapacity = floor (_nominalCapacity * (0.35 + (0.65 * _logistics)));
        _edge set ["capacity",_effectiveCapacity max 1];
        _edge set ["travelTime",_nominalTravel * (1 / (((_logistics * 0.75) + (_command * 0.25)) max 0.2))];
        _edge set ["dispatchFactor",(_logistics * 0.75) + (_command * 0.25)];
        private _fromStatus = toUpperANSI (_from getOrDefault ["status","ACTIVE"]);
        if (_fromStatus in ["DESTROYED","DISABLED","CANCELLED"] || {_logistics <= 0.05}) then {
            _edge set ["status","CLOSED"];
            _edge set ["closedReason","SOURCE_CAPABILITY_LOST"];
        } else {
            if ((_edge getOrDefault ["closedReason",""]) == "SOURCE_CAPABILITY_LOST") then {
                _edge set ["status","OPEN"];
                _edge set ["closedReason",""];
                _edge set ["nextDeliveryAt",time + 90];
            };
        };
        DRO2026_networkEdges set [_edgeId,_edge];
    } forEach keys DRO2026_networkEdges;
    private _snapshot = createHashMapFromArray [
        ["enemyCommand",_enemy getOrDefault ["commandFactor",1]],
        ["enemyLogistics",_enemy getOrDefault ["logisticsFactor",1]],
        ["enemyRadar",_enemy getOrDefault ["radarFactor",1]],
        ["friendlyCommand",_friendly getOrDefault ["commandFactor",1]],
        ["friendlyLogistics",_friendly getOrDefault ["logisticsFactor",1]]
    ];
    if !(_snapshot isEqualTo _lastSnapshot) then {
        ["CAPABILITY_EFFECTS_UPDATED",_snapshot,"OPERATION"] call DRO2026_fnc_emitEvent;
        _lastSnapshot = _snapshot;
    };
    sleep 15;
};