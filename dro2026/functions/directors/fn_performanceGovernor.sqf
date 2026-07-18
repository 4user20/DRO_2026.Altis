if (!isServer) exitWith {};
enableDynamicSimulationSystem true;
"Group" setDynamicSimulationDistance DRO2026_GROUP_ACTIVATION_DISTANCE;
"Vehicle" setDynamicSimulationDistance DRO2026_VEHICLE_ACTIVATION_DISTANCE;
"EmptyVehicle" setDynamicSimulationDistance 900;
"Prop" setDynamicSimulationDistance DRO2026_PROP_ACTIVATION_DISTANCE;
"IsMoving" setDynamicSimulationDistanceCoef 1.8;

while {true} do {
    private _fps = diag_fps;
    DRO2026_fpsAverage = (DRO2026_fpsAverage * 0.8) + (_fps * 0.2);
    DRO2026_spawnBudgetFactor = linearConversion [18, 45, DRO2026_fpsAverage, 0.35, 1, true];

    DRO2026_managedGroups = DRO2026_managedGroups select {!isNull _x && {count units _x > 0}};
    DRO2026_managedVehicles = DRO2026_managedVehicles select {!isNull _x && {alive _x}};
    DRO2026_activeDrones = DRO2026_activeDrones select {!isNull _x && {alive _x}};
    DRO2026_activeConvoys = DRO2026_activeConvoys select {
        private _vehicles = _x getOrDefault ["vehicles", []];
        ({alive _x} count _vehicles) > 0
    };
    DRO2026_sites = DRO2026_sites select {
        private _object = _x getOrDefault ["object", objNull];
        private _background = _x getOrDefault ["background", false];
        _background || {isNull _object} || {alive _object}
    };
    if (count DRO2026_contacts > 180) then {
        DRO2026_contacts = [DRO2026_contacts, [], {_x getOrDefault ["lastSeen", 0]}, "DESCEND"] call BIS_fnc_sortBy;
        private _dropped = DRO2026_contacts select [180];
        {
            private _marker = _x getOrDefault ["marker", ""];
            if (_marker != "" && {hasInterface}) then {deleteMarkerLocal _marker};
        } forEach _dropped;
        DRO2026_contacts resize 180;
    };

    if (DRO2026_fpsAverage < 22) then {
        "Group" setDynamicSimulationDistance 1250;
        "Vehicle" setDynamicSimulationDistance 1750;
    } else {
        "Group" setDynamicSimulationDistance DRO2026_GROUP_ACTIVATION_DISTANCE;
        "Vehicle" setDynamicSimulationDistance DRO2026_VEHICLE_ACTIVATION_DISTANCE;
    };
    sleep 10;
};
