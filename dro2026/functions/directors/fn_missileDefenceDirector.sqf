if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_missileDefenceDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_missileDefenceDirectorStarted",true];
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _registry = missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]];
    {
        private _record = _x;
        private _munition = _record getOrDefault ["object",objNull];
        private _state = toUpperANSI (_record getOrDefault ["state","INBOUND"]);
        if (!isNull _munition && {_state == "INBOUND"} && {!(_record getOrDefault ["intercepted",false])}) then {
            private _launchSide = _record getOrDefault ["launchSide",enemySide];
            private _defenderSide = _record getOrDefault ["targetSide",if (_launchSide == enemySide) then {playersSide} else {enemySide}];
            private _nodeId = if (_defenderSide == playersSide) then {"NODE_FRIENDLY_AA_LONG"} else {"NODE_AA_LONG_01"};
            private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
            private _status = toUpperANSI (_node getOrDefault ["status","DISABLED"]);
            private _stocks = _node getOrDefault ["stocks",createHashMap];
            private _missiles = _stocks getOrDefault ["AA_MISSILES",0];
            private _nodeATL = _node getOrDefault ["position",[]];
            if (count _node > 0 && {!(_status in ["DESTROYED","DISABLED","CANCELLED"])} && {_missiles > 0} && {count _nodeATL >= 2}) then {
                private _nodeASL = [_nodeATL,"ATL",objNull] call DRO2026_fnc_normalizePositionASL;
                private _munitionASL = getPosASL _munition;
                private _distance = _nodeASL distance2D _munitionASL;
                private _effects = [_defenderSide] call DRO2026_fnc_getOperationalEffects;
                private _radarFactor = _effects getOrDefault ["radarFactor",0];
                private _commandFactor = _effects getOrDefault ["commandFactor",0.35];
                private _profile = toUpperANSI (_record getOrDefault ["profile","CRUISE"]);
                private _range = if (_profile in ["ISKANDER","BALLISTIC"]) then {18000} else {14500};
                if (_distance <= _range) then {
                    private _lastDetection = _record getOrDefault ["lastDetectionCheck",-999];
                    if (!(_record getOrDefault ["detected",false]) && {(time - _lastDetection) >= 2.5}) then {
                        _record set ["lastDetectionCheck",time];
                        private _rcs = _record getOrDefault ["radarCrossSection",0.65];
                        private _altitudeAGL = ((getPosATL _munition) select 2) max 0;
                        private _altitudeFactor = linearConversion [20,900,_altitudeAGL,0.45,1,true];
                        private _rangeFactor = linearConversion [_range,2500,_distance,0.35,1,true];
                        private _profileFactor = if (_profile in ["ISKANDER","BALLISTIC"]) then {0.72} else {if (_profile in ["FP5","FLAMINGO"]) then {0.88} else {1}};
                        private _detectChance = (0.12 + (0.58 * _radarFactor * _commandFactor * _rangeFactor * _altitudeFactor * _profileFactor * (_rcs min 1.2))) min 0.94;
                        if (random 1 < _detectChance) then {
                            _record set ["detected",true];
                            private _detectedBy = _record getOrDefault ["detectedBy",[]];
                            _detectedBy pushBackUnique _nodeId;
                            _record set ["detectedBy",_detectedBy];
                            ["STRATEGIC_MUNITION_DETECTED",createHashMapFromArray [
                                ["munitionId",_record getOrDefault ["id",""]],["profile",_profile],
                                ["defender",str _defenderSide],["nodeId",_nodeId],["distance",_distance],
                                ["detectionChance",_detectChance]
                            ],_record getOrDefault ["id",""]] call DRO2026_fnc_emitEvent;
                            if (_defenderSide == playersSide) then {["ALERT","Штаб: обнаружена баллистическая или крылатая цель. ПВО ведёт сопровождение."] call DRO2026_fnc_hqVoice};
                        };
                    };
                    private _engagements = _record getOrDefault ["engagements",0];
                    private _lastEngagement = _record getOrDefault ["lastEngagementAt",-999];
                    if (_record getOrDefault ["detected",false] && {_engagements < 2} && {(time - _lastEngagement) > 7} && {_distance <= (_range * 0.88)}) then {
                        private _interceptorAmmo = "";
                        private _launchers = (_node getOrDefault ["physicalRefs",[]]) select {!isNull _x && {alive _x} && {local _x}};
                        private _launcher = if (count _launchers > 0) then {([_launchers,[],{_x distance2D _munition},"ASCEND"] call BIS_fnc_sortBy) select 0} else {objNull};
                        if (!isNull _launcher) then {_interceptorAmmo = [typeOf _launcher] call DRO2026_fnc_resolveLauncherAmmo};
                        if (_interceptorAmmo == "" || {!isClass (configFile >> "CfgAmmo" >> _interceptorAmmo)}) then {
                            if (isClass (configFile >> "CfgAmmo" >> "M_Titan_AA")) then {_interceptorAmmo = "M_Titan_AA"};
                        };
                        if (_interceptorAmmo != "") then {
                            [_nodeId,"AA_MISSILES",-1,"STRATEGIC_INTERCEPT_LAUNCH"] call DRO2026_fnc_changeNetworkNodeStock;
                            _record set ["engagements",_engagements + 1];
                            _record set ["lastEngagementAt",time];
                            private _launchASL = if (!isNull _launcher) then {getPosASL _launcher vectorAdd [0,0,4]} else {_nodeASL vectorAdd [0,0,18]};
                            private _interceptor = createVehicle [_interceptorAmmo,ASLToAGL _launchASL,[],0,"CAN_COLLIDE"];
                            if (!isNull _interceptor) then {
                                _interceptor setPosASL _launchASL;
                                private _speed = 420;
                                private _rangeFactor = linearConversion [_range * 0.88,1800,_distance,0.55,1,true];
                                private _profilePK = if (_profile in ["ISKANDER","BALLISTIC"]) then {0.42} else {if (_profile in ["FP5","FLAMINGO"]) then {0.64} else {0.72}};
                                private _pKill = (_profilePK * (0.45 + 0.55 * _radarFactor) * (0.55 + 0.45 * _commandFactor) * _rangeFactor * (if (_engagements > 0) then {0.82} else {1})) max 0.08 min 0.86;
                                private _willKill = random 1 < _pKill;
                                private _missOffset = if (_willKill) then {[0,0,0]} else {[35 + random 95,-70 + random 140,-25 + random 80]};
                                ["MISSILE_DEFENCE_ENGAGED",createHashMapFromArray [
                                    ["munitionId",_record getOrDefault ["id",""]],["nodeId",_nodeId],
                                    ["interceptorAmmo",_interceptorAmmo],["pKill",_pKill],["engagement",_engagements + 1]
                                ],_record getOrDefault ["id",""]] call DRO2026_fnc_emitEvent;
                                [_interceptor,_munition,_record,_nodeId,_speed,_willKill,_missOffset] spawn {
                                    params ["_interceptor","_munition","_record","_nodeId","_speed","_willKill","_missOffset"];
                                    private _deadline = time + 42;
                                    private _closest = 1e9;
                                    while {!isNull _interceptor && {!isNull _munition} && {time < _deadline} && {!(_record getOrDefault ["intercepted",false])}} do {
                                        private _targetASL = getPosASL _munition vectorAdd _missOffset;
                                        private _delta = _targetASL vectorDiff getPosASL _interceptor;
                                        private _length = vectorMagnitude _delta;
                                        _closest = _closest min _length;
                                        if (_length > 0.1) then {
                                            private _direction = _delta vectorMultiply (1 / _length);
                                            private _right = _direction vectorCrossProduct [0,0,1];
                                            if (vectorMagnitude _right < 0.01) then {_right = [1,0,0]};
                                            _right = _right vectorMultiply (1 / ((vectorMagnitude _right) max 0.01));
                                            private _up = _right vectorCrossProduct _direction;
                                            _interceptor setVectorDirAndUp [_direction,_up];
                                            _interceptor setVelocity (_direction vectorMultiply _speed);
                                        };
                                        if (_willKill && {_length < 24}) exitWith {
                                            _record set ["intercepted",true];
                                            _record set ["interceptedBy",_nodeId];
                                            _record set ["state","INTERCEPTED"];
                                            _munition setVariable ["DRO2026_intercepted",true,true];
                                            [_record,getPosASL _munition,"INTERCEPTED"] call DRO2026_fnc_resolveStrategicImpact;
                                            deleteVehicle _munition;
                                            triggerAmmo _interceptor;
                                        };
                                        if (!_willKill && {_closest < 70} && {_length > (_closest + 45)}) exitWith {};
                                        sleep 0.06;
                                    };
                                    if (!isNull _interceptor) then {deleteVehicle _interceptor};
                                    if (!_willKill && {!(_record getOrDefault ["intercepted",false])}) then {
                                        ["MISSILE_DEFENCE_MISSED",createHashMapFromArray [["munitionId",_record getOrDefault ["id",""]],["nodeId",_nodeId],["closestApproach",_closest]],_record getOrDefault ["id",""]] call DRO2026_fnc_emitEvent;
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    } forEach _registry;
    sleep 0.75;
};