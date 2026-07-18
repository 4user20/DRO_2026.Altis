if (!isServer) exitWith {};
enableDynamicSimulationSystem true;
"Group" setDynamicSimulationDistance DRO2026_GROUP_ACTIVATION_DISTANCE;
"Vehicle" setDynamicSimulationDistance DRO2026_VEHICLE_ACTIVATION_DISTANCE;
"EmptyVehicle" setDynamicSimulationDistance 700;
"Prop" setDynamicSimulationDistance DRO2026_PROP_ACTIVATION_DISTANCE;
"IsMoving" setDynamicSimulationDistanceCoef 1.5;

while {!DRO2026_missionEnding} do {
    private _fps = diag_fps;
    DRO2026_fpsAverage = (DRO2026_fpsAverage * 0.82) + (_fps * 0.18);
    DRO2026_spawnBudgetFactor = linearConversion [17, 42, DRO2026_fpsAverage, 0.25, 1, true];

    DRO2026_managedGroups = DRO2026_managedGroups select {!isNull _x && {count units _x > 0}};
    DRO2026_managedVehicles = DRO2026_managedVehicles select {!isNull _x && {alive _x}};
    DRO2026_activeDrones = DRO2026_activeDrones select {!isNull _x && {alive _x}};
    DRO2026_activeConvoys = DRO2026_activeConvoys select {
        private _vehicles = _x getOrDefault ["vehicles", []];
        ({alive _x} count _vehicles) > 0
    };
    DRO2026_civilTraffic = DRO2026_civilTraffic select {
        private _vehicle = _x getOrDefault ["vehicle", objNull];
        !isNull _vehicle && {alive _vehicle}
    };
    DRO2026_sites = DRO2026_sites select {
        private _object = _x getOrDefault ["object", objNull];
        private _objects = _x getOrDefault ["objects", []];
        private _operator = _x getOrDefault ["operator", objNull];
        private _hasLivingObject = (!isNull _object && {alive _object}) || {({!isNull _x && {alive _x}} count _objects) > 0} || {!isNull _operator && {alive _operator}};
        _hasLivingObject
    };

    if (count DRO2026_contacts > 120) then {
        DRO2026_contacts = [DRO2026_contacts, [], {_x getOrDefault ["lastSeen", 0]}, "DESCEND"] call BIS_fnc_sortBy;
        private _dropped = DRO2026_contacts select [120];
        {private _marker = _x getOrDefault ["marker", ""]; if (_marker != "" && {hasInterface}) then {deleteMarkerLocal _marker}} forEach _dropped;
        DRO2026_contacts resize 120;
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
    sleep 10;
};
