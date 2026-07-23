if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_directorsStarted", false]) exitWith {};
missionNamespace setVariable ["DRO2026_directorsStarted", true];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_buildCapabilityNetwork;
[] call DRO2026_fnc_createFriendlyPositions;
[] call DRO2026_fnc_createStrategicInfrastructure;
[] call DRO2026_fnc_createFriendlyLogisticsSite;
[] call DRO2026_fnc_syncNetworkState;
{
    if ((side _x) == enemySide && {({isPlayer _x} count units _x) == 0}) then {
        [_x] call DRO2026_fnc_registerManagedGroup;
        {private _vehicle = vehicle _x; if (_vehicle != _x) then {DRO2026_managedVehicles pushBackUnique _vehicle}} forEach units _x;
    };
} forEach allGroups;
{private _object = _x getOrDefault ["object", objNull]; if (!isNull _object) then {DRO2026_managedVehicles pushBackUnique _object}} forEach DRO2026_sites;

[] spawn DRO2026_fnc_startTelemetry;
["DIRECTOR", "START_BATCH", createHashMapFromArray [["directors", [
    "capabilityEffects", "missileDefence", "pointDefence", "strategicStrike",
    "operation", "airDefence", "performanceGovernor", "sensor", "droneWarfare",
    "enemyFPV", "enemyISR", "longRangeDrone", "friendlyStrike", "logistics",
    "dynamicObjective", "civilTraffic", "civilianIntel", "enemyAir", "reaction"
]]], 1, "DIRECTORS", 0] call DRO2026_fnc_telemetryRecord;

// Effects are authoritative inputs for all other directors; start them before action generation.
[] spawn DRO2026_fnc_capabilityEffectsDirector;
[] spawn DRO2026_fnc_missileDefenceDirector;
[] spawn DRO2026_fnc_pointDefenceDirector;
[] spawn DRO2026_fnc_strategicStrikeDirector;
[] spawn DRO2026_fnc_operationDirector;
[] spawn DRO2026_fnc_airDefenceDirector;
[] spawn DRO2026_fnc_performanceGovernor;
[] spawn DRO2026_fnc_sensorDirector;
[] spawn DRO2026_fnc_droneWarfareDirector;
[] spawn DRO2026_fnc_enemyFPVDirector;
[] spawn DRO2026_fnc_enemyISRDirector;
[] spawn DRO2026_fnc_longRangeDroneDirector;
[] spawn DRO2026_fnc_friendlyStrikeDirector;
[] spawn DRO2026_fnc_logisticsDirector;
[] spawn DRO2026_fnc_dynamicObjectiveDirector;
[] spawn DRO2026_fnc_civilTrafficDirector;
[] spawn DRO2026_fnc_civilianIntelDirector;
[] spawn DRO2026_fnc_enemyAirDirector;
[] spawn DRO2026_fnc_reactionDirector;
["RADIO_CHECK"] call DRO2026_fnc_hqVoice;
[format ["Директоры современной операции %1 запущены; doctrine=%2, strategic warfare active", DRO2026_VERSION, DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"]]] call DRO2026_fnc_log;