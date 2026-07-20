params ["_AOIndex"];
if (!isServer) exitWith {""};
[] call DRO2026_fnc_buildTheaterGraph;
[] call DRO2026_fnc_buildCapabilityNetwork;

DRO2026_activeConvoys = DRO2026_activeConvoys select {
    private _vehicles = _x getOrDefault ["vehicles", []];
    private _status = _x getOrDefault ["status", "ACTIVE"];
    _status in ["ACTIVE", "IN_TRANSIT"] && {(_vehicles findIf {!isNull _x && {alive _x} && {canMove _x}}) >= 0}
};
if (count DRO2026_activeConvoys >= DRO2026_ACTIVE_CONVOY_LIMIT) exitWith {
    [format ["Лимит активных колонн достигнут: %1", DRO2026_ACTIVE_CONVOY_LIMIT]] call DRO2026_fnc_log;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsRun
};

private _plans = [
    ["NODE_ARTILLERY_01", "EDGE_LOGISTICS_ARTILLERY", "ARTILLERY_AMMO", 16, "артиллерийские боеприпасы"],
    ["NODE_FPV_FORWARD_01", "EDGE_LOGISTICS_FPV", "FPV_KITS", 8, "FPV-комплекты"],
    ["NODE_DRONE_REAR_01", "EDGE_LOGISTICS_DRONES", "LONG_RANGE_DRONES", 5, "дальние ударные БПЛА"],
    ["NODE_EW_01", "EDGE_LOGISTICS_EW", "EW_BATTERIES", 6, "батареи и ЗИП РЭБ"],
    ["NODE_AA_LONG_01", "EDGE_LOGISTICS_AA_LONG", "AA_MISSILES", 6, "ракеты ПВО"]
];
private _sourceNode = DRO2026_networkNodes getOrDefault ["NODE_LOGISTICS_01", createHashMap];
private _sourceStocks = _sourceNode getOrDefault ["stocks", createHashMap];
_plans = _plans select {
    private _toNode = DRO2026_networkNodes getOrDefault [_x select 0, createHashMap];
    private _edge = DRO2026_networkEdges getOrDefault [_x select 1, createHashMap];
    private _cargoType = _x select 2;
    count _toNode > 0 && {count _edge > 0} &&
    {!((_toNode getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"])} &&
    {(_sourceStocks getOrDefault [_cargoType, 0]) > 0}
};
if (count _plans == 0) exitWith {[_AOIndex] call DRO2026_fnc_objectiveLogisticsRun};
private _plan = selectRandom _plans;
_plan params ["_toNodeId", "_edgeId", "_cargoType", "_requestedAmount", "_cargoLabel"];
private _toNode = DRO2026_networkNodes get _toNodeId;
private _edge = DRO2026_networkEdges get _edgeId;
private _available = _sourceStocks getOrDefault [_cargoType, 0];
private _amount = _requestedAmount min _available;
if (_amount <= 0) exitWith {[_AOIndex] call DRO2026_fnc_objectiveLogisticsRun};
["NODE_LOGISTICS_01", _cargoType, -_amount, "OBJECTIVE_CONVOY_DISPATCH"] call DRO2026_fnc_changeNetworkNodeStock;

private _source = +(_sourceNode getOrDefault ["position", ["ENEMY_LOGISTICS"] call DRO2026_fnc_getTheaterNode]);
private _destination = +(_toNode getOrDefault ["position", _source]);
private _sourceRoad = [_source, 1300] call BIS_fnc_nearestRoad;
private _destinationRoad = [_destination, 1300] call BIS_fnc_nearestRoad;
if (!isNull _sourceRoad) then {_source = getPosATL _sourceRoad};
if (!isNull _destinationRoad) then {_destination = getPosATL _destinationRoad};

private _taskName = format ["D26_CONVOY_%1", floor random 1000000];
private _deliveryId = format ["DELIVERY_TASK_%1_%2", floor diag_tickTime, floor random 1000000];
private _markerPrefix = format ["D26_CONVOY_ROUTE_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
private _routeMarkers = [_markerPrefix, _source, _destination, _color, "Источник поставки", "Узел-получатель"] call DRO2026_fnc_createRouteMarkers;
private _taskMarker = _routeMarkers param [0, ""];

private _sideSuffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _cargoFallback = switch (enemySide) do {case west: {"B_Truck_01_transport_F"}; case resistance: {"I_Truck_02_transport_F"}; default {"O_Truck_03_transport_F"}};
private _escortFallback = switch (enemySide) do {case west: {"B_MRAP_01_hmg_F"}; case resistance: {"I_MRAP_03_hmg_F"}; default {"O_MRAP_02_hmg_F"}};
private _cargoClass = [format ["CONVOY_CARGO_%1", _sideSuffix], _cargoFallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _escortClass = [format ["CONVOY_ESCORT_%1", _sideSuffix], _escortFallback, enemySide] call DRO2026_fnc_getSideRoleClass;
if (_cargoClass == "") then {_cargoClass = _cargoFallback};
if (_escortClass == "") then {_escortClass = _cargoClass};
private _risk = _edge getOrDefault ["risk", 0.12];
private _classes = if (_risk > 0.48) then {[_escortClass, _cargoClass, _cargoClass, _escortClass, _escortClass]} else {[_escortClass, _cargoClass, _cargoClass, _escortClass]};
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
        if (!isNull _crewGroup && {!isNull (driver _vehicle)}) then {
            _vehicles pushBack _vehicle;
            if (_x == _cargoClass) then {_cargoVehicles pushBack _vehicle};
            DRO2026_managedVehicles pushBackUnique _vehicle;
            _vehicle forceFollowRoad true;
            _vehicle setConvoySeparation 32;
            if (isNull _convoyGroup) then {
                _convoyGroup = _crewGroup
            } else {
                if (_crewGroup != _convoyGroup) then {
                    (units _crewGroup) joinSilent _convoyGroup;
                    if (count units _crewGroup == 0) then {deleteGroup _crewGroup};
                };
            };
            _convoyGroup addVehicle _vehicle;
            _vehicle addEventHandler ["Hit", {
                params ["_vehicle"];
                private _group = if (isNull (driver _vehicle)) then {grpNull} else {group (driver _vehicle)};
                if (!isNull _group) then {_group setBehaviourStrong "AWARE"; _group setCombatMode "YELLOW"; _group setSpeedMode "NORMAL"};
                DRO2026_alertLevel = (DRO2026_alertLevel + 0.12) min 1;
            }];
        } else {
            deleteVehicleCrew _vehicle;
            deleteVehicle _vehicle;
            if (!isNull _crewGroup) then {deleteGroup _crewGroup};
        };
    };
} forEach _classes;

private _rollbackMaterialization = {
    {if (!isNull _x) then {deleteVehicleCrew _x; deleteVehicle _x}} forEach _vehicles;
    if (!isNull _convoyGroup) then {deleteGroup _convoyGroup};
    {if (_x != "") then {deleteMarker _x}} forEach _routeMarkers;
    ["NODE_LOGISTICS_01", _cargoType, _amount, "OBJECTIVE_CONVOY_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
};
if (count _cargoVehicles == 0 || {isNull _convoyGroup}) exitWith {
    call _rollbackMaterialization;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsRun
};
[_convoyGroup, false] call DRO2026_fnc_registerManagedGroup;
_convoyGroup setBehaviourStrong "SAFE";
_convoyGroup setCombatMode "YELLOW";
_convoyGroup setSpeedMode "LIMITED";
_convoyGroup setFormation "COLUMN";
{if (!isNull (driver _x)) then {(driver _x) disableAI "PATH"; doStop (driver _x)}} forEach _vehicles;

private _distance = _source distance2D _destination;
private _eta = time + ((_distance / 9) max 180);
private _delivery = createHashMapFromArray [
    ["schema", 2], ["id", _deliveryId], ["edgeId", _edgeId], ["fromNode", "NODE_LOGISTICS_01"], ["toNode", _toNodeId],
    ["source", +_source], ["destination", +_destination], ["cargoType", _cargoType], ["amount", _amount],
    ["cargoLabel", _cargoLabel], ["status", "IN_TRANSIT"], ["physicalState", "ACTIVE"],
    ["vehicles", _vehicles], ["cargoVehicles", _cargoVehicles], ["cargoVehicle", _cargoVehicles select 0], ["group", _convoyGroup],
    ["createdAt", time], ["eta", _eta], ["task", _taskName], ["processed", false]
];
private _convoy = createHashMapFromArray [
    ["schema", 2], ["id", _deliveryId], ["type", "SUPPLY_CONVOY"], ["status", "IN_TRANSIT"],
    ["vehicles", _vehicles], ["group", _convoyGroup], ["delivery", _delivery], ["task", _taskName]
];
private _siteExtra = createHashMapFromArray [
    ["deliveryId", _deliveryId], ["edgeId", _edgeId], ["networkNodeId", _toNodeId], ["cargoType", _cargoType],
    ["amount", _amount], ["cargo", _cargoVehicles], ["group", _convoyGroup], ["task", _taskName], ["virtual", false]
];
private _siteRecord = ["CONVOY", _source, _vehicles select 0, _vehicles, _siteExtra] call DRO2026_fnc_createSiteRecord;
if !([_siteRecord, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    call _rollbackMaterialization;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsRun
};
DRO2026_supplyLanes pushBack _delivery;
DRO2026_activeConvoys pushBack _convoy;
DRO2026_sites pushBack _siteRecord;
["DELIVERY_MATERIALIZED", createHashMapFromArray [["deliveryId", _deliveryId], ["edgeId", _edgeId], ["cargoType", _cargoType], ["amount", _amount]], _deliveryId] call DRO2026_fnc_emitEvent;

private _distanceKm = (_distance / 1000) toFixed 1;
private _title = "Перехватить поставку";
private _desc = format [
    "Колонна перевозит %1 (%2 ед.) к узлу %3. Расчётное время прибытия — около %4 минут, маршрут — %5 км. Уничтожение грузовых машин лишит именно этот узел указанного ресурса; эскорт сам по себе не является целью.",
    _cargoLabel, _amount, _toNodeId, ceil ((_eta - time) / 60), _distanceKm
];
private _meta = createHashMapFromArray [
    ["type", "CONVOY_INTERDICTION"], ["deliveryId", _deliveryId], ["edgeId", _edgeId], ["toNode", _toNodeId],
    ["cargoType", _cargoType], ["amount", _amount], ["vehicles", _vehicles], ["cargo", _cargoVehicles], ["routeMarkers", _routeMarkers]
];
[_taskName, _desc, _title, _taskMarker, "destroy", _source, 0.92, [], _meta] call DRO2026_fnc_createObjectiveRecord;

[_taskName, _vehicles, _cargoVehicles, _convoyGroup, _destination, _routeMarkers, _convoy, _delivery, _siteRecord, _edgeId, _toNodeId, _cargoType, _amount] spawn {
    params ["_task", "_vehicles", "_cargo", "_group", "_destination", "_markers", "_convoy", "_delivery", "_siteRecord", "_edgeId", "_toNodeId", "_cargoType", "_amount"];
    private _cleanup = {
        {
            if (!isNull _x) then {
                deleteVehicleCrew _x;
                if (alive _x) then {deleteVehicle _x};
            };
        } forEach _vehicles;
        if (!isNull _group) then {deleteGroup _group};
        {if (_x != "") then {deleteMarker _x}} forEach _markers;
    };
    private _cancel = {
        if !(_delivery getOrDefault ["processed", false]) then {
            ["NODE_LOGISTICS_01", _cargoType, _amount, "OBJECTIVE_CONVOY_CANCELLED"] call DRO2026_fnc_changeNetworkNodeStock;
            _delivery set ["processed", true];
        };
        _delivery set ["status", "CANCELLED"];
        _delivery set ["physicalState", "DISABLED"];
        _delivery set ["completedAt", time];
        _convoy set ["status", "CANCELLED"];
        _siteRecord set ["status", "DISABLED"];
        _siteRecord set ["disabledAt", time];
        ["DELIVERY_CANCELLED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["cargoType", _cargoType], ["amount", _amount]], _delivery get "id"] call DRO2026_fnc_emitEvent;
        call _cleanup;
    };

    private _readyDeadline = time + 180;
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["playersReady", 0] == 1 ||
        {time > _readyDeadline} ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};
    private _departureAt = time + 12 + random 20;
    waitUntil {sleep 1; time >= _departureAt || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};

    {if (alive _x && {!isNull (driver _x)}) then {(driver _x) enableAI "PATH"; (driver _x) doFollow leader _group}} forEach _vehicles;
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
        if (count _aliveCargo == 0 || {count _aliveVehicles == 0}) then {
            _delivery set ["status", "INTERDICTED"];
            _delivery set ["completedAt", time];
            _delivery set ["physicalState", "DESTROYED"];
            _siteRecord set ["status", "DESTROYED"];
            _siteRecord set ["destroyedAt", time];
            private _edge = DRO2026_networkEdges getOrDefault [_edgeId, createHashMap];
            if (count _edge > 0) then {
                _edge set ["risk", ((_edge getOrDefault ["risk", 0.12]) + 0.28) min 0.95];
                _edge set ["interdictionPressure", (_edge getOrDefault ["interdictionPressure", 0]) + 1];
                _edge set ["nextDeliveryAt", time + ((_edge getOrDefault ["travelTime", 600]) * (1.35 + (_edge getOrDefault ["risk", 0.12])))];
                DRO2026_networkEdges set [_edgeId, _edge];
            };
            ["DELIVERY_INTERDICTED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["toNode", _toNodeId], ["cargoType", _cargoType], ["amount", _amount]], _delivery get "id"] call DRO2026_fnc_emitEvent;
            [_task, "CONVOY_DESTROYED", []] call DRO2026_fnc_completeObjective;
            _finished = true;
        } else {
            private _lead = _aliveVehicles select 0;
            if (count _lastLeadPosition > 1 && {_lead distance2D _lastLeadPosition < 5} && {speed _lead < 3}) then {_stuckTime = _stuckTime + 5} else {_stuckTime = 0};
            _lastLeadPosition = getPosATL _lead;
            if (_stuckTime > 35 && {!isNull (driver _lead)}) then {
                (group (driver _lead)) move _destination;
                {if (alive _x && {!isNull (driver _x)}) then {(driver _x) doMove _destination}} forEach _aliveVehicles;
                _stuckTime = 0;
            };
            if (_lead distance2D _destination < 120) then {
                _delivery set ["status", "DELIVERED"];
                _delivery set ["completedAt", time];
                _delivery set ["physicalState", "COMPLETED"];
                _siteRecord set ["status", "COMPLETED"];
                [_toNodeId, _cargoType, _amount, "OBJECTIVE_CONVOY_DELIVERED"] call DRO2026_fnc_changeNetworkNodeStock;
                _delivery set ["processed", true];
                ["DELIVERY_COMPLETED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["toNode", _toNodeId], ["cargoType", _cargoType], ["amount", _amount]], _delivery get "id"] call DRO2026_fnc_emitEvent;
                [_task, "FAILED", true] spawn BIS_fnc_taskSetState;
                missionNamespace setVariable [format ["%1Completed", _task], -1, true];
                _finished = true;
            };
        };
    };

    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {call _cancel};
    _convoy set ["status", _delivery getOrDefault ["status", "COMPLETED"]];
    {if (_x != "") then {deleteMarker _x}} forEach _markers;
    private _cleanupAt = time + (if ((_delivery getOrDefault ["status", ""]) == "DELIVERED") then {20} else {90});
    waitUntil {sleep 2; time >= _cleanupAt || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    call _cleanup;
};
[] spawn {
    private _deadline = time + 190;
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {time > _deadline} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 8; ["CONVOY_TASK"] call DRO2026_fnc_hqVoice};
};
_taskName
