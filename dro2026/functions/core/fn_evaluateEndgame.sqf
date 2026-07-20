if (!isServer) exitWith {missionNamespace getVariable ["DRO2026_endgameState",createHashMap]};
if !(missionNamespace getVariable ["DRO2026_networkBuilt",false]) exitWith {createHashMapFromArray [["ready",false],["reason","NETWORK_NOT_READY"]]};

private _statusOf = {
    params ["_nodeId"];
    private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
    if (count _node == 0) exitWith {"DESTROYED"};
    toUpperANSI (_node getOrDefault ["status","ACTIVE"])
};
private _disabled = {
    params ["_nodeId"];
    ([_nodeId] call _statusOf) in ["DEGRADED","DISABLED","DESTROYED","CANCELLED"]
};
private _destroyed = {
    params ["_nodeId"];
    ([_nodeId] call _statusOf) in ["DISABLED","DESTROYED","CANCELLED"]
};

private _intelDegraded =
    (["NODE_EW_01"] call _disabled) ||
    {(["NODE_AA_LONG_01"] call _disabled) && {(["NODE_DRONE_REAR_01"] call _disabled)}};
private _strategicDepotLost = ["NODE_LOGISTICS_01"] call _destroyed;
private _strikeThreatSuppressed =
    (["NODE_DRONE_REAR_01"] call _disabled) ||
    {(DRO2026_resources getOrDefault ["enemyLongRangeStock",12]) <= 2};
private _commandSuppressed = ["NODE_ENEMY_HQ"] call _disabled;
private _operationalPressure =
    (["NODE_ARTILLERY_01"] call _disabled) ||
    {(["NODE_FPV_FORWARD_01"] call _disabled)} ||
    {(["NODE_AA_SHORAD_01"] call _disabled)};

private _elapsed = time - (DRO2026_operationState getOrDefault ["startedAt",time]);
private _minimumDuration = missionNamespace getVariable ["DRO2026_MIN_OPERATION_DURATION",3600];
private _durationSatisfied = _elapsed >= _minimumDuration ||
    {missionNamespace getVariable ["DRO2026_ENDGAME_ALLOW_EARLY",false]};
private _conditions = createHashMapFromArray [
    ["intelNetworkDegraded",_intelDegraded],
    ["strategicDepotLost",_strategicDepotLost],
    ["strikeThreatSuppressed",_strikeThreatSuppressed],
    ["commandSuppressed",_commandSuppressed],
    ["operationalPressure",_operationalPressure],
    ["durationSatisfied",_durationSatisfied]
];
private _strategicCount = 0;
{if (_conditions getOrDefault [_x,false]) then {_strategicCount = _strategicCount + 1}} forEach [
    "intelNetworkDegraded","strategicDepotLost","strikeThreatSuppressed","commandSuppressed","operationalPressure"
];
private _ready = _durationSatisfied && {_commandSuppressed} && {_strategicCount >= 4};
private _reason = if (_ready) then {"STRATEGIC_CONDITIONS_MET"} else {
    if (!_durationSatisfied) then {"MINIMUM_OPERATION_DURATION"} else {
        if (!_commandSuppressed) then {"COMMAND_NODE_ACTIVE"} else {"INSUFFICIENT_STRATEGIC_EFFECTS"}
    }
};
private _outcome = if (_ready) then {
    private _health = DRO2026_operationState getOrDefault ["networkHealth",1];
    if (_health <= 0.25 && {_strategicCount >= 5}) then {"FULL_SUCCESS"} else {"PARTIAL_SUCCESS"}
} else {"IN_PROGRESS"};

private _state = createHashMapFromArray [
    ["ready",_ready],["reason",_reason],["outcome",_outcome],
    ["conditions",_conditions],["strategicCount",_strategicCount],
    ["elapsed",_elapsed],["minimumDuration",_minimumDuration],
    ["evaluatedAt",time]
];
missionNamespace setVariable ["DRO2026_endgameState",_state,true];
DRO2026_operationState set ["endgameReady",_ready];
DRO2026_operationState set ["endgameReason",_reason];
DRO2026_operationState set ["endgameOutcome",_outcome];
if (_ready && {!(missionNamespace getVariable ["DRO2026_endgameReadyEmitted",false])}) then {
    missionNamespace setVariable ["DRO2026_endgameReadyEmitted",true,true];
    DRO2026_operationState set ["phase","ENDGAME"];
    ["OBJECTIVE","ENDGAME_READY",_state,"OPERATION"] call DRO2026_fnc_logStructured;
    ["ENDGAME_READY",_state,"OPERATION"] call DRO2026_fnc_emitEvent;
};
_state
