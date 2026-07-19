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
[] call DRO2026_fnc_assignManagedGroupIds;
{private _object = _x getOrDefault ["object", objNull]; if (!isNull _object) then {DRO2026_managedVehicles pushBackUnique _object}} forEach DRO2026_sites;

// AI-aware OODA owns intent proposal and contains deterministic fallback.
[] call DRO2026_fnc_initAITransport;
[] spawn DRO2026_fnc_aiResponseListener;
[] spawn DRO2026_fnc_aiOperationDirector;
[] spawn DRO2026_fnc_strategicAIDirector;
[] spawn DRO2026_fnc_airDefenceDirector;
[] spawn DRO2026_fnc_performanceGovernor;
[] spawn DRO2026_fnc_sensorDirector;
[] spawn DRO2026_fnc_enemyFPVDirector;
[] spawn DRO2026_fnc_enemyISRDirector;
[] spawn DRO2026_fnc_longRangeDroneDirector;
[] spawn DRO2026_fnc_friendlyStrikeDirector;
[] spawn DRO2026_fnc_logisticsDirector;
[] spawn DRO2026_fnc_civilTrafficDirector;
[] spawn DRO2026_fnc_civilianIntelDirector;
[] spawn DRO2026_fnc_enemyAirDirector;
[] spawn DRO2026_fnc_reactionDirector;
["RADIO_CHECK"] call DRO2026_fnc_hqVoice;
[format ["Директоры современной операции %1 запущены; doctrine=%2; aiMode=%3", DRO2026_VERSION, DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"], missionNamespace getVariable ["DRO2026_AI_MODE", "OFF"]]] call DRO2026_fnc_log;
