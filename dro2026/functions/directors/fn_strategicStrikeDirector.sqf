if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_strategicStrikeDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_strategicStrikeDirectorStarted",true];
private _nodeId = "NODE_BALLISTIC_01";
private _lastLaunch = -9999;
private _launches = 0;
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
    private _effects = [enemySide] call DRO2026_fnc_getOperationalEffects;
    private _phase = DRO2026_operationState getOrDefault ["phase","DEPLOYMENT"];
    private _status = toUpperANSI (_node getOrDefault ["status","DISABLED"]);
    private _stocks = _node getOrDefault ["stocks",createHashMap];
    private _missiles = _stocks getOrDefault ["BALLISTIC_MISSILES",0];
    private _fuel = _stocks getOrDefault ["FUEL",0];
    private _strikeFactor = _effects getOrDefault ["strikeFactor",0];
    private _active = missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]];
    private _activeBallistic = {
        (_x getOrDefault ["launchSide",sideUnknown]) == enemySide &&
        {toUpperANSI (_x getOrDefault ["profile",""]) in ["ISKANDER","BALLISTIC"]} &&
        {toUpperANSI (_x getOrDefault ["state","INBOUND"]) == "INBOUND"}
    } count _active;
    private _physicalLaunchers = (_node getOrDefault ["physicalRefs",[]]) select {
        !isNull _x && {alive _x} && {local _x} && {canMove _x} && {!isNull driver _x} && {
            [typeOf _x] call DRO2026_fnc_getAssetPrimaryRole == "BALLISTIC_MISSILE_LAUNCHER"
        }
    };
    private _launcher = if (count _physicalLaunchers > 0) then {_physicalLaunchers select 0} else {objNull};
    private _ammoClass = if (isNull _launcher) then {""} else {[typeOf _launcher] call DRO2026_fnc_resolveLauncherAmmo};
    if (_ammoClass != "" && {!isClass (configFile >> "CfgAmmo" >> _ammoClass)}) then {_ammoClass = ""};
    private _maxLaunches = missionNamespace getVariable ["DRO2026_MAX_ISKANDER_LAUNCHES",2];
    private _baseCooldown = missionNamespace getVariable ["DRO2026_ISKANDER_COOLDOWN",900];
    private _cooldown = (_baseCooldown * (1 / ((_strikeFactor max 0.28)))) min 2400;
    private _stateMachine = toUpperANSI (_node getOrDefault ["stateMachineState","HIDDEN"]);
    private _ready = count _node > 0 && {!(_status in ["DESTROYED","DISABLED","CANCELLED"])} && {
        _stateMachine in ["HIDDEN","READY"]
    } && {
        _phase in ["SHAPING","DISRUPTION","DEEP_STRIKE","COUNTERATTACK","EXPLOITATION"]
    } && {
        !isNull _launcher && {_ammoClass != ""}
    } && {
        _missiles >= 1 && {_fuel >= 1} && {_launches < _maxLaunches} && {_activeBallistic < 1} && {(time - _lastLaunch) >= _cooldown}
    };
    if (_ready) then {
        private _target = [enemySide,"ISKANDER","TRACKED"] call DRO2026_fnc_selectStrategicTarget;
        if (_target getOrDefault ["ok",false]) then {
            private _originATL = getPosATL _launcher;
            [_nodeId,"BALLISTIC_MISSILES",-1,"ISKANDER_LAUNCH_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
            [_nodeId,"FUEL",-1,"ISKANDER_LAUNCH_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
            _node set ["stateMachineState","PREPARING"];
            _node set ["activeLauncherNetId",netId _launcher];
            _node set ["lastUpdatedAt",time];
            DRO2026_networkNodes set [_nodeId,_node];
            ["BALLISTIC_LAUNCH_PREPARING",createHashMapFromArray [
                ["nodeId",_nodeId],["launcher",typeOf _launcher],["targetNodeId",_target getOrDefault ["nodeId",""]]
            ],_nodeId] call DRO2026_fnc_emitEvent;
            sleep (18 + random 24);
            private _currentNode = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
            private _currentStatus = toUpperANSI (_currentNode getOrDefault ["status","DISABLED"]);
            private _launcherValid = !isNull _launcher && {alive _launcher} && {local _launcher} && {canMove _launcher} && {!isNull driver _launcher};
            if (_currentStatus in ["DESTROYED","DISABLED","CANCELLED"] || {!_launcherValid}) then {
                [_nodeId,"BALLISTIC_MISSILES",1,"ISKANDER_PRELAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                [_nodeId,"FUEL",1,"ISKANDER_PRELAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                _currentNode set ["stateMachineState",if (_launcherValid) then {"HIDDEN"} else {"DEGRADED"}];
                DRO2026_networkNodes set [_nodeId,_currentNode];
            } else {
                _currentNode set ["stateMachineState","READY"];
                DRO2026_networkNodes set [_nodeId,_currentNode];
                private _munition = [_originATL,_target,enemySide,"ISKANDER",_ammoClass,1.7,0.55] call DRO2026_fnc_launchStrategicMunition;
                if (count _munition > 0) then {
                    _lastLaunch = time;
                    _launches = _launches + 1;
                    DRO2026_operationState set ["iskanderLaunches",_launches];
                    _currentNode set ["stateMachineState","FIRED"];
                    _currentNode set ["lastLaunchAt",time];
                    _currentNode set ["launches",_launches];
                    DRO2026_networkNodes set [_nodeId,_currentNode];
                    ["STRATEGIC_STRIKE_ORDERED",createHashMapFromArray [
                        ["actor",_nodeId],["targetNodeId",_target getOrDefault ["nodeId",""]],
                        ["profile","ISKANDER"],["munitionId",_munition getOrDefault ["id",""]],
                        ["launcherNetId",netId _launcher],["remainingMissiles",(_missiles - 1) max 0]
                    ],_nodeId] call DRO2026_fnc_emitEvent;
                    [_nodeId,_launcher] spawn {
                        params ["_nodeId","_launcher"];
                        sleep (25 + random 30);
                        private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
                        if (count _node == 0 || {isNull _launcher} || {!alive _launcher} || {!local _launcher} || {!canMove _launcher} || {isNull driver _launcher}) exitWith {
                            if (count _node > 0) then {
                                _node set ["stateMachineState","DEGRADED"];
                                DRO2026_networkNodes set [_nodeId,_node];
                            };
                        };
                        _node set ["stateMachineState","DISPLACING"];
                        _node set ["emissionState","SILENT"];
                        DRO2026_networkNodes set [_nodeId,_node];
                        private _origin = getPosATL _launcher;
                        private _bearing = [360,format ["ISKANDER_DISPLACE_%1",_node getOrDefault ["launches",1]],0] call DRO2026_fnc_seededRandom;
                        private _placement = [_origin,700,2200,_bearing,true,true,650] call DRO2026_fnc_findRoadAwarePosition;
                        if !(_placement getOrDefault ["ok",false]) exitWith {
                            _node set ["stateMachineState","HIDDEN"];
                            _node set ["relocationFailure",_placement getOrDefault ["code","NO_ROAD_POSITION"]];
                            DRO2026_networkNodes set [_nodeId,_node];
                            ["BALLISTIC_LAUNCHER_RELOCATION_FAILED",createHashMapFromArray [
                                ["nodeId",_nodeId],["reason",_placement getOrDefault ["code","NO_ROAD_POSITION"]]
                            ],_nodeId] call DRO2026_fnc_emitEvent;
                        };
                        private _destination = +(_placement getOrDefault ["positionATL",[]]);
                        private _group = group (driver _launcher);
                        while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
                        _launcher forceFollowRoad true;
                        private _waypoint = _group addWaypoint [_destination,30];
                        _waypoint setWaypointType "MOVE";
                        _waypoint setWaypointSpeed "FULL";
                        _waypoint setWaypointBehaviour "AWARE";
                        _waypoint setWaypointCompletionRadius 70;
                        _group setCurrentWaypoint _waypoint;
                        private _deadline = time + 300;
                        waitUntil {
                            sleep 3;
                            isNull _launcher || {!alive _launcher} || {!canMove _launcher} || {_launcher distance2D _destination < 90} ||
                            {time > _deadline} || {missionNamespace getVariable ["DRO2026_missionEnding",false]}
                        };
                        _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
                        if (!isNull _launcher && {alive _launcher} && {canMove _launcher} && {_launcher distance2D _destination < 120}) then {
                            private _newPositionATL = getPosATL _launcher;
                            _node set ["position",+_newPositionATL];
                            _node set ["stateMachineState","HIDDEN"];
                            _node set ["lastRelocationAt",time];
                            DRO2026_networkNodes set [_nodeId,_node];
                            {
                                if ((_x getOrDefault ["networkNodeId",""]) == _nodeId) then {
                                    _x set ["position",+_newPositionATL];
                                    _x set ["positionATL",+_newPositionATL];
                                    _x set ["positionASL",ATLToASL _newPositionATL];
                                    _x set ["lastUpdatedAt",time];
                                };
                            } forEach DRO2026_sites;
                            ["BALLISTIC_LAUNCHER_DISPLACED",createHashMapFromArray [
                                ["nodeId",_nodeId],["launcherNetId",netId _launcher],["positionATL",+_newPositionATL]
                            ],_nodeId] call DRO2026_fnc_emitEvent;
                        } else {
                            _node set ["stateMachineState",if (!isNull _launcher && {alive _launcher}) then {"DEGRADED"} else {"DESTROYED"}];
                            _node set ["relocationFailure","MOVE_FAILED"];
                            DRO2026_networkNodes set [_nodeId,_node];
                            ["BALLISTIC_LAUNCHER_RELOCATION_FAILED",createHashMapFromArray [
                                ["nodeId",_nodeId],["reason","MOVE_FAILED"]
                            ],_nodeId] call DRO2026_fnc_emitEvent;
                        };
                    };
                } else {
                    [_nodeId,"BALLISTIC_MISSILES",1,"ISKANDER_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                    [_nodeId,"FUEL",1,"ISKANDER_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                    _currentNode set ["stateMachineState","HIDDEN"];
                    DRO2026_networkNodes set [_nodeId,_currentNode];
                };
            };
        };
    };
    sleep 20;
};