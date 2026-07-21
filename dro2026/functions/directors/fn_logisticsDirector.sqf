if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_logisticsDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_logisticsDirectorStarted",true];

private _targetStocks = createHashMapFromArray [
    ["ARTILLERY_AMMO",24],["FPV_KITS",12],["LONG_RANGE_DRONES",8],["FUEL",18],
    ["EW_BATTERIES",10],["AA_MISSILES",10],["RADAR_PARTS",3],["BATTERIES",10],
    ["INFANTRY_REPLACEMENTS",24],["MEDICAL",12]
];
private _terminalStates = ["COMPLETE","FAILED","DESTROYED","CANCELED"];
private _cleanupJob = {
    params [["_job",createHashMap,[createHashMap]],["_deleteAlive",true,[true]]];
    private _group = _job getOrDefault ["group",grpNull];
    {
        if (!isNull _x) then {
            if (local _x) then {
                deleteVehicleCrew _x;
                if (_deleteAlive || {!alive _x}) then {deleteVehicle _x};
            };
        };
    } forEach (_job getOrDefault ["vehicles",[]]);
    if (!isNull _group) then {deleteGroup _group};
};
private _setSiteState = {
    params [["_job",createHashMap,[createHashMap]],["_state","DISABLED",[""]]];
    private _site = _job getOrDefault ["siteRecord",createHashMap];
    if (count _site > 0) then {
        _site set ["state",_state];
        _site set ["status",_state];
        _site set ["lastUpdatedAt",time];
    };
};
private _refund = {
    params [["_job",createHashMap,[createHashMap]],["_reason","DELIVERY_REFUNDED",[""]]];
    if (_job getOrDefault ["reservationSettled",false]) exitWith {};
    private _sourceId = _job getOrDefault ["sourceNodeId",""];
    private _cargo = _job getOrDefault ["cargo",createHashMap];
    {
        [_sourceId,_x,_cargo getOrDefault [_x,0],_reason] call DRO2026_fnc_changeNetworkNodeStock;
    } forEach keys _cargo;
    _job set ["reservationSettled",true];
};
private _materialize = {
    params [["_edgeId","",[""]],["_cargoType","",[""]],["_amount",0,[0]]];
    private _edge = DRO2026_networkEdges getOrDefault [_edgeId,createHashMap];
    private _fromId = _edge getOrDefault ["from",""];
    private _toId = _edge getOrDefault ["to",""];
    private _fromNode = DRO2026_networkNodes getOrDefault [_fromId,createHashMap];
    private _toNode = DRO2026_networkNodes getOrDefault [_toId,createHashMap];
    if (_fromId == "" || {_toId == ""} || {count _fromNode == 0} || {count _toNode == 0}) exitWith {createHashMap};

    private _side = _fromNode getOrDefault ["side",enemySide];
    private _source = _fromNode getOrDefault ["position",[0,0,0]];
    private _destination = _toNode getOrDefault ["position",[0,0,0]];
    private _bearing = _source getDir _destination;
    private _placement = [_source,250,1800,_bearing,true,false,350] call DRO2026_fnc_findRoadAwarePosition;
    if !(_placement getOrDefault ["ok",false]) exitWith {
        ["LOGISTICS","ROAD_PLACEMENT_REJECTED",createHashMapFromArray [
            ["edgeId",_edgeId],["fromNode",_fromId],["toNode",_toId],
            ["reason",_placement getOrDefault ["fallbackReason","ROAD_REQUIRED_NOT_FOUND"]],
            ["code",_placement getOrDefault ["code","ROAD_REQUIRED_NOT_FOUND"]]
        ],_edgeId] call DRO2026_fnc_logStructured;
        createHashMap
    };
    private _spawn = +(_placement getOrDefault ["positionATL",_placement getOrDefault ["position",[]]]);
    if (count _spawn < 2) exitWith {createHashMap};

    private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
    private _cargoFallback = switch _side do {
        case west: {"B_Truck_01_ammo_F"};
        case resistance: {"I_Truck_02_ammo_F"};
        default {"O_Truck_03_ammo_F"};
    };
    if (_cargoType == "FUEL") then {
        _cargoFallback = switch _side do {
            case west: {"B_Truck_01_fuel_F"};
            case resistance: {"I_Truck_02_fuel_F"};
            default {"O_Truck_03_fuel_F"};
        };
    };
    private _escortFallback = switch _side do {
        case west: {"B_MRAP_01_hmg_F"};
        case resistance: {"I_MRAP_03_hmg_F"};
        default {"O_MRAP_02_hmg_F"};
    };
    private _cargoClass = [format ["CONVOY_CARGO_%1",_suffix],_cargoFallback,_side] call DRO2026_fnc_getSideRoleClass;
    private _escortClass = [format ["CONVOY_ESCORT_%1",_suffix],_escortFallback,_side] call DRO2026_fnc_getSideRoleClass;
    if (_cargoClass == "" || {!([_cargoClass,"LOGISTICS_POOL"] call DRO2026_fnc_isAssetAllowedForRole)}) exitWith {
        ["ROLE","LOGISTICS_CLASS_REJECTED",createHashMapFromArray [
            ["class",_cargoClass],["role",[_cargoClass] call DRO2026_fnc_getAssetPrimaryRole],["edgeId",_edgeId]
        ],_edgeId] call DRO2026_fnc_logStructured;
        createHashMap
    };
    private _escortRole = [_escortClass] call DRO2026_fnc_getAssetPrimaryRole;
    if (_escortRole in ["ARTILLERY_TUBE","ARTILLERY_TUBE_HEAVY","ARTILLERY_ROCKET","ARTILLERY_ROCKET_LIGHT","ARTILLERY_ROCKET_HEAVY","MORTAR","SAM_LONG_RANGE","SAM_MEDIUM_RANGE","SAM_SHORT_RANGE","SHORAD","EARLY_WARNING_RADAR","FIRE_CONTROL_RADAR","BALLISTIC_MISSILE_LAUNCHER","CRUISE_MISSILE_CARRIER","UAV_LAUNCHER","FPV_LAUNCHER"]) then {
        _escortClass = _escortFallback;
    };

    private _vehiclePlan = [[_cargoClass,true]];
    if (_amount > 8) then {_vehiclePlan pushBack [_cargoClass,true]};
    _vehiclePlan pushBack [_escortClass,false];
    private _vehicles = [];
    private _cargoVehicles = [];
    private _group = grpNull;
    {
        _x params [["_class","",[""]],["_isCargo",false,[true]]];
        if (_class != "" && {isClass (configFile >> "CfgVehicles" >> _class)}) then {
            private _vehiclePosition = _spawn getPos [_forEachIndex * 26,_bearing + 180];
            private _vehicle = createVehicle [_class,_vehiclePosition,[],0,"NONE"];
            if (!isNull _vehicle && {local _vehicle}) then {
                _vehicle setDir _bearing;
                _vehicle setVehiclePosition [getPosATL _vehicle,[],0,"NONE"];
                private _crew = _side createVehicleCrew _vehicle;
                if (!isNull _crew && {!isNull driver _vehicle}) then {
                    if (isNull _group) then {
                        _group = _crew;
                    } else {
                        (units _crew) joinSilent _group;
                        if (count units _crew == 0) then {deleteGroup _crew};
                    };
                    _group addVehicle _vehicle;
                    _vehicles pushBack _vehicle;
                    if (_isCargo) then {_cargoVehicles pushBack _vehicle};
                    _vehicle forceFollowRoad true;
                    _vehicle setConvoySeparation 28;
                    _vehicle enableDynamicSimulation true;
                } else {
                    deleteVehicleCrew _vehicle;
                    deleteVehicle _vehicle;
                    if (!isNull _crew) then {deleteGroup _crew};
                };
            };
        };
    } forEach _vehiclePlan;
    if (isNull _group || {count _cargoVehicles == 0}) exitWith {
        {if (!isNull _x && {local _x}) then {deleteVehicleCrew _x; deleteVehicle _x}} forEach _vehicles;
        if (!isNull _group) then {deleteGroup _group};
        createHashMap
    };

    [_group,false] call DRO2026_fnc_registerManagedGroup;
    _group setBehaviourStrong "SAFE";
    _group setCombatMode "YELLOW";
    _group setSpeedMode "LIMITED";
    _group setFormation "COLUMN";
    private _waypoint = _group addWaypoint [_destination,-1];
    _waypoint setWaypointType "MOVE";
    _waypoint setWaypointSpeed "LIMITED";
    _waypoint setWaypointBehaviour "SAFE";
    _waypoint setWaypointCompletionRadius 65;

    private _jobId = format ["LOGJOB_%1_%2",floor (diag_tickTime * 1000),floor random 100000];
    private _components = createHashMapFromArray [
        ["crew",units _group],["guards",[]],["launchers",[]],["antennas",[]],
        ["terminals",[]],["generators",[]],["stocks",_cargoVehicles],
        ["transports",_vehicles],["camouflage",[]],["staticProps",[]]
    ];
    private _siteExtra = createHashMapFromArray [
        ["deliveryId",_jobId],["networkNodeId",_toId],["side",_side],
        ["components",_components],["cargoType",_cargoType],["amount",_amount],
        ["roadAnchorNetId",_placement getOrDefault ["roadAnchorNetId",""]]
    ];
    private _site = ["LOGISTICS_RUN",_spawn,_cargoVehicles select 0,_vehicles,_siteExtra] call DRO2026_fnc_createSiteRecord;
    DRO2026_sites pushBack _site;
    private _job = createHashMapFromArray [
        ["schema",3],["id",_jobId],["side",_side],["type",_cargoType],
        ["sourceNodeId",_fromId],["destinationNodeId",_toId],
        ["cargo",createHashMapFromArray [[_cargoType,_amount]]],
        ["vehicles",_vehicles],["cargoVehicles",_cargoVehicles],["escortGroups",[_group]],
        ["group",_group],["route",[_spawn,_destination]],["state","ENROUTE"],
        ["status","ENROUTE"],["siteRecord",_site],["createdAt",time],["updatedAt",time],
        ["reservationSettled",false],["returning",false]
    ];
    {DRO2026_managedVehicles pushBackUnique _x} forEach _vehicles;
    ["DELIVERY_MATERIALIZED",createHashMapFromArray [
        ["deliveryId",_jobId],["edgeId",_edgeId],["position",_spawn],
        ["cargoType",_cargoType],["amount",_amount]
    ],_jobId] call DRO2026_fnc_emitEvent;
    _job
};

