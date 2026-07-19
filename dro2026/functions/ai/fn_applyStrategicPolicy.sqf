params ["_data"];
if (!isServer || {!(_data isEqualType [])} || {count _data < 13}) exitWith {false};
if ((_data param [0,"",[""]]) != "STRATEGIC_POLICY" || {(_data param [2,"",[""]]) != "READY"}) exitWith {false};
private _sequence=_data param [1,-1,[0]];
private _pending=missionNamespace getVariable ["DRO2026_aiPendingStrategicSequence",-1];
private _pendingAt=missionNamespace getVariable ["DRO2026_aiPendingStrategicAt",-1];
if (_sequence != _pending || {_pendingAt < 0} || {(time-_pendingAt)>90}) exitWith {
    ["AI_DECISION_STALE",createHashMapFromArray [["jobType","STRATEGIC_POLICY"],["sequence",_sequence],["expected",_pending]],"AI"] call DRO2026_fnc_emitEvent;
    false
};
missionNamespace setVariable ["DRO2026_aiPendingStrategicSequence",-1];
missionNamespace setVariable ["DRO2026_aiPendingStrategicAt",-1];
private _mode=toUpperANSI (missionNamespace getVariable ["DRO2026_AI_MODE","OFF"]);
if (_mode == "OBSERVE") exitWith {
    ["AI_STRATEGIC_POLICY_OBSERVED",createHashMapFromArray [["sequence",_sequence],["doctrine",_data param [3,""]],["reasonCode",_data param [12,""]]],"AI"] call DRO2026_fnc_emitEvent;
    true
};
if (_mode != "HYBRID") exitWith {false};
private _doctrine = _data param [3,"",[""]];
if !(_doctrine in ["DRONE_HEAVY","ARTILLERY_HEAVY","DEFENSIVE_NETWORK","MOBILE_RESERVES"]) then {_doctrine = DRO2026_operationState getOrDefault ["doctrine","DRONE_HEAVY"]};
private _policy = createHashMapFromArray [
    ["desiredTempo",((_data param [4,0.5,[0]]) max 0.15) min 0.9],
    ["reconPressure",((_data param [5,0.5,[0]]) max 0) min 1],
    ["strikePressure",((_data param [6,0.5,[0]]) max 0) min 1],
    ["reserveCommitment",((_data param [7,0.45,[0]]) max 0) min 0.85],
    ["logisticsPriority",((_data param [8,0.5,[0]]) max 0) min 1],
    ["recoveryBias",((_data param [9,0.5,[0]]) max 0) min 1],
    ["pauseAfterMajorAttack",round (((_data param [10,60,[0]]) max 30) min 180)],
    ["priorities",(_data param [11,[],[[]]]) select [0,6]],
    ["reasonCode",(_data param [12,"",[""]]) select [0,80]],
    ["expiresAt",time + 480]
];
missionNamespace setVariable ["DRO2026_aiPolicy",_policy];
DRO2026_operationState set ["doctrine",_doctrine];
["AI_STRATEGIC_POLICY_APPLIED",createHashMapFromArray [["doctrine",_doctrine],["desiredTempo",_policy get "desiredTempo"],["reasonCode",_policy get "reasonCode"]],"AI"] call DRO2026_fnc_emitEvent;
true
