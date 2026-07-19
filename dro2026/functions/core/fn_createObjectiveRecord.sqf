params ["_taskName", "_description", "_title", "_markerName", "_taskType", "_position", ["_reconChance", 0.35], ["_subTasks", []], ["_meta", createHashMap]];
missionNamespace setVariable [format ["%1Completed", _taskName], 0, true];
missionNamespace setVariable [format ["%1_taskType", _taskName], _taskType, true];
allObjectives pushBackUnique _taskName;

private _effectiveReconChance = if ((toUpperANSI _taskName find "D26_") == 0) then {-1} else {_reconChance};
objData pushBack [_taskName, _description, _title, _markerName, _taskType, _position, _effectiveReconChance, _subTasks];

private _emptyMap = createHashMap;
if !(_meta isEqualType _emptyMap) then {_meta = createHashMap};
private _objectiveType = _meta getOrDefault ["type", "UNKNOWN"];
private _nodeId = _meta getOrDefault ["nodeId", ""];
if (_nodeId == "") then {
    _nodeId = switch _objectiveType do {
        case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
        case "LOGISTICS_RUN": {"NODE_LOGISTICS_01"};
        case "CONVOY_INTERDICTION": {"NODE_LOGISTICS_01"};
        case "ARTILLERY_HUNT": {"NODE_ARTILLERY_01"};
        case "EW_HUNT": {"NODE_EW_01"};
        case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "AIR_DEFENCE": {"NODE_AA_LONG_01"};
        case "CUT_REAR": {"NODE_ENEMY_HQ"};
        default {""};
    };
};
_meta set ["schema", 2];
_meta set ["nodeId", _nodeId];
_meta set ["createdAt", time];
_meta set ["effectStatus", "PENDING"];
DRO2026_objectiveMeta set [_taskName, _meta];
if (_nodeId != "" && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
    private _node = DRO2026_networkNodes get _nodeId;
    _node set ["knownByPlayer", "DETECTED"];
    DRO2026_networkNodes set [_nodeId, _node];
};
[format ["Создана задача %1 (%2), effect=%3, node=%4", _title, _taskName, _objectiveType, _nodeId]] call DRO2026_fnc_log;
_taskName