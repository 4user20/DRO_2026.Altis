if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_directorsStarted", false]) exitWith {};
missionNamespace setVariable ["DRO2026_directorsStarted", true];
[] call DRO2026_fnc_initState;
[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_createFriendlyPositions;
[] call DRO2026_fnc_createStrategicInfrastructure;
{
    if ((side _x) == enemySide && {({isPlayer _x} count units _x) == 0}) then {
        [_x] call DRO2026_fnc_registerManagedGroup;
        {private _veh = vehicle _x; if (_veh != _x) then {DRO2026_managedVehicles pushBackUnique _veh}} forEach units _x;
    };
} forEach allGroups;
{private _obj = _x getOrDefault ["object", objNull]; if (!isNull _obj) then {DRO2026_managedVehicles pushBackUnique _obj}} forEach DRO2026_sites;
[] spawn DRO2026_fnc_performanceGovernor;
[] spawn DRO2026_fnc_sensorDirector;
[] spawn DRO2026_fnc_enemyFPVDirector;
[] spawn DRO2026_fnc_enemyISRDirector;
[] spawn DRO2026_fnc_longRangeDroneDirector;
[] spawn DRO2026_fnc_friendlyStrikeDirector;
[] spawn DRO2026_fnc_logisticsDirector;
[] spawn DRO2026_fnc_civilTrafficDirector;
[] spawn DRO2026_fnc_enemyAirDirector;
[] spawn DRO2026_fnc_reactionDirector;
["RADIO_CHECK"] call DRO2026_fnc_hqVoice;
["Директоры современной операции RC3 запущены"] call DRO2026_fnc_log;
