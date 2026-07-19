params ["_taskName", ["_voice", "TASK_COMPLETE"], ["_resourceChanges", []]];
if (!isServer) exitWith {};
if ((missionNamespace getVariable [format ["%1Completed", _taskName], 0]) == 1) exitWith {};
missionNamespace setVariable [format ["%1Completed", _taskName], 1, true];
[_taskName, "SUCCEEDED", true] spawn BIS_fnc_taskSetState;

{
    _x params ["_key", "_delta"];
    private _current = DRO2026_resources getOrDefault [_key, 0];
    DRO2026_resources set [_key, (((_current + _delta) max 0) min 100)];
} forEach _resourceChanges;

private _meta = DRO2026_objectiveMeta getOrDefault [_taskName, createHashMap];
private _type = _meta getOrDefault ["type", "UNKNOWN"];
private _nodeId = _meta getOrDefault ["nodeId", ""];
if (_nodeId == "") then {
    _nodeId = switch _type do {
        case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
        case "ARTILLERY_HUNT": {"NODE_ARTILLERY_01"};
        case "EW_HUNT": {"NODE_EW_01"};
        case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "AIR_DEFENCE": {"NODE_AA_LONG_01"};
        case "CUT_REAR": {"NODE_ENEMY_HQ"};
        default {""};
    };
};
if (_nodeId != "" && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
    private _node = DRO2026_networkNodes get _nodeId;
    private _liveRefs = (_node getOrDefault ["physicalRefs", []]) select {!isNull _x && {alive _x}};
    if (count _liveRefs == 0) then {
        _node set ["status", "DESTROYED"];
        _node set ["physicalState", "DESTROYED"];
        _node set ["destroyedAt", time];
    } else {
        _node set ["status", "DEGRADED"];
    };
    _node set ["lastUpdatedAt", time];
    DRO2026_networkNodes set [_nodeId, _node];
};

private _effect = createHashMapFromArray [
    ["task", _taskName], ["type", _type], ["nodeId", _nodeId],
    ["completedAt", time], ["resourceChanges", _resourceChanges]
];
private _effects = DRO2026_operationState getOrDefault ["completedEffects", []];
_effects pushBack _effect;
DRO2026_operationState set ["completedEffects", _effects];
["OBJECTIVE_COMPLETED", _effect, if (_nodeId == "") then {"OPERATION"} else {_nodeId}] call DRO2026_fnc_emitEvent;
[] call DRO2026_fnc_syncNetworkState;
[] call DRO2026_fnc_evaluateOperationPhase;
[_voice] call DRO2026_fnc_hqVoice;
if (DRO2026_AUTO_SAVE && {!isMultiplayer}) then {saveGame};