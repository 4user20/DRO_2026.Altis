if (!isServer) exitWith {};
private _targetStocks = createHashMapFromArray [
    ["ARTILLERY_AMMO", 24], ["FPV_KITS", 12], ["LONG_RANGE_DRONES", 8],
    ["FUEL", 18], ["EW_BATTERIES", 10], ["AA_MISSILES", 10],
    ["RADAR_PARTS", 3], ["BATTERIES", 10], ["INFANTRY_REPLACEMENTS", 24], ["MEDICAL", 12]
];
private _setActiveConvoyStatus = {
    params ["_deliveryId", "_status"];
    private _index = DRO2026_activeConvoys findIf {(_x getOrDefault ["id", ""]) == _deliveryId};
    if (_index >= 0) then {
        private _convoy = DRO2026_activeConvoys select _index;
        _convoy set ["status", _status];
        DRO2026_activeConvoys set [_index, _convoy];
    };
};

while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _now = time;
    private _humanPlayers = allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}};
    [] call DRO2026_fnc_syncNetworkState;

    // Remove old history only; active and recently completed deliveries remain inspectable.
    DRO2026_supplyLanes = DRO2026_supplyLanes select {
        private _status = _x getOrDefault ["status", "UNKNOWN"];
        private _finishedAt = _x getOrDefault ["completedAt", _x getOrDefault ["createdAt", _now]];
        _status in ["VIRTUAL", "IN_TRANSIT", "EN_ROUTE"] || {(_now - _finishedAt) < DRO2026_SUPPLY_EVENT_TTL}
    };
    if (count DRO2026_supplyLanes > DRO2026_MAX_SUPPLY_EVENTS) then {
        DRO2026_supplyLanes deleteRange [0, count DRO2026_supplyLanes - DRO2026_MAX_SUPPLY_EVENTS];
    };

    // Advance deliveries and materialize only when tactically relevant.
    {
        private _delivery = _x;
        private _status = _delivery getOrDefault ["status", "UNKNOWN"];
        if (_status in ["VIRTUAL", "IN_TRANSIT", "EN_ROUTE"]) then {
            private _from = _delivery getOrDefault ["source", [0,0,0]];
            private _to = _delivery getOrDefault ["destination", [0,0,0]];
            private _startedAt = _delivery getOrDefault ["createdAt", _now];
            private _eta = _delivery getOrDefault ["eta", _now + 60];
            private _progress = linearConversion [_startedAt, _eta, _now, 0, 1, true];
            private _current = _from vectorAdd ((_to vectorDiff _from) vectorMultiply _progress);
            _delivery set ["virtualPosition", _current];

            private _physicalState = _delivery getOrDefault ["physicalState", "VIRTUAL"];
            private _edgeId = _delivery getOrDefault ["edgeId", ""];
            private _edge = DRO2026_networkEdges getOrDefault [_edgeId, createHashMap];
            private _detected = (_humanPlayers findIf {_x distance2D _current < 3400}) >= 0;
            private _knownByPlayer = (DRO2026_contacts findIf {
                (_x getOrDefault ["owner", ""]) == "PLAYER" &&
                {(_x getOrDefault ["classification", ""]) in ["КОЛОННА", "ЛОГИСТИКА", "ТЕХНИКА"]} &&
                {(_x getOrDefault ["positionMean", [0,0,0]]) distance2D _current < ((_x getOrDefault ["uncertaintyRadius", 200]) + 700)}
            }) >= 0;

            if (_physicalState == "VIRTUAL" && {(_detected || {_knownByPlayer})} && {count DRO2026_activeConvoys < DRO2026_ACTIVE_CONVOY_LIMIT}) then {
                private _sideSuffix = switch (enemySide) do {case west: {"WEST"}; case resistance: {"GUER"}; default {"EAST"}};
                private _cargoFallback = switch (enemySide) do {case west: {"B_Truck_01_transport_F"}; case resistance: {"I_Truck_02_transport_F"}; default {"O_Truck_03_transport_F"}};
                private _escortFallback = switch (enemySide) do {case west: {"B_MRAP_01_hmg_F"}; case resistance: {"I_MRAP_03_hmg_F"}; default {"O_MRAP_02_hmg_F"}};
                private _cargoClass = [format ["CONVOY_CARGO_%1", _sideSuffix], _cargoFallback] call DRO2026_fnc_getRoleClass;
                private _escortClass = [format ["CONVOY_ESCORT_%1", _sideSuffix], _escortFallback] call DRO2026_fnc_getRoleClass;
                private _road = [_current, 900] call BIS_fnc_nearestRoad;
                private _spawn = if (isNull _road) then {_current} else {getPosATL _road};
                private _direction = _spawn getDir _to;
                private _vehicles = [];
                private _group = grpNull;
                {
                    private _vehicle = createVehicle [_x, _spawn getPos [_forEachIndex * 24, _direction + 180], [], 0, "NONE"];
                    if (!isNull _vehicle) then {
                        _vehicle setDir _direction;
                        private _crew = enemySide createVehicleCrew _vehicle;
                        if (!isNull _crew && {!isNull (driver _vehicle)}) then {
                            if (isNull _group) then {
                                _group = _crew;
                            } else {
                                (units _crew) joinSilent _group;
                                if (count units _crew == 0) then {deleteGroup _crew};
                            };
                            _vehicles pushBack _vehicle;
                            DRO2026_managedVehicles pushBackUnique _vehicle;
                            _vehicle forceFollowRoad true;
                            _vehicle setConvoySeparation 28;
                        } else {
                            deleteVehicleCrew _vehicle;
                            deleteVehicle _vehicle;
                            if (!isNull _crew) then {deleteGroup _crew};
                        };
                    };
                } forEach [_cargoClass, _escortClass];

                if (count _vehicles > 0 && {!isNull _group}) then {
                    [_group, false] call DRO2026_fnc_registerManagedGroup;
                    _group setBehaviourStrong "SAFE";
                    _group setCombatMode "YELLOW";
                    _group setSpeedMode "LIMITED";
                    _group setFormation "COLUMN";
                    private _waypoint = _group addWaypoint [_to, 30];
                    _waypoint setWaypointType "MOVE";
                    _waypoint setWaypointSpeed "LIMITED";
                    _waypoint setWaypointBehaviour "SAFE";
                    _delivery set ["physicalState", "ACTIVE"];
                    _delivery set ["status", "IN_TRANSIT"];
                    _delivery set ["vehicles", _vehicles];
                    _delivery set ["cargoVehicle", _vehicles select 0];
                    _delivery set ["group", _group];
                    private _convoy = createHashMapFromArray [["id", _delivery get "id"], ["status", "IN_TRANSIT"], ["vehicles", _vehicles], ["group", _group], ["delivery", _delivery]];
                    DRO2026_activeConvoys pushBack _convoy;
                    private _extra = createHashMapFromArray [
                        ["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["networkNodeId", _delivery getOrDefault ["toNode", ""]],
                        ["cargoType", _delivery getOrDefault ["cargoType", "UNKNOWN"]], ["amount", _delivery getOrDefault ["amount", 0]], ["virtual", false]
                    ];
                    private _site = ["LOGISTICS_RUN", _spawn, _vehicles select 0, _vehicles, _extra] call DRO2026_fnc_createSiteRecord;
                    DRO2026_sites pushBack _site;
                    ["DELIVERY_MATERIALIZED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["position", _spawn]], _delivery get "id"] call DRO2026_fnc_emitEvent;
                } else {
                    {if (!isNull _x) then {deleteVehicleCrew _x; deleteVehicle _x}} forEach _vehicles;
                    if (!isNull _group) then {deleteGroup _group};
                };
            };

            if ((_delivery getOrDefault ["physicalState", "VIRTUAL"]) == "ACTIVE") then {
                private _cargoVehicle = _delivery getOrDefault ["cargoVehicle", objNull];
                if (isNull _cargoVehicle || {!alive _cargoVehicle} || {!canMove _cargoVehicle}) then {
                    _delivery set ["status", "INTERDICTED"];
                    _delivery set ["completedAt", _now];
                    _delivery set ["physicalState", "DESTROYED"];
                    [_delivery get "id", "INTERDICTED"] call _setActiveConvoyStatus;
                    if (count _edge > 0) then {
                        _edge set ["risk", ((_edge getOrDefault ["risk", 0.12]) + 0.22) min 0.95];
                        _edge set ["interdictionPressure", (_edge getOrDefault ["interdictionPressure", 0]) + 1];
                        _edge set ["nextDeliveryAt", _now + ((_edge getOrDefault ["travelTime", 600]) * (1.2 + (_edge getOrDefault ["risk", 0.12])))];
                        DRO2026_networkEdges set [_edgeId, _edge];
                    };
                    ["DELIVERY_INTERDICTED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["cargoType", _delivery getOrDefault ["cargoType", ""]], ["amount", _delivery getOrDefault ["amount", 0]]], _delivery get "id"] call DRO2026_fnc_emitEvent;
                } else {
                    if (_cargoVehicle distance2D _to < 120) then {
                        _delivery set ["status", "DELIVERED"];
                        _delivery set ["completedAt", _now];
                        [_delivery get "id", "DELIVERED"] call _setActiveConvoyStatus;
                    };
                };
            } else {
                if ((_delivery getOrDefault ["status", ""]) == "VIRTUAL" && {_now >= _eta}) then {
                    _delivery set ["status", "DELIVERED"];
                    _delivery set ["completedAt", _now];
                };
            };

            if ((_delivery getOrDefault ["status", ""]) == "DELIVERED" && {!(_delivery getOrDefault ["processed", false])}) then {
                private _toNode = _delivery getOrDefault ["toNode", ""];
                private _cargoType = _delivery getOrDefault ["cargoType", ""];
                private _amount = _delivery getOrDefault ["amount", 0];
                [_toNode, _cargoType, _amount, "DELIVERY_COMPLETED"] call DRO2026_fnc_changeNetworkNodeStock;
                _delivery set ["processed", true];
                _delivery set ["processedAt", _now];
                if (count _edge > 0) then {
                    _edge set ["lastDeliveryAt", _now];
                    _edge set ["risk", ((_edge getOrDefault ["risk", 0.12]) - 0.04) max 0.05];
                    _edge set ["nextDeliveryAt", _now + (_edge getOrDefault ["travelTime", 600])];
                    DRO2026_networkEdges set [_edgeId, _edge];
                };
                ["DELIVERY_COMPLETED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["toNode", _toNode], ["cargoType", _cargoType], ["amount", _amount]], _delivery get "id"] call DRO2026_fnc_emitEvent;
                {if (!isNull _x) then {deleteVehicleCrew _x; deleteVehicle _x}} forEach (_delivery getOrDefault ["vehicles", []]);
                private _deliveryGroup = _delivery getOrDefault ["group", grpNull];
                if (!isNull _deliveryGroup) then {deleteGroup _deliveryGroup};
            };
        };
    } forEach DRO2026_supplyLanes;

    // Create new virtual deliveries from actual consumer deficits.
    {
        private _edgeId = _x;
        private _edge = DRO2026_networkEdges get _edgeId;
        if ((_edge getOrDefault ["status", "OPEN"]) == "OPEN" && {_now >= (_edge getOrDefault ["nextDeliveryAt", 0])}) then {
            private _hasActive = (DRO2026_supplyLanes findIf {
                (_x getOrDefault ["edgeId", ""]) == _edgeId && {(_x getOrDefault ["status", ""]) in ["VIRTUAL", "IN_TRANSIT", "EN_ROUTE"]}
            }) >= 0;
            if (!_hasActive) then {
                private _fromId = _edge getOrDefault ["from", ""];
                private _toId = _edge getOrDefault ["to", ""];
                private _fromNode = DRO2026_networkNodes getOrDefault [_fromId, createHashMap];
                private _toNode = DRO2026_networkNodes getOrDefault [_toId, createHashMap];
                if (count _fromNode > 0 && {count _toNode > 0} && {!((_fromNode getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"])}) then {
                    private _fromStocks = _fromNode getOrDefault ["stocks", createHashMap];
                    private _toStocks = _toNode getOrDefault ["stocks", createHashMap];
                    private _deficits = [];
                    {
                        private _cargoType = _x;
                        private _target = _targetStocks getOrDefault [_cargoType, _edge getOrDefault ["capacity", 1]];
                        private _current = _toStocks getOrDefault [_cargoType, 0];
                        private _available = _fromStocks getOrDefault [_cargoType, 0];
                        private _deficit = (_target - _current) max 0;
                        if (_deficit > 0 && {_available > 0}) then {_deficits pushBack [_cargoType, _deficit, _available]};
                    } forEach (_edge getOrDefault ["cargoTypes", []]);
                    if (count _deficits > 0) then {
                        _deficits = [_deficits, [], {-((_x select 1) / ((_targetStocks getOrDefault [_x select 0, 1]) max 1))}, "ASCEND"] call BIS_fnc_sortBy;
                        (_deficits select 0) params ["_cargoType", "_deficit", "_available"];
                        private _amount = (_edge getOrDefault ["capacity", 1]) min _deficit min _available;
                        if (_amount > 0) then {
                            [_fromId, _cargoType, -_amount, "DELIVERY_DISPATCHED"] call DRO2026_fnc_changeNetworkNodeStock;
                            private _travel = (_edge getOrDefault ["travelTime", 600]) * (1 + (_edge getOrDefault ["risk", 0.12]) * 0.7);
                            private _delivery = createHashMapFromArray [
                                ["schema", 2], ["id", format ["DELIVERY_%1_%2", floor diag_tickTime, floor random 1000000]],
                                ["edgeId", _edgeId], ["fromNode", _fromId], ["toNode", _toId],
                                ["source", +(_fromNode getOrDefault ["position", [0,0,0]])], ["destination", +(_toNode getOrDefault ["position", [0,0,0]])],
                                ["cargoType", _cargoType], ["amount", _amount], ["status", "VIRTUAL"], ["physicalState", "VIRTUAL"],
                                ["createdAt", _now], ["eta", _now + _travel], ["processed", false]
                            ];
                            DRO2026_supplyLanes pushBack _delivery;
                            _edge set ["nextDeliveryAt", _now + _travel + 120];
                            DRO2026_networkEdges set [_edgeId, _edge];
                            ["DELIVERY_STARTED", createHashMapFromArray [["deliveryId", _delivery get "id"], ["edgeId", _edgeId], ["cargoType", _cargoType], ["amount", _amount], ["eta", _delivery get "eta"]], _delivery get "id"] call DRO2026_fnc_emitEvent;
                        };
                    } else {
                        _edge set ["nextDeliveryAt", _now + 180];
                        DRO2026_networkEdges set [_edgeId, _edge];
                    };
                };
            };
        };
    } forEach keys DRO2026_networkEdges;

    // Mirror node stocks into legacy aggregate values used by old UI and remaining scripts.
    private _logistics = DRO2026_networkNodes getOrDefault ["NODE_LOGISTICS_01", createHashMap];
    private _artillery = DRO2026_networkNodes getOrDefault ["NODE_ARTILLERY_01", createHashMap];
    private _fpv = DRO2026_networkNodes getOrDefault ["NODE_FPV_FORWARD_01", createHashMap];
    private _long = DRO2026_networkNodes getOrDefault ["NODE_DRONE_REAR_01", createHashMap];
    private _logStocks = _logistics getOrDefault ["stocks", createHashMap];
    private _artStocks = _artillery getOrDefault ["stocks", createHashMap];
    private _fpvStocks = _fpv getOrDefault ["stocks", createHashMap];
    private _longStocks = _long getOrDefault ["stocks", createHashMap];
    DRO2026_resources set ["enemySupply", ((_logStocks getOrDefault ["FUEL", 0]) + (_logStocks getOrDefault ["ARTILLERY_AMMO", 0]) + (_logStocks getOrDefault ["FPV_KITS", 0])) min 100];
    DRO2026_resources set ["enemyArtilleryAmmo", _artStocks getOrDefault ["ARTILLERY_AMMO", 0]];
    DRO2026_resources set ["enemyDroneStock", _fpvStocks getOrDefault ["FPV_KITS", 0]];
    DRO2026_resources set ["enemyLongRangeStock", _longStocks getOrDefault ["LONG_RANGE_DRONES", 0]];

    sleep 20;
};