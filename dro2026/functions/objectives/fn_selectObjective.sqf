params ["_AOIndex", ["_allowRepeat", false]];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_buildCapabilityNetwork;
[] call DRO2026_fnc_syncNetworkState;

private _phase = [] call DRO2026_fnc_evaluateOperationPhase;
DRO2026_operationPackageName = format ["%1 · %2", _phase, DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"]];
private _task = "";
private _selectedType = "";
private _selectedNode = "";
private _maxAttempts = 4;
private _attemptedTypes = [];

for "_attempt" from 1 to _maxAttempts do {
    if (_task != "") exitWith {};
    private _type = [_allowRepeat, _attemptedTypes] call DRO2026_fnc_selectObjectiveOpportunity;
    if (_type == "") exitWith {
        [format ["No objective opportunity remains after %1 local attempts", count _attemptedTypes]] call DRO2026_fnc_log;
    };
    _attemptedTypes pushBackUnique _type;
    private _opportunity = missionNamespace getVariable ["DRO2026_selectedOpportunity", createHashMap];
    private _nodeId = _opportunity getOrDefault ["nodeId", ""];
    DRO2026_objectiveQueue = (DRO2026_operationState getOrDefault ["activeOpportunities", []]) apply {_x getOrDefault ["type", ""]};
    [format ["State-driven objective attempt %1/%2: %3; node=%4; phase=%5", _attempt, _maxAttempts, _type, _nodeId, _phase]] call DRO2026_fnc_log;

    private _candidateTask = switch (_type) do {
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
        default {""};
    };
    if (!isNil "_candidateTask" && {_candidateTask isEqualType ""} && {_candidateTask != ""}) then {
        _task = _candidateTask;
        _selectedType = _type;
        _selectedNode = _nodeId;
        DRO2026_usedObjectiveTypes pushBackUnique _type;
        if (_nodeId != "") then {DRO2026_usedObjectiveNodes pushBackUnique _nodeId};
    } else {
        missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap];
        ["OBJECTIVE_MATERIALIZATION_FAILED", createHashMapFromArray [["type", _type], ["nodeId", _nodeId], ["attempt", _attempt]], "OPERATION"] call DRO2026_fnc_emitEvent;
        [format ["Objective materialisation failed: %1 node=%2; selecting another local candidate", _type, _nodeId]] call DRO2026_fnc_log;
    };
};

if (!isNil "_task" && {_task isEqualType ""} && {_task != ""}) then {
    ["OBJECTIVE_EXPOSED", createHashMapFromArray [["type", _selectedType], ["task", _task], ["phase", _phase], ["nodeId", _selectedNode]], "OPERATION"] call DRO2026_fnc_emitEvent;
} else {
    missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap];
    DRO2026_operationState set ["activeOpportunities", []];
    ["OBJECTIVE_SELECTION_EXHAUSTED", createHashMapFromArray [["AOIndex", _AOIndex], ["attemptedTypes", +_attemptedTypes], ["phase", _phase]], "OPERATION"] call DRO2026_fnc_emitEvent;
    [format ["All deterministic objective adapters failed for AO index %1: %2", _AOIndex, _attemptedTypes joinString ", "]] call DRO2026_fnc_log;
    _task = "";
};
_task
