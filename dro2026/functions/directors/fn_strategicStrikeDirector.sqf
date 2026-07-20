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
    private _activeBallistic = {_x getOrDefault ["launchSide",sideUnknown] == enemySide && {toUpperANSI (_x getOrDefault ["profile",""]) in ["ISKANDER","BALLISTIC"]} && {toUpperANSI (_x getOrDefault ["state","INBOUND"]) == "INBOUND"}} count _active;
    private _maxLaunches = missionNamespace getVariable ["DRO2026_MAX_ISKANDER_LAUNCHES",2];
    private _baseCooldown = missionNamespace getVariable ["DRO2026_ISKANDER_COOLDOWN",900];
    private _cooldown = _baseCooldown * (1 / ((_strikeFactor max 0.28))) min 2400;
    private _ready = count _node > 0 && {!(_status in ["DESTROYED","DISABLED","CANCELLED"])} && {
        _phase in ["SHAPING","DISRUPTION","DEEP_STRIKE","COUNTERATTACK","EXPLOITATION"]
    } && {_missiles >= 1} && {_fuel >= 1} && {_launches < _maxLaunches} && {_activeBallistic < 1} && {(time - _lastLaunch) >= _cooldown};
    if (_ready) then {
        private _target = [enemySide,"ISKANDER","TRACKED"] call DRO2026_fnc_selectStrategicTarget;
        if (_target getOrDefault ["ok",false]) then {
            private _originATL = _node getOrDefault ["position",[]];
            private _ammoClass = "";
            private _physical = (_node getOrDefault ["physicalRefs",[]]) select {!isNull _x && {alive _x}};
            {
                private _resolved = [typeOf _x] call DRO2026_fnc_resolveLauncherAmmo;
                if (_resolved != "" && {isClass (configFile >> "CfgAmmo" >> _resolved)}) exitWith {_ammoClass = _resolved};
            } forEach _physical;
            if (_ammoClass == "") then {
                private _role = format ["BALLISTIC_MISSILE_%1",[enemySide] call DRO2026_fnc_getSideSuffix];
                {
                    private _resolved = [_x] call DRO2026_fnc_resolveLauncherAmmo;
                    if (_resolved != "" && {isClass (configFile >> "CfgAmmo" >> _resolved)}) exitWith {_ammoClass = _resolved};
                } forEach (DRO2026_assetRegistry getOrDefault [_role,[]]);
            };
            if (_ammoClass != "" && {count _originATL >= 2}) then {
                [_nodeId,"BALLISTIC_MISSILES",-1,"ISKANDER_LAUNCH_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
                [_nodeId,"FUEL",-1,"ISKANDER_LAUNCH_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
                _node set ["stateMachineState","PREPARING"];
                _node set ["lastUpdatedAt",time];
                DRO2026_networkNodes set [_nodeId,_node];
                sleep (18 + random 24);
                private _currentNode = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
                private _currentStatus = toUpperANSI (_currentNode getOrDefault ["status","DISABLED"]);
                if (_currentStatus in ["DESTROYED","DISABLED","CANCELLED"]) then {
                    [_nodeId,"BALLISTIC_MISSILES",1,"ISKANDER_PRELAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                    [_nodeId,"FUEL",1,"ISKANDER_PRELAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                } else {
                    _currentNode set ["stateMachineState","READY"];
                    DRO2026_networkNodes set [_nodeId,_currentNode];
                    private _munition = [_originATL,_target,enemySide,"ISKANDER",_ammoClass,1.7,0.55] call DRO2026_fnc_launchStrategicMunition;
                    if (count _munition > 0) then {
                        _lastLaunch = time;
                        _launches = _launches + 1;
                        _currentNode set ["stateMachineState","FIRED"];
                        _currentNode set ["lastLaunchAt",time];
                        _currentNode set ["launches",_launches];
                        DRO2026_networkNodes set [_nodeId,_currentNode];
                        ["STRATEGIC_STRIKE_ORDERED",createHashMapFromArray [
                            ["actor",_nodeId],["targetNodeId",_target getOrDefault ["nodeId",""]],
                            ["profile","ISKANDER"],["munitionId",_munition getOrDefault ["id",""]],
                            ["remainingMissiles",(_missiles - 1) max 0]
                        ],_nodeId] call DRO2026_fnc_emitEvent;
                        [_nodeId] spawn {
                            params ["_nodeId"];
                            sleep (45 + random 55);
                            private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
                            if (count _node > 0 && {!((toUpperANSI (_node getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])}) then {
                                _node set ["stateMachineState","DISPLACING"];
                                _node set ["emissionState","SILENT"];
                                DRO2026_networkNodes set [_nodeId,_node];
                                sleep (50 + random 70);
                                _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
                                if (count _node > 0) then {_node set ["stateMachineState","HIDDEN"]; DRO2026_networkNodes set [_nodeId,_node]};
                            };
                        };
                    } else {
                        [_nodeId,"BALLISTIC_MISSILES",1,"ISKANDER_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                        [_nodeId,"FUEL",1,"ISKANDER_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
                    };
                };
            };
        };
    };
    sleep 20;
};