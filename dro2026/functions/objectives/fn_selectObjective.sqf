params ["_AOIndex", ["_allowRepeat", false]];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_buildCapabilityNetwork;
[] call DRO2026_fnc_syncNetworkState;

private _phase = [] call DRO2026_fnc_evaluateOperationPhase;
private _type = [_allowRepeat] call DRO2026_fnc_selectObjectiveOpportunity;
DRO2026_operationPackageName = format ["%1 · %2", _phase, DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"]];
DRO2026_objectiveQueue = (DRO2026_operationState getOrDefault ["activeOpportunities", []]) apply {_x getOrDefault ["type", ""]};
DRO2026_usedObjectiveTypes pushBackUnique _type;
[format ["State-driven objective: %1; phase=%2; opportunities=%3", _type, _phase, DRO2026_objectiveQueue]] call DRO2026_fnc_log;

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
    default {[_AOIndex] call DRO2026_fnc_objectiveISRRecon};
};
["OBJECTIVE_EXPOSED", createHashMapFromArray [["type", _type], ["task", _task], ["phase", _phase]], "OPERATION"] call DRO2026_fnc_emitEvent;
_task