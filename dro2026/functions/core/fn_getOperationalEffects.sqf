params [["_side",enemySide,[east]]];
if !(missionNamespace getVariable ["DRO2026_networkBuilt",false]) exitWith {createHashMapFromArray [
    ["commandFactor",1],["logisticsFactor",1],["radarFactor",1],["strikeFactor",1],
    ["decisionIntervalMultiplier",1],["sensorIntervalMultiplier",1],["dispatchIntervalMultiplier",1]
]};

private _factorFor = {
    params ["_nodeId",["_missing",0,[0]],["_componentKeys",[],[[]]]];
    private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
    if (count _node == 0) exitWith {_missing};
    private _statusFactor = switch (toUpperANSI (_node getOrDefault ["status","ACTIVE"])) do {
        case "ACTIVE": {1};
        case "DEGRADED": {0.68};
        case "DISABLED": {0.12};
        case "DESTROYED": {0};
        case "CANCELLED": {0};
        default {0.35};
    };
    private _components = _node getOrDefault ["components",createHashMap];
    private _componentFactor = 1;
    {
        private _value = (_components getOrDefault [_x,1]) max 0 min 1;
        _componentFactor = _componentFactor min _value;
    } forEach _componentKeys;
    (_statusFactor * _componentFactor) max 0 min 1
};
private _hqId = if (_side == enemySide) then {"NODE_ENEMY_HQ"} else {"NODE_FRIENDLY_HQ"};
private _logId = if (_side == enemySide) then {"NODE_LOGISTICS_01"} else {"NODE_FRIENDLY_LOGISTICS"};
private _aaId = if (_side == enemySide) then {"NODE_AA_LONG_01"} else {"NODE_FRIENDLY_AA_LONG"};
private _ewId = if (_side == enemySide) then {"NODE_EW_01"} else {"NODE_FRIENDLY_DRONES"};
private _strikeId = if (_side == enemySide) then {"NODE_BALLISTIC_01"} else {"NODE_FRIENDLY_DRONES"};
private _farpId = if (_side == enemySide) then {"NODE_FARP_01"} else {"NODE_FRIENDLY_FARP"};

private _command = [_hqId,0.35,["commandLink"]] call _factorFor;
private _logistics = [_logId,0.25,["warehouse","commandLink"]] call _factorFor;
private _radar = [_aaId,0,["radar","commandLink"]] call _factorFor;
private _sensor = [_ewId,0.35,["radar","commandLink"]] call _factorFor;
private _strikeNode = [_strikeId,0,["launcher","commandLink","mobility"]] call _factorFor;
private _farp = [_farpId,0,["warehouse","commandLink"]] call _factorFor;
private _strike = ((_command * 0.40) + (_logistics * 0.20) + (_strikeNode * 0.40)) max 0 min 1;
private _decisionMultiplier = (1 / ((_command max 0.2))) min 4.5;
private _sensorMultiplier = (1 / (((_command * 0.45) + (_sensor * 0.55)) max 0.25)) min 3.5;
private _dispatchMultiplier = (1 / (((_command * 0.25) + (_logistics * 0.75)) max 0.2)) min 4.5;
private _effects = createHashMapFromArray [
    ["side",_side],["commandFactor",_command],["logisticsFactor",_logistics],
    ["radarFactor",_radar],["sensorFactor",_sensor],["strikeNodeFactor",_strikeNode],
    ["strikeFactor",_strike],["farpFactor",_farp],
    ["decisionIntervalMultiplier",_decisionMultiplier],
    ["sensorIntervalMultiplier",_sensorMultiplier],
    ["dispatchIntervalMultiplier",_dispatchMultiplier],
    ["evaluatedAt",time]
];
missionNamespace setVariable [format ["DRO2026_operationalEffects_%1",str _side],_effects];
_effects