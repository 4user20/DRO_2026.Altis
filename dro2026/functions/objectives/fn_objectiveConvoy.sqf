params ["_AOIndex"];
[] call DRO2026_fnc_buildTheaterGraph;

// Remove completed, destroyed or orphaned convoy records before enforcing the configured limit.
DRO2026_activeConvoys = DRO2026_activeConvoys select {
    private _vehicles = _x getOrDefault ["vehicles", []];
    private _task = _x getOrDefault ["task", ""];
    (_vehicles findIf {!isNull _x && {alive _x} && {canMove _x}}) >= 0 &&
    {_task == "" || {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0}}
};
if (count DRO2026_activeConvoys >= DRO2026_ACTIVE_CONVOY_LIMIT) exitWith {
    [format ["Лимит активных колонн достигнут: %1", DRO2026_ACTIVE_CONVOY_LIMIT]] call DRO2026_fnc_log;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsRun
};

private _source = ["ENEMY_LOGISTICS"] call DRO2026_fnc_getTheaterNode;
private _destinationKey = selectRandom ["ENEMY_TACTICAL_REAR", "ENEMY_ARTILLERY", "ENEMY_DRONE_FORWARD", "ENEMY_EW"];
private _destination = [_destinationKey] call DRO2026_fnc_getTheaterNode;
if ((_source distance2D _destination) < DRO2026_CONVOY_MIN_ROUTE) then {
    private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", random 360];
    _source = [_destination, DRO2026_CONVOY_MIN_ROUTE, DRO2026_CONVOY_MAX_ROUTE, _axis, 70, true, 1000] call DRO2026_fnc_findStrategicPosition;
};
private _sourceRoad = [_source, 1300] call BIS_fnc_nearestRoad;
private _destinationRoad = [_destination, 1300] call BIS_fnc_nearestRoad;
if (!isNull _sourceRoad) then {_source = getPosATL _sourceRoad};
if (!isNull _destinationRoad) then {_destination = getPosATL _destinationRoad};

