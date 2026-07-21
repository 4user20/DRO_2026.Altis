if (!isServer) exitWith {};
enableDynamicSimulationSystem true;
"Group" setDynamicSimulationDistance DRO2026_GROUP_ACTIVATION_DISTANCE;
"Vehicle" setDynamicSimulationDistance DRO2026_VEHICLE_ACTIVATION_DISTANCE;
"EmptyVehicle" setDynamicSimulationDistance 700;
"Prop" setDynamicSimulationDistance DRO2026_PROP_ACTIVATION_DISTANCE;
"IsMoving" setDynamicSimulationDistanceCoef 1.5;
private _lastTelemetryAt = -999;
private _lastNetworkSyncAt = -999;

while {!DRO2026_missionEnding} do {
    private _fps = diag_fps;
    DRO2026_fpsAverage = (DRO2026_fpsAverage * 0.82) + (_fps * 0.18);
    DRO2026_spawnBudgetFactor = linearConversion [17, 42, DRO2026_fpsAverage, 0.20, 1, true];
    private _heavyPaused = DRO2026_fpsAverage < 16;
    missionNamespace setVariable ["DRO2026_heavySystemsPaused", _heavyPaused];

    DRO2026_managedGroups = DRO2026_managedGroups select {!isNull _x && {count units _x > 0}};
    DRO2026_managedVehicles = DRO2026_managedVehicles select {!isNull _x && {alive _x}};
    DRO2026_activeDrones = DRO2026_activeDrones select {!isNull _x && {alive _x}};
    DRO2026_activeConvoys = DRO2026_activeConvoys select {
        private _vehicles = _x getOrDefault ["vehicles", []];
        private _state = _x getOrDefault ["status", "ACTIVE"];
        _state in ["ACTIVE", "IN_TRANSIT"] && {({!isNull _x && {alive _x}} count _vehicles) > 0}
    };
    DRO2026_civilTraffic = DRO2026_civilTraffic select {
        private _vehicle = _x getOrDefault ["vehicle", objNull];
        !isNull _vehicle && {alive _vehicle}
    };

    // Keep logical site records and their history. Only remove invalid object references.
    {
        private _site = _x;
        private _objects = (_site getOrDefault ["objects", []]) select {!isNull _x};
        _site set ["objects", _objects];
        private _object = _site getOrDefault ["object", objNull];
        if (isNull _object && {count _objects > 0}) then {_site set ["object", _objects select 0]};
        _site set ["lastCompactedAt", time];
    } forEach DRO2026_sites;
    if ((time - _lastNetworkSyncAt) >= 20) then {
        _lastNetworkSyncAt = time;
        [] call DRO2026_fnc_syncNetworkState;
    };

    if (count DRO2026_contacts > 160) then {
        DRO2026_contacts = [DRO2026_contacts, [], {
            private _bda = _x getOrDefault ["bdaState", "DETECTED"];
            private _historyPenalty = if (_bda in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]) then {400} else {0};
            -((_x getOrDefault ["lastSeen", 0]) - _historyPenalty + ((_x getOrDefault ["confidence", 0]) * 120))
        }, "ASCEND"] call BIS_fnc_sortBy;
        private _dropped = DRO2026_contacts select [160];
        {
            if ((_x getOrDefault ["owner", ""]) == "PLAYER") then {
                [_x getOrDefault ["id", ""], [], 0, "", true, 0, ""] remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
            };
        } forEach _dropped;
        DRO2026_contacts resize 160;
    };

    if (DRO2026_fpsAverage < 20) then {
        "Group" setDynamicSimulationDistance 900;
        "Vehicle" setDynamicSimulationDistance 1350;
        "Prop" setDynamicSimulationDistance 220;
    } else {
        if (DRO2026_fpsAverage < 28) then {
            "Group" setDynamicSimulationDistance 1250;
            "Vehicle" setDynamicSimulationDistance 1800;
            "Prop" setDynamicSimulationDistance 320;
        } else {
            "Group" setDynamicSimulationDistance DRO2026_GROUP_ACTIVATION_DISTANCE;
            "Vehicle" setDynamicSimulationDistance DRO2026_VEHICLE_ACTIVATION_DISTANCE;
            "Prop" setDynamicSimulationDistance DRO2026_PROP_ACTIVATION_DISTANCE;
        };
    };

    if ((missionNamespace getVariable ["DRO2026_PERF_TELEMETRY",false]) && {(time - _lastTelemetryAt) >= 60}) then {
        _lastTelemetryAt = time;
        ["PERF","SNAPSHOT",createHashMapFromArray [
            ["fps",diag_fps],["fpsMin",diag_fpsMin],["activeScripts",diag_activeSQFScripts],
            ["allUnits",count allUnits],["vehicles",count vehicles],["groups",count allGroups],
            ["contacts",count DRO2026_contacts],["droneMissions",count DRO2026_activeDrones],
            ["logisticsJobs",count DRO2026_logisticsJobs],["dynamicTasks",count DRO2026_dynamicTasks],
            ["spawnBudgetFactor",DRO2026_spawnBudgetFactor],["heavySystemsPaused",missionNamespace getVariable ["DRO2026_heavySystemsPaused",false]]
        ]] call DRO2026_fnc_logStructured;
    };
    sleep 10;
};