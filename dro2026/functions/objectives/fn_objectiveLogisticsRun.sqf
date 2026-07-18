params ["_AOIndex"];
[] call DRO2026_fnc_buildTheaterGraph;
private _source = ["ENEMY_LOGISTICS"] call DRO2026_fnc_getTheaterNode;
private _destinationKey = selectRandom ["ENEMY_TACTICAL_REAR", "ENEMY_ARTILLERY", "ENEMY_DRONE_FORWARD", "ENEMY_EW"];
private _destination = [_destinationKey] call DRO2026_fnc_getTheaterNode;
if ((_source distance2D _destination) < DRO2026_CONVOY_MIN_ROUTE) then {
    private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", random 360];
    _source = [_destination, DRO2026_CONVOY_MIN_ROUTE, DRO2026_CONVOY_MAX_ROUTE, _axis, 70, true, 1000] call DRO2026_fnc_findStrategicPosition;
};
private _sourceRoad = [_source, 1000] call BIS_fnc_nearestRoad;
private _destRoad = [_destination, 1000] call BIS_fnc_nearestRoad;
if (!isNull _sourceRoad) then {_source = getPosATL _sourceRoad};
if (!isNull _destRoad) then {_destination = getPosATL _destRoad};
private _taskName = format ["D26_LOGRUN_%1", floor random 1000000];
private _prefix = format ["D26_LOGRUN_ROUTE_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
private _markers = [_prefix, _source, _destination, _color, "Выход транспорта", "Получатель груза"] call DRO2026_fnc_createRouteMarkers;
private _cargoRole = if (enemySide == west) then {"CONVOY_CARGO_WEST"} else {"CONVOY_CARGO_EAST"};
private _truckClass = [_cargoRole, if (enemySide == west) then {"B_Truck_01_ammo_F"} else {"O_Truck_03_ammo_F"}] call DRO2026_fnc_getRoleClass;
private _truck = createVehicle [_truckClass, _source, [], 0, "NONE"];
if (isNull _truck) exitWith {[_AOIndex] call DRO2026_fnc_objectiveLogisticsHub};
private _group = enemySide createVehicleCrew _truck;
_truck setDir (_source getDir _destination);
_truck forceFollowRoad true;
DRO2026_managedVehicles pushBackUnique _truck;
if (!isNull _group) then {
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setBehaviourStrong "SAFE"; _group setCombatMode "YELLOW"; _group setSpeedMode "NORMAL";
    if (!isNull (driver _truck)) then {(driver _truck) disableAI "PATH"; doStop (driver _truck)};
};
DRO2026_sites pushBack createHashMapFromArray [["type", "LOGISTICS_RUN"], ["position", _source], ["object", _truck], ["destination", _destination]];
private _title = "Перехватить отдельный транспорт снабжения";
private _desc = format ["Из точки A к передовой точке B следует отдельная машина снабжения. Такие рейсы менее заметны, чем колонны, но регулярно подвозят боеприпасы, горючее, батареи, комплектующие БПЛА и снабжение для огневых групп. Длина обозначенного маршрута — около %1 км. Остановите машину до разгрузки.", ((_source distance2D _destination) / 1000) toFixed 1];
private _meta = createHashMapFromArray [["type", "LOGISTICS_RUN"], ["vehicle", _truck], ["source", _source], ["destination", _destination], ["routeMarkers", _markers]];
[_taskName, _desc, _title, _markers select 0, "destroy", _source, 0.95, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _truck, _destination, _group] spawn {
    params ["_task", "_truck", "_destination", "_group"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1};
    sleep (15 + random 25);
    if (alive _truck && {!isNull (driver _truck)} && {!isNull _group}) then {
        (driver _truck) enableAI "PATH";
        private _wp = _group addWaypoint [_destination, 15];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCompletionRadius 55;
    };
    waitUntil {sleep 3; !alive _truck || {!canMove _truck} || {_truck distance2D _destination < 80}};
    if (!alive _truck || {!canMove _truck}) then {[_task, "LOGISTICS_DESTROYED", [["enemySupply", -16], ["enemyDroneStock", -3], ["enemyArtilleryAmmo", -7]]] call DRO2026_fnc_completeObjective} else {
        [_task, "FAILED", true] spawn BIS_fnc_taskSetState;
        missionNamespace setVariable [format ["%1Completed", _task], -1, true];
    };
};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 8; ["NEW_TASK", "Штаб: Перехватите отдельную машину снабжения на обозначенном маршруте."] call DRO2026_fnc_hqVoice};
_taskName
