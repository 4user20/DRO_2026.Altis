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

private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _fallback = switch (enemySide) do {case west: {"B_Truck_01_ammo_F"}; case resistance: {"I_Truck_02_ammo_F"}; default {"O_Truck_03_ammo_F"}};
private _truckClass = [format ["CONVOY_CARGO_%1", _suffix], _fallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _truck = if (_truckClass == "") then {objNull} else {createVehicle [_truckClass, _source, [], 0, "NONE"]};
if (isNull _truck) exitWith {
    {if (_x != "") then {deleteMarker _x}} forEach _markers;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsHub
};
_truck setDir (_source getDir _destination);
private _group = enemySide createVehicleCrew _truck;
if (isNull _group || {isNull (driver _truck)}) exitWith {
    deleteVehicleCrew _truck;
    deleteVehicle _truck;
    if (!isNull _group) then {deleteGroup _group};
    {if (_x != "") then {deleteMarker _x}} forEach _markers;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsHub
};
_truck forceFollowRoad true;
DRO2026_managedVehicles pushBackUnique _truck;
[_group, false] call DRO2026_fnc_registerManagedGroup;
_group setBehaviourStrong "SAFE";
_group setCombatMode "YELLOW";
_group setSpeedMode "NORMAL";
(driver _truck) disableAI "PATH";
doStop (driver _truck);

private _extra = createHashMapFromArray [
    ["destination", _destination], ["group", _group], ["task", _taskName],
    ["virtual", false], ["background", false]
];
private _site = ["LOGISTICS_RUN", _source, _truck, [_truck], _extra] call DRO2026_fnc_createSiteRecord;
if !([_site, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    deleteVehicleCrew _truck;
    deleteVehicle _truck;
    {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
    deleteGroup _group;
    {if (_x != "") then {deleteMarker _x}} forEach _markers;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsHub
};
DRO2026_sites pushBack _site;

private _title = "Перехватить отдельный транспорт снабжения";
private _desc = format ["Из точки A к передовой точке B следует отдельная машина снабжения. Длина обозначенного маршрута — около %1 км. Остановите машину до разгрузки.", ((_source distance2D _destination) / 1000) toFixed 1];
private _meta = createHashMapFromArray [
    ["type", "LOGISTICS_RUN"], ["vehicle", _truck], ["critical", [_truck]],
    ["source", _source], ["destination", _destination], ["routeMarkers", _markers], ["siteId", _site get "id"]
];
[_taskName, _desc, _title, _markers select 0, "destroy", _source, 0.95, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _truck, _destination, _group, _markers, _site] spawn {
    params ["_task", "_truck", "_destination", "_group", "_markers", "_site"];
    private _cleanup = {
        {if (_x != "") then {deleteMarker _x}} forEach _markers;
        if (!isNull _truck) then {
            deleteVehicleCrew _truck;
            if (alive _truck) then {deleteVehicle _truck};
        };
        if (!isNull _group) then {deleteGroup _group};
    };
    private _cancel = {
        _site set ["status", "CANCELLED"];
        _site set ["physicalState", "DISABLED"];
        _site set ["disabledAt", time];
        _site set ["lastUpdatedAt", time];
        call _cleanup;
    };

    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};
    private _departureAt = time + 15 + random 25;
    waitUntil {sleep 1; time >= _departureAt || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};

    if (alive _truck && {!isNull (driver _truck)} && {!isNull _group}) then {
        (driver _truck) enableAI "PATH";
        private _wp = _group addWaypoint [_destination, 15];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCompletionRadius 55;
    };
    waitUntil {
        sleep 3;
        !alive _truck || {!canMove _truck} || {_truck distance2D _destination < 80} ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};

    private _interdicted = !alive _truck || {!canMove _truck};
    if (_interdicted) then {
        [_task, "LOGISTICS_DESTROYED", [["enemySupply", -16], ["enemyDroneStock", -3], ["enemyArtilleryAmmo", -7]]] call DRO2026_fnc_completeObjective;
    } else {
        _site set ["status", "COMPLETED"];
        _site set ["physicalState", "COMPLETED"];
        _site set ["completedAt", time];
        _site set ["lastUpdatedAt", time];
        [_task, "FAILED", true] spawn BIS_fnc_taskSetState;
        missionNamespace setVariable [format ["%1Completed", _task], -1, true];
        ["DELIVERY_COMPLETED", createHashMapFromArray [["task", _task], ["destination", _destination]], _site get "id"] call DRO2026_fnc_emitEvent;
    };

    {if (_x != "") then {deleteMarker _x}} forEach _markers;
    private _cleanupAt = time + (if (_interdicted) then {90} else {20});
    waitUntil {sleep 2; time >= _cleanupAt || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    call _cleanup;
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 8; ["NEW_TASK", "Штаб: Перехватите отдельную машину снабжения на обозначенном маршруте."] call DRO2026_fnc_hqVoice};
};
_taskName
