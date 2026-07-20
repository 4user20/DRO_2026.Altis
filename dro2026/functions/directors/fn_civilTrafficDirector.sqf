if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep (140 + random 110);
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};
    DRO2026_civilTraffic = DRO2026_civilTraffic select {
        private _vehicle = _x getOrDefault ["vehicle", objNull];
        !isNull _vehicle && {alive _vehicle} && {canMove _vehicle}
    };
    if (count DRO2026_civilTraffic >= DRO2026_ACTIVE_CIV_TRAFFIC_LIMIT) then {continue};

    [] call DRO2026_fnc_buildTheaterGraph;
    private _source = [selectRandom ["FRIENDLY_LOGISTICS", "FRIENDLY_REAR", "ENEMY_LOGISTICS"]] call DRO2026_fnc_getTheaterNode;
    private _destination = [selectRandom ["FRIENDLY_REAR", "ENEMY_LOGISTICS", "ENEMY_TACTICAL_REAR"]] call DRO2026_fnc_getTheaterNode;
    if ((_source distance2D _destination) < 4200) then {continue};
    private _sourceRoad = [_source, 1200] call BIS_fnc_nearestRoad;
    private _destinationRoad = [_destination, 1200] call BIS_fnc_nearestRoad;
    if (isNull _sourceRoad || {isNull _destinationRoad}) then {continue};
    _source = getPosATL _sourceRoad;
    _destination = getPosATL _destinationRoad;
    if ((_source distance2D _destination) < 3500) then {continue};
    private _class = ["CIV_TRAFFIC", "C_Offroad_01_F"] call DRO2026_fnc_getRoleClass;
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg || {!(_class isKindOf "LandVehicle")}) then {continue};
    private _vehicle = createVehicle [_class, _source, [], 0, "NONE"];
    if (isNull _vehicle) then {continue};
    _vehicle setDir (_source getDir _destination);
    private _group = createGroup [civilian, true];
    if (isNull _group) then {
        deleteVehicle _vehicle;
        continue;
    };
    private _driver = _group createUnit ["C_man_p_beggar_F_euro", _source, [], 0, "NONE"];
    if (isNull _driver) then {
        deleteVehicle _vehicle;
        deleteGroup _group;
        continue;
    };
    _driver moveInDriver _vehicle;
    if (driver _vehicle != _driver) then {
        if (objectParent _driver == _vehicle) then {
            _vehicle deleteVehicleCrew _driver;
        } else {
            deleteVehicle _driver;
        };
        deleteVehicle _vehicle;
        deleteGroup _group;
        continue;
    };
    _vehicle forceFollowRoad true;
    _group setBehaviourStrong "SAFE";
    _group setCombatMode "BLUE";
    _group setSpeedMode "LIMITED";
    private _waypoint = _group addWaypoint [_destination, 15];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "LIMITED";
    _waypoint setWaypointBehaviour "SAFE";
    DRO2026_civilTraffic pushBack (createHashMapFromArray [["vehicle", _vehicle], ["driver", _driver], ["group", _group], ["source", _source], ["destination", _destination]]);
    [_vehicle, _group, _destination] spawn {
        params ["_vehicle", "_group", "_destination"];
        waitUntil {
            sleep 5;
            !alive _vehicle || {!canMove _vehicle} || {_vehicle distance2D _destination < 75} ||
            {missionNamespace getVariable ["DRO2026_missionEnding", false]}
        };
        if (!isNull _vehicle) then {
            deleteVehicleCrew _vehicle;
            if (alive _vehicle) then {deleteVehicle _vehicle};
        };
        if (!isNull _group) then {deleteGroup _group};
    };
};