private _taskName = format ["D26_CONVOY_%1", floor random 1000000];
private _convoyId = format ["LANE_%1_%2", floor diag_tickTime, floor random 1000000];
private _markerPrefix = format ["D26_CONVOY_ROUTE_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
private _routeMarkers = [_markerPrefix, _source, _destination, _color, "Источник колонны", "Передовой пункт разгрузки"] call DRO2026_fnc_createRouteMarkers;
private _taskMarker = _routeMarkers select 0;

private _sideSuffix = switch (enemySide) do {
    case west: {"WEST"};
    case resistance: {"GUER"};
    default {"EAST"};
};
private _cargoRole = format ["CONVOY_CARGO_%1", _sideSuffix];
private _escortRole = format ["CONVOY_ESCORT_%1", _sideSuffix];
private _cargoFallback = switch (enemySide) do {
    case west: {"B_Truck_01_transport_F"};
    case resistance: {"I_Truck_02_transport_F"};
    default {"O_Truck_03_transport_F"};
};
private _escortFallback = switch (enemySide) do {
    case west: {"B_MRAP_01_hmg_F"};
    case resistance: {"I_MRAP_03_hmg_F"};
    default {"O_MRAP_02_hmg_F"};
};
private _cargoClass = [_cargoRole, _cargoFallback] call DRO2026_fnc_getRoleClass;
private _escortClass = [_escortRole, _escortFallback] call DRO2026_fnc_getRoleClass;
if (!isClass (configFile >> "CfgVehicles" >> _cargoClass)) then {_cargoClass = _cargoFallback};
if (!isClass (configFile >> "CfgVehicles" >> _escortClass)) then {_escortClass = _cargoClass};

private _manifest = switch (_destinationKey) do {
    case "ENEMY_ARTILLERY": {createHashMapFromArray [["enemySupply", 12], ["enemyArtilleryAmmo", 16], ["enemyDroneStock", 1]]};
    case "ENEMY_DRONE_FORWARD": {createHashMapFromArray [["enemySupply", 10], ["enemyArtilleryAmmo", 2], ["enemyDroneStock", 9]]};
    case "ENEMY_EW": {createHashMapFromArray [["enemySupply", 15], ["enemyArtilleryAmmo", 2], ["enemyDroneStock", 3]]};
    default {createHashMapFromArray [["enemySupply", 18], ["enemyArtilleryAmmo", 7], ["enemyDroneStock", 4]]};
};
private _classes = [_escortClass, _cargoClass, _cargoClass, _escortClass];
private _vehicles = [];
private _cargoVehicles = [];
private _convoyGroup = grpNull;
private _direction = _source getDir _destination;

{
    private _spawn = _source getPos [_forEachIndex * 28, _direction + 180];
    private _vehicle = createVehicle [_x, _spawn, [], 0, "NONE"];
    if (!isNull _vehicle) then {
        _vehicle setDir _direction;
        private _crewGroup = enemySide createVehicleCrew _vehicle;
        if (!isNull _crewGroup && {!isNull driver _vehicle}) then {
            _vehicles pushBack _vehicle;
            if (_forEachIndex in [1,2]) then {_cargoVehicles pushBack _vehicle};
            DRO2026_managedVehicles pushBackUnique _vehicle;
            _vehicle forceFollowRoad true;
            _vehicle setConvoySeparation 32;
            if (isNull _convoyGroup) then {
                _convoyGroup = _crewGroup;
            } else {
                if (_crewGroup != _convoyGroup) then {
                    (units _crewGroup) joinSilent _convoyGroup;
                    if (count units _crewGroup == 0) then {deleteGroup _crewGroup};
                };
            };
            _convoyGroup addVehicle _vehicle;
            _vehicle addEventHandler ["Hit", {
                params ["_vehicle"];
                private _group = if (isNull driver _vehicle) then {grpNull} else {group driver _vehicle};
                if (!isNull _group) then {
                    _group setBehaviourStrong "AWARE";
                    _group setCombatMode "YELLOW";
                    _group setSpeedMode "NORMAL";
                };
                DRO2026_alertLevel = (DRO2026_alertLevel + 0.12) min 1;
            }];
        } else {
            deleteVehicleCrew _vehicle;
            deleteVehicle _vehicle;
            if (!isNull _crewGroup) then {deleteGroup _crewGroup};
        };
    };
} forEach _classes;

if (count _cargoVehicles == 0 || {isNull _convoyGroup}) exitWith {
    {deleteVehicleCrew _x; deleteVehicle _x} forEach _vehicles;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsRun
};
[_convoyGroup, false] call DRO2026_fnc_registerManagedGroup;
_convoyGroup setBehaviourStrong "SAFE";
_convoyGroup setCombatMode "YELLOW";
_convoyGroup setSpeedMode "LIMITED";
_convoyGroup setFormation "COLUMN";
{
    if (!isNull driver _x) then {
        (driver _x) disableAI "PATH";
        doStop driver _x;
    };
} forEach _vehicles;

private _distance = _source distance2D _destination;
private _eta = time + ((_distance / 9) max 180);
private _lane = createHashMapFromArray [
    ["schema", 1], ["id", _convoyId], ["source", +_source], ["destination", +_destination],
    ["destinationType", _destinationKey], ["cargo", _manifest], ["status", "EN_ROUTE"],
    ["createdAt", time], ["eta", _eta], ["task", _taskName], ["processed", false]
];
DRO2026_supplyLanes pushBack _lane;

private _convoy = createHashMapFromArray [
    ["schema", 1], ["id", _convoyId], ["type", "SUPPLY_CONVOY"],
    ["vehicles", _vehicles], ["cargo", _cargoVehicles], ["group", _convoyGroup],
    ["source", +_source], ["destination", +_destination], ["task", _taskName], ["lane", _lane]
];
DRO2026_activeConvoys pushBack _convoy;
private _siteExtra = createHashMapFromArray [
    ["convoyId", _convoyId], ["cargo", _cargoVehicles], ["group", _convoyGroup], ["task", _taskName]
];
private _siteRecord = ["CONVOY", _source, _vehicles select 0, _vehicles, _siteExtra] call DRO2026_fnc_createSiteRecord;
if ([_siteRecord, true, ["convoyId"]] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _siteRecord};

private _distanceKm = (_distance / 1000) toFixed 1;
private _title = "Перехватить колонну снабжения";
private _desc = format [
    "Колонна перевозит конкретный груз к узлу %1. Расчётное время прибытия — около %2 минут, маршрут — %3 км. Уничтожение грузовых машин сорвёт передачу боеприпасов, FPV-комплектов и снабжения; уничтожение только эскорта задачу не завершает.",
    _destinationKey, ceil ((_eta - time) / 60), _distanceKm
];
private _meta = createHashMapFromArray [
    ["type", "CONVOY_INTERDICTION"], ["vehicles", _vehicles], ["cargo", _cargoVehicles],
    ["source", _source], ["destination", _destination], ["routeMarkers", _routeMarkers],
    ["convoyId", _convoyId], ["manifest", _manifest]
];
[_taskName, _desc, _title, _taskMarker, "destroy", _source, 0.92, [], _meta] call DRO2026_fnc_createObjectiveRecord;

[_taskName, _vehicles, _cargoVehicles, _convoyGroup, _destination, _routeMarkers, _convoy, _lane, _siteRecord] spawn {
    params ["_task", "_vehicles", "_cargo", "_group", "_destination", "_markers", "_convoy", "_lane", "_siteRecord"];
    private _readyDeadline = time + 180;
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["playersReady", 0] == 1 ||
        {time > _readyDeadline} ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};
    sleep (12 + random 20);
    {
        if (alive _x && {!isNull driver _x}) then {
            (driver _x) enableAI "PATH";
            (driver _x) doFollow leader _group;
        };
    } forEach _vehicles;
    private _waypoint = _group addWaypoint [_destination, 20];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "LIMITED";
    _waypoint setWaypointBehaviour "SAFE";
    _waypoint setWaypointCompletionRadius 70;
    private _lastLeadPosition = [];
    private _stuckTime = 0;
    private _finished = false;
    while {!_finished && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
        sleep 5;
        private _aliveCargo = _cargo select {alive _x && {canMove _x}};
        private _aliveVehicles = _vehicles select {alive _x && {canMove _x}};
        if (count _aliveCargo == 0) then {
            _lane set ["status", "DESTROYED"];
            _lane set ["completedAt", time];
            [_task, "CONVOY_DESTROYED", [["enemySupply", -28], ["enemyDroneStock", -7], ["enemyArtilleryAmmo", -14]]] call DRO2026_fnc_completeObjective;
            _finished = true;
        } else {
            if (count _aliveVehicles == 0) then {
                _lane set ["status", "DESTROYED"];
                _lane set ["completedAt", time];
                [_task, "CONVOY_DESTROYED", [["enemySupply", -24]]] call DRO2026_fnc_completeObjective;
                _finished = true;
            } else {
                private _lead = _aliveVehicles select 0;
                if (count _lastLeadPosition > 1 && {_lead distance2D _lastLeadPosition < 5} && {speed _lead < 3}) then {
                    _stuckTime = _stuckTime + 5
                } else {
                    _stuckTime = 0
                };
                _lastLeadPosition = getPosATL _lead;
                if (_stuckTime > 35 && {!isNull driver _lead}) then {
                    (group driver _lead) move _destination;
                    {if (alive _x && {!isNull driver _x}) then {(driver _x) doMove _destination}} forEach _aliveVehicles;
                    _stuckTime = 0;
                };
                if (_lead distance2D _destination < 120) then {
                    _lane set ["status", "DELIVERED"];
                    _lane set ["completedAt", time];
                    DRO2026_supplyEvents pushBack _lane;
                    [_task, "FAILED", true] spawn BIS_fnc_taskSetState;
                    missionNamespace setVariable [format ["%1Completed", _task], -1, true];
                    _finished = true;
                };
            };
        };
    };

    private _convoyIndex = DRO2026_activeConvoys findIf {(_x getOrDefault ["id", ""]) == (_convoy getOrDefault ["id", "-"])};
    if (_convoyIndex >= 0) then {DRO2026_activeConvoys deleteAt _convoyIndex};
    private _siteIndex = DRO2026_sites findIf {(_x getOrDefault ["convoyId", ""]) == (_convoy getOrDefault ["id", "-"])};
    if (_siteIndex >= 0) then {DRO2026_sites deleteAt _siteIndex};
    {if (_x != "") then {deleteMarker _x}} forEach _markers;
};
[] spawn {
    private _deadline = time + 180;
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {time > _deadline}};
    sleep 8;
    ["CONVOY_TASK"] call DRO2026_fnc_hqVoice;
};
_taskName