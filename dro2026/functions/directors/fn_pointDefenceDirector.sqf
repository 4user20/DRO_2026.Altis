if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_pointDefenceDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_pointDefenceDirectorStarted",true];
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _sites = DRO2026_sites select {(_x getOrDefault ["type",""]) == "POINT_DEFENCE" && {!((_x getOrDefault ["status","ACTIVE"]) in ["DESTROYED","DISABLED","CANCELLED"])}};
    {
        private _site = _x;
        private _vehicle = _site getOrDefault ["object",objNull];
        private _nodeId = _site getOrDefault ["networkNodeId",""];
        private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
        private _stocks = _node getOrDefault ["stocks",createHashMap];
        private _stock = _stocks getOrDefault ["POINT_DEFENCE_AMMO",0];
        if (!isNull _vehicle && {alive _vehicle} && {_stock > 0} && {!((toUpperANSI (_node getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])}) then {
            private _siteSide = _site getOrDefault ["side",enemySide];
            private _hostileSide = if (_siteSide == enemySide) then {playersSide} else {enemySide};
            private _targets = [];
            {
                private _air = _x;
                if (!isNull _air && {alive _air} && {_air distance2D _vehicle <= 2600}) then {
                    private _launchSide = _air getVariable ["DRO2026_launchSide",sideUnknown];
                    private _airSide = side _air;
                    if (count crew _air > 0) then {_airSide = side (group ((crew _air) select 0))};
                    if (_launchSide == _hostileSide || {_airSide == _hostileSide}) then {
                        private _priority = if (_air getVariable ["DRO2026_decoy",false]) then {0.45} else {1};
                        _targets pushBack [_air,_priority,_air distance2D _vehicle];
                    };
                };
            } forEach ((DRO2026_activeDrones + vehicles) arrayIntersect (DRO2026_activeDrones + vehicles));
            {
                private _munition = _x getOrDefault ["object",objNull];
                if (!isNull _munition && {(_x getOrDefault ["launchSide",sideUnknown]) == _hostileSide} && {_munition distance2D _vehicle <= 2100}) then {
                    _targets pushBack [_munition,1.25,_munition distance2D _vehicle];
                };
            } forEach (missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]]);
            if (count _targets > 0) then {
                _targets = [_targets,[],{-((_x select 1) - ((_x select 2) / 5000))},"ASCEND"] call BIS_fnc_sortBy;
                private _target = (_targets select 0) select 0;
                private _gunner = gunner _vehicle;
                if (!isNull _gunner) then {
                    _gunner enableAI "TARGET";
                    _gunner enableAI "AUTOTARGET";
                    _vehicle reveal [_target,4];
                    _gunner doTarget _target;
                    if (canFire _vehicle && {_vehicle aimedAtTarget [_target] > 0.08}) then {
                        private _fired = _vehicle fireAtTarget [_target];
                        if (!_fired) then {_gunner doFire _target};
                    };
                };
            };
        } else {
            if (!isNull _vehicle && {!isNull gunner _vehicle}) then {(gunner _vehicle) disableAI "AUTOTARGET"};
        };
    } forEach _sites;
    sleep 1.5;
};