if (!isServer) exitWith {};
while {true} do {
    sleep (140 + random 110);
    DRO2026_civilTraffic = DRO2026_civilTraffic select {
        private _veh = _x getOrDefault ["vehicle", objNull];
        !isNull _veh && {alive _veh} && {canMove _veh}
    };
    if (count DRO2026_civilTraffic >= DRO2026_ACTIVE_CIV_TRAFFIC_LIMIT) then {continue};

    [] call DRO2026_fnc_buildTheaterGraph;
    private _source = [selectRandom ["FRIENDLY_LOGISTICS", "FRIENDLY_REAR", "ENEMY_LOGISTICS"]] call DRO2026_fnc_getTheaterNode;
    private _dest = [selectRandom ["FRIENDLY_REAR", "ENEMY_LOGISTICS", "ENEMY_TACTICAL_REAR"]] call DRO2026_fnc_getTheaterNode;
    if ((_source distance2D _dest) < 4200) then {continue};
    private _sourceRoad = [_source, 1200] call BIS_fnc_nearestRoad;
    private _destRoad = [_dest, 1200] call BIS_fnc_nearestRoad;
    if (isNull _sourceRoad || {isNull _destRoad}) then {continue};
    _source = getPosATL _sourceRoad;
    _dest = getPosATL _destRoad;
    if ((_source distance2D _dest) < 3500) then {continue};
    private _class = ["CIV_TRAFFIC", "C_Offroad_01_F"] call DRO2026_fnc_getRoleClass;
    private _veh = createVehicle [_class, _source, [], 0, "NONE"];
    if (isNull _veh) then {continue};
    private _group = createGroup [civilian, true];
    private _driver = _group createUnit ["C_man_p_beggar_F_euro", _source, [], 0, "NONE"];
    _driver moveInDriver _veh;
    _veh setDir (_source getDir _dest);
    _veh forceFollowRoad true;
    _group setBehaviourStrong "SAFE";
    _group setCombatMode "BLUE";
    _group setSpeedMode "LIMITED";
    private _wp = _group addWaypoint [_dest, 15];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
    DRO2026_civilTraffic pushBack (createHashMapFromArray [["vehicle", _veh], ["driver", _driver], ["group", _group], ["source", _source], ["destination", _dest]]);
    [_veh, _driver, _group, _dest] spawn {
        params ["_veh", "_driver", "_group", "_dest"];
        waitUntil {sleep 10; !alive _veh || {!canMove _veh} || {_veh distance2D _dest < 75}};
        if (alive _driver) then {deleteVehicle _driver};
        if (alive _veh) then {deleteVehicle _veh};
        if (!isNull _group) then {deleteGroup _group};
    };
};