while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _now = time;
    [] call DRO2026_fnc_syncNetworkState;
    {
        private _job = _x;
        private _state = _job getOrDefault ["state","FAILED"];
        if !(_state in _terminalStates) then {
            private _cargoVehicles = _job getOrDefault ["cargoVehicles",[]];
            private _aliveCargo = _cargoVehicles select {!isNull _x && {alive _x} && {canMove _x}};
            private _destinationId = _job getOrDefault ["destinationNodeId",""];
            private _destination = DRO2026_networkNodes getOrDefault [_destinationId,createHashMap];
            if (count _aliveCargo == 0) then {
                _job set ["state","DESTROYED"];
                _job set ["status","DESTROYED"];
                _job set ["updatedAt",_now];
                _job set ["reservationSettled",true];
                [_job,"DESTROYED"] call _setSiteState;
                ["DELIVERY_INTERDICTED",createHashMapFromArray [
                    ["deliveryId",_job get "id"],["cargo",_job getOrDefault ["cargo",createHashMap]]
                ],_job get "id"] call DRO2026_fnc_emitEvent;
                [_job,false] call _cleanupJob;
            } else {
                if (count _destination == 0 || {(_destination getOrDefault ["status","ACTIVE"]) in ["DESTROYED","DISABLED"]}) then {
                    if !(_job getOrDefault ["returning",false]) then {
                        private _source = DRO2026_networkNodes getOrDefault [_job getOrDefault ["sourceNodeId",""],createHashMap];
                        private _sourcePos = _source getOrDefault ["position",[0,0,0]];
                        private _group = _job getOrDefault ["group",grpNull];
                        if (!isNull _group) then {
                            private _returnWaypoint = _group addWaypoint [_sourcePos,-1];
                            _returnWaypoint setWaypointType "MOVE";
                            _returnWaypoint setWaypointCompletionRadius 65;
                            _group setCurrentWaypoint _returnWaypoint;
                        };
                        _job set ["state","RETURNING"];
                        _job set ["status","RETURNING"];
                        _job set ["returning",true];
                    };
                } else {
                    private _destinationPos = _destination getOrDefault ["position",[0,0,0]];
                    private _lead = _aliveCargo select 0;
                    if ((_lead distance2D _destinationPos) < 110) then {
                        _job set ["state","TRANSFERRING"];
                        _job set ["status","TRANSFERRING"];
                        private _cargo = _job getOrDefault ["cargo",createHashMap];
                        private _ok = true;
                        {
                            private _result = [_x,_cargo getOrDefault [_x,0],_lead,_destinationId] call DRO2026_fnc_transferLogisticsCargo;
                            if !(_result getOrDefault ["ok",false]) then {_ok = false};
                        } forEach keys _cargo;
                        if (_ok) then {
                            {
                                [_destinationId,_x,_cargo getOrDefault [_x,0],"DELIVERY_COMPLETED"] call DRO2026_fnc_changeNetworkNodeStock;
                            } forEach keys _cargo;
                            _job set ["reservationSettled",true];
                            _job set ["state","COMPLETE"];
                            _job set ["status","COMPLETE"];
                            _job set ["updatedAt",_now];
                            [_job,"COMPLETED"] call _setSiteState;
                            ["DELIVERY_COMPLETED",createHashMapFromArray [
                                ["deliveryId",_job get "id"],["toNode",_destinationId],["cargo",_cargo]
                            ],_job get "id"] call DRO2026_fnc_emitEvent;
                            [_job,true] call _cleanupJob;
                        } else {
                            _job set ["state","FAILED"];
                            _job set ["status","FAILED"];
                            [_job,"TRANSFER_FAILED"] call _refund;
                            [_job,true] call _cleanupJob;
                        };
                    };
                };
                if (_job getOrDefault ["returning",false]) then {
                    private _source = DRO2026_networkNodes getOrDefault [_job getOrDefault ["sourceNodeId",""],createHashMap];
                    private _sourcePos = _source getOrDefault ["position",[0,0,0]];
                    if (((_aliveCargo select 0) distance2D _sourcePos) < 110) then {
                        [_job,"DESTINATION_UNAVAILABLE"] call _refund;
                        _job set ["state","CANCELED"];
                        _job set ["status","CANCELED"];
                        [_job,"DISABLED"] call _setSiteState;
                        [_job,true] call _cleanupJob;
                    };
                };
            };
        };
    } forEach DRO2026_logisticsJobs;
    DRO2026_activeConvoys = DRO2026_logisticsJobs select {!((_x getOrDefault ["state","FAILED"]) in _terminalStates)};
    DRO2026_supplyLanes = DRO2026_logisticsJobs;

    {
        private _edgeId = _x;
        private _edge = DRO2026_networkEdges get _edgeId;
        if ((_edge getOrDefault ["status","OPEN"]) == "OPEN" && {_now >= (_edge getOrDefault ["nextDeliveryAt",0])}) then {
            private _fromId = _edge getOrDefault ["from",""];
            private _toId = _edge getOrDefault ["to",""];
            private _fromNode = DRO2026_networkNodes getOrDefault [_fromId,createHashMap];
            private _toNode = DRO2026_networkNodes getOrDefault [_toId,createHashMap];
            private _side = _fromNode getOrDefault ["side",enemySide];
            private _activeForSide = {
                (_x getOrDefault ["side",sideUnknown]) == _side &&
                {!((_x getOrDefault ["state","FAILED"]) in _terminalStates)}
            } count DRO2026_logisticsJobs;
            private _edgeBusy = (DRO2026_logisticsJobs findIf {
                (_x getOrDefault ["edgeId",""]) == _edgeId &&
                {!((_x getOrDefault ["state","FAILED"]) in _terminalStates)}
            }) >= 0;
            if (!_edgeBusy && {_activeForSide < (missionNamespace getVariable ["DRO2026_MAX_ACTIVE_LOGISTICS_JOBS_PER_SIDE",4])} && {count _fromNode > 0} && {count _toNode > 0}) then {
                private _fromStocks = _fromNode getOrDefault ["stocks",createHashMap];
                private _toStocks = _toNode getOrDefault ["stocks",createHashMap];
                private _deficits = [];
                {
                    private _target = _targetStocks getOrDefault [_x,_edge getOrDefault ["capacity",1]];
                    private _current = _toStocks getOrDefault [_x,0];
                    private _available = _fromStocks getOrDefault [_x,0];
                    private _deficit = (_target - _current) max 0;
                    if (_deficit > 0 && {_available > 0}) then {_deficits pushBack [_x,_deficit,_available]};
                } forEach (_edge getOrDefault ["cargoTypes",[]]);
                if (count _deficits > 0) then {
                    _deficits = [_deficits,[],{
                        -((_x select 1) / ((_targetStocks getOrDefault [_x select 0,1]) max 1))
                    },"ASCEND"] call BIS_fnc_sortBy;
                    (_deficits select 0) params ["_cargoType","_deficit","_available"];
                    private _amount = (_edge getOrDefault ["capacity",1]) min _deficit min _available;
                    if (_amount > 0) then {
                        [_fromId,_cargoType,-_amount,"DELIVERY_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
                        private _job = [_edgeId,_cargoType,_amount] call _materialize;
                        if (count _job > 0) then {
                            _job set ["edgeId",_edgeId];
                            DRO2026_logisticsJobs pushBack _job;
                            _edge set ["nextDeliveryAt",_now + (_edge getOrDefault ["travelTime",600]) + 180];
                        } else {
                            [_fromId,_cargoType,_amount,"DELIVERY_MATERIALIZATION_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                            _edge set ["nextDeliveryAt",_now + 120];
                        };
                    };
                } else {
                    _edge set ["nextDeliveryAt",_now + 180];
                };
                DRO2026_networkEdges set [_edgeId,_edge];
            };
        };
    } forEach keys DRO2026_networkEdges;

    private _enemyLog = DRO2026_networkNodes getOrDefault ["NODE_LOGISTICS_01",createHashMap];
    private _enemyArt = DRO2026_networkNodes getOrDefault ["NODE_ARTILLERY_01",createHashMap];
    private _enemyFpv = DRO2026_networkNodes getOrDefault ["NODE_FPV_FORWARD_01",createHashMap];
    private _enemyLong = DRO2026_networkNodes getOrDefault ["NODE_DRONE_REAR_01",createHashMap];
    private _logStocks = _enemyLog getOrDefault ["stocks",createHashMap];
    private _artStocks = _enemyArt getOrDefault ["stocks",createHashMap];
    private _fpvStocks = _enemyFpv getOrDefault ["stocks",createHashMap];
    private _longStocks = _enemyLong getOrDefault ["stocks",createHashMap];
    DRO2026_resources set ["enemySupply",((_logStocks getOrDefault ["FUEL",0]) + (_logStocks getOrDefault ["ARTILLERY_AMMO",0]) + (_logStocks getOrDefault ["FPV_KITS",0])) min 300];
    DRO2026_resources set ["enemyArtilleryAmmo",_artStocks getOrDefault ["ARTILLERY_AMMO",0]];
    DRO2026_resources set ["enemyDroneStock",_fpvStocks getOrDefault ["FPV_KITS",0]];
    DRO2026_resources set ["enemyLongRangeStock",_longStocks getOrDefault ["LONG_RANGE_DRONES",0]];
    sleep 30;
};

{
    if !((_x getOrDefault ["state","FAILED"]) in _terminalStates) then {
        [_x,"MISSION_END"] call _refund;
        [_x,true] call _cleanupJob;
    };
} forEach DRO2026_logisticsJobs;
