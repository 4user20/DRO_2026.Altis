params ["_AOIndex", ["_allowRepeat", false]];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;

if (count DRO2026_objectiveQueue == 0) then {
    private _packages = +DRO2026_OPERATION_PACKAGES;
    private _chosen = selectRandom _packages;
    DRO2026_operationPackageName = _chosen select 0;
    DRO2026_objectiveQueue = +(_chosen select 1);
    [format ["Пакет операции: %1 / %2", DRO2026_operationPackageName, DRO2026_objectiveQueue]] call DRO2026_fnc_log;
};

private _type = DRO2026_objectiveQueue deleteAt 0;
if (!_allowRepeat && {_type in DRO2026_usedObjectiveTypes}) then {
    private _available = DRO2026_OPERATION_TYPES - DRO2026_usedObjectiveTypes;
    if (count _available > 0) then {_type = selectRandom _available};
};
DRO2026_usedObjectiveTypes pushBackUnique _type;

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
    default {[_AOIndex] call DRO2026_fnc_objectiveLogisticsHub};
};
_task
