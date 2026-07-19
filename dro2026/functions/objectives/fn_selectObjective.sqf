params ["_AOIndex", ["_allowRepeat", false]];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_buildCapabilityNetwork;
[] call DRO2026_fnc_syncNetworkState;

private _phase = [] call DRO2026_fnc_evaluateOperationPhase;
private _type = [_allowRepeat] call DRO2026_fnc_selectObjectiveOpportunity;
private _opportunity = missionNamespace getVariable ["DRO2026_selectedOpportunity", createHashMap];
private _nodeId = _opportunity getOrDefault ["nodeId", ""];
DRO2026_operationPackageName = format ["%1 · %2", _phase, DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"]];
DRO2026_objectiveQueue = (DRO2026_operationState getOrDefault ["activeOpportunities", []]) apply {_x getOrDefault ["type", ""]};
DRO2026_usedObjectiveTypes pushBackUnique _type;
if (_nodeId != "") then {DRO2026_usedObjectiveNodes pushBackUnique _nodeId};
[format ["State-driven objective: %1; node=%2; phase=%3; opportunities=%4", _type, _nodeId, _phase, DRO2026_objectiveQueue]] call DRO2026_fnc_log;

private _task = switch (_type) do {
    case "LOGISTICS_HUB": {[_AOIndex] call DRO2026_fnc_objectiveLogisticsHub};
    case "LOGISTICS_RUN": {[_AOIndex] call DRO2026_fnc_objectiveLogisticsRun};
    case "ARTILLERY_HUNT": {[_AOIndex] call DRO2026_fnc_objectiveArtilleryHunt};
    case "EW_HUNT": {[_AOIndex] call DRO2026_fnc_objectiveEWHunt};
    case "CONVOY_INTERDICTION": {[_AOIndex] call DRO2026_fnc_objectiveConvoy};
    case "DRONE_SITE": {[_AOIndex] call DRO2026_fnc_objectiveDroneSite};
    case "UAV_TEAM": {[_AOIndex] call DRO2026_fnc_objectiveUAVTeam};
    case "AIR_DEFENCE": {[_AOIndex] call DRO2026_fnc_objectiveAirDefence};
    case "ISR_RECON": {[_AOIndex] call DRO2026_fnc_objectiveISRRecon};
    case "CUT_REAR": {[_AOIndex] call DRO2026_fnc_objectiveCutRear};
    default {[_AOIndex] call DRO2026_fnc_objectiveCutRear};
};
if (isNil "_task" || {!(_task isEqualType "")} || {_task == ""}) then {
    DRO2026_usedObjectiveTypes = DRO2026_usedObjectiveTypes - [_type];
    if (_nodeId != "") then {DRO2026_usedObjectiveNodes = DRO2026_usedObjectiveNodes - [_nodeId]};
    [format ["Objective materialisation failed: %1 node=%2", _type, _nodeId]] call DRO2026_fnc_log;
} else {
    ["OBJECTIVE_EXPOSED", createHashMapFromArray [["type", _type], ["task", _task], ["phase", _phase], ["nodeId", _nodeId]], "OPERATION"] call DRO2026_fnc_emitEvent;
};
_task
