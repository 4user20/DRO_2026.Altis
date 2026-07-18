params ["_AOIndex"];
[] call DRO2026_fnc_buildTheaterGraph;
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
private _markerPrefix = format ["D26_CONVOY_ROUTE_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
private _routeMarkers = [_markerPrefix, _source, _destination, _color, "Источник колонны", "Передовой пункт разгрузки"] call DRO2026_fnc_createRouteMarkers;
private _taskMarker = _routeMarkers select 0;

private _cargoRole = if (enemySide == west) then {"CONVOY_CARGO_WEST"} else {"CONVOY_CARGO_EAST"};
private _escortRole = if (enemySide == west) then {"CONVOY_ESCORT_WEST"} else {"CONVOY_ESCORT_EAST"};
private _cargoClass = [_cargoRole, if (enemySide == west) then {"B_Truck_01_transport_F"} else {"O_Truck_03_transport_F"}] call DRO2026_fnc_getRoleClass;
private _escortClass = [_escortRole, if (enemySide == west) then {"B_MRAP_01_hmg_F"} else {"O_MRAP_02_hmg_F"}] call DRO2026_fnc_getRoleClass;
if (!isClass (configFile >> "CfgVehicles" >> _escortClass)) then {_escortClass = _cargoClass};
private _classes = [_escortClass, _cargoClass, selectRandom [_cargoClass, _cargoClass], _escortClass];
private _vehicles = [];
private _cargoVehicles = [];
private _convoyGroup = grpNull;
private _dir = _source getDir _destination;

{
    private _spawn = _source getPos [_forEachIndex * 28, _dir + 180];
    private _veh = createVehicle [_x, _spawn, [], 0, "NONE"];
    if (!isNull _veh) then {
        _veh setDir _dir;
        private _crewGroup = enemySide createVehicleCrew _veh;
        _vehicles pushBack _veh;
        if (_forEachIndex in [1,2]) then {_cargoVehicles pushBack _veh};
        DRO2026_managedVehicles pushBackUnique _veh;
        _veh forceFollowRoad true;
        _veh setConvoySeparation 32;
        if (isNull _convoyGroup) then {_convoyGroup = _crewGroup} else {
            if (!isNull _crewGroup && {_crewGroup != _convoyGroup}) then {
                (units _crewGroup) joinSilent _convoyGroup;
                if (count units _crewGroup == 0) then {deleteGroup _crewGroup};
            };
        };
        if (!isNull _convoyGroup) then {_convoyGroup addVehicle _veh};
        _veh addEventHandler ["Hit", {
            params ["_vehicle"];
            private _grp = if (isNull (driver _vehicle)) then {grpNull} else {group driver _vehicle};
            if (!isNull _grp) then {_grp setBehaviourStrong "AWARE"; _grp setCombatMode "YELLOW"; _grp setSpeedMode "NORMAL"};
            DRO2026_alertLevel = (DRO2026_alertLevel + 0.12) min 1;
        }];
    };
} forEach _classes;

if (count _cargoVehicles == 0 || {isNull _convoyGroup}) exitWith {[_AOIndex] call DRO2026_fnc_objectiveLogisticsRun};
[_convoyGroup, false] call DRO2026_fnc_registerManagedGroup;
_convoyGroup setBehaviourStrong "SAFE";
_convoyGroup setCombatMode "YELLOW";
_convoyGroup setSpeedMode "LIMITED";
_convoyGroup setFormation "COLUMN";
{
    if (!isNull (driver _x)) then {
        (driver _x) disableAI "PATH";
        doStop (driver _x);
    };
} forEach _vehicles;

private _convoy = createHashMapFromArray [["type", "SUPPLY_CONVOY"], ["vehicles", _vehicles], ["cargo", _cargoVehicles], ["group", _convoyGroup], ["source", _source], ["destination", _destination], ["task", _taskName]];
DRO2026_activeConvoys pushBack _convoy;
DRO2026_sites pushBack createHashMapFromArray [["type", "CONVOY"], ["position", _source], ["object", _vehicles select 0], ["objects", _vehicles]];

private _distanceKm = ((_source distance2D _destination) / 1000) toFixed 1;
private _title = "Перехватить колонну снабжения";
private _desc = format ["Колонна вышла из тылового узла в точке A и следует к передовому пункту разгрузки в точке B. Длина маршрута — около %1 км. Основные цели — грузовые машины с боеприпасами, горючим, комплектами БПЛА и снабжением для артиллерии; уничтожение только эскорта задачу не завершает. Перехватите колонну на обозначенном коридоре до её прибытия.", _distanceKm];
private _meta = createHashMapFromArray [["type", "CONVOY_INTERDICTION"], ["vehicles", _vehicles], ["cargo", _cargoVehicles], ["source", _source], ["destination", _destination], ["routeMarkers", _routeMarkers]];
[_taskName, _desc, _title, _taskMarker, "destroy", _source, 0.92, [], _meta] call DRO2026_fnc_createObjectiveRecord;

[_taskName, _vehicles, _cargoVehicles, _convoyGroup, _destination, _routeMarkers] spawn {
    params ["_task", "_vehicles", "_cargo", "_group", "_destination", "_markers"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1};
    sleep (12 + random 20);
    {
        if (alive _x && {!isNull (driver _x)}) then {
            (driver _x) enableAI "PATH";
            (driver _x) doFollow (leader _group);
        };
    } forEach _vehicles;
    private _wp = _group addWaypoint [_destination, 20];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointCompletionRadius 70;
    private _lastLeadPos = [];
    private _stuckTime = 0;
    while {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0} do {
        sleep 5;
        private _aliveCargo = _cargo select {alive _x && {canMove _x}};
        if (count _aliveCargo == 0) exitWith {[_task, "CONVOY_DESTROYED", [["enemySupply", -28], ["enemyDroneStock", -7], ["enemyArtilleryAmmo", -14]]] call DRO2026_fnc_completeObjective};
        private _alive = _vehicles select {alive _x && {canMove _x}};
        if (count _alive == 0) exitWith {[_task, "CONVOY_DESTROYED", [["enemySupply", -24]]] call DRO2026_fnc_completeObjective};
        private _lead = _alive select 0;
        if (count _lastLeadPos > 1 && {_lead distance2D _lastLeadPos < 5} && {speed _lead < 3}) then {_stuckTime = _stuckTime + 5} else {_stuckTime = 0};
        _lastLeadPos = getPosATL _lead;
        if (_stuckTime > 35 && {!isNull (driver _lead)}) then {
            (group driver _lead) move _destination;
            {if (alive _x && {!isNull (driver _x)}) then {(driver _x) doMove _destination}} forEach _alive;
            _stuckTime = 0;
        };
        if ((_lead distance2D _destination) < 120) exitWith {
            [_task, "FAILED", true] spawn BIS_fnc_taskSetState;
            missionNamespace setVariable [format ["%1Completed", _task], -1, true];
            DRO2026_resources set ["enemySupply", (((DRO2026_resources getOrDefault ["enemySupply", 0]) + 18) min 100)];
        };
    };
};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 8; ["CONVOY_TASK"] call DRO2026_fnc_hqVoice};
_taskName
