if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_pointDefenceDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_pointDefenceDirectorStarted",true];
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _airCandidates = (vehicles select {!isNull _x && {alive _x} && {_x isKindOf "Air"}}) + (DRO2026_activeDrones select {!isNull _x && {alive _x}});
    _airCandidates = _airCandidates arrayIntersect _airCandidates;
    private _sites = DRO2026_sites select {
        (_x getOrDefault ["type",""]) == "POINT_DEFENCE" &&
        {!((toUpperANSI (_x getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])}
    };
    {
        private _site = _x;
        private _vehicle = _site getOrDefault ["object",objNull];
        private _nodeId = _site getOrDefault ["networkNodeId",""];
        private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
        private _stocks = _node getOrDefault ["stocks",createHashMap];
        private _stock = _stocks getOrDefault ["POINT_DEFENCE_AMMO",0];
        private _gunner = if (isNull _vehicle) then {objNull} else {gunner _vehicle};
        private _operational = !isNull _vehicle && {alive _vehicle} && {canFire _vehicle} && {_stock > 0} && {
            !((toUpperANSI (_node getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])
        };
        if (_operational) then {
            if (!someAmmo _vehicle && {local _vehicle}) then {
                _vehicle setVehicleAmmo 1;
                ["POINT_DEFENCE_REARMED",createHashMapFromArray [
                    ["nodeId",_nodeId],["asset",typeOf _vehicle],["abstractStock",_stock]
                ],_nodeId] call DRO2026_fnc_emitEvent;
            };
            private _siteSide = _site getOrDefault ["side",enemySide];
            private _hostileSide = if (_siteSide == enemySide) then {playersSide} else {enemySide};
            private _targets = [];
            {
                private _air = _x;
                if (!isNull _air && {alive _air} && {_air isKindOf "Air"} && {_air distance2D _vehicle <= 2600}) then {
                    private _launchSide = _air getVariable ["DRO2026_launchSide",sideUnknown];
                    private _airSide = side _air;
                    if (count crew _air > 0) then {_airSide = side (group ((crew _air) select 0))};
                    if (_launchSide == _hostileSide || {_airSide == _hostileSide}) then {
                        private _priority = if (_air getVariable ["DRO2026_decoy",false]) then {0.45} else {1};
                        if (_air isKindOf "Plane") then {_priority = _priority + 0.15};
                        _targets pushBack [_air,_priority,_air distance2D _vehicle];
                    };
                };
            } forEach _airCandidates;
            {
                private _munition = _x getOrDefault ["object",objNull];
                if (!isNull _munition && {(_x getOrDefault ["launchSide",sideUnknown]) == _hostileSide} && {_munition distance2D _vehicle <= 2100}) then {
                    _targets pushBack [_munition,1.25,_munition distance2D _vehicle];
                };
            } forEach (missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]]);
            if (count _targets > 0 && {!isNull _gunner}) then {
                _targets = [_targets,[],{-((_x select 1) - ((_x select 2) / 5000))},"ASCEND"] call BIS_fnc_sortBy;
                private _target = (_targets select 0) select 0;
                private _group = group _gunner;
                _group setCombatMode "RED";
                _gunner enableAI "TARGET";
                _gunner enableAI "AUTOTARGET";
                _vehicle reveal [_target,4];
                _gunner doTarget _target;
                if (_vehicle aimedAtTarget [_target] > 0.08) then {
                    private _fired = _vehicle fireAtTarget [_target];
                    if (!_fired) then {_gunner doFire _target};
                };
            } else {
                if (!isNull _gunner) then {
                    _gunner doTarget objNull;
                    _gunner doWatch objNull;
                    _gunner disableAI "AUTOTARGET";
                    (group _gunner) setCombatMode "BLUE";
                };
            };
        } else {
            if (!isNull _vehicle && {local _vehicle} && {_stock <= 0} && {someAmmo _vehicle}) then {_vehicle setVehicleAmmo 0};
            if (!isNull _gunner) then {
                _gunner doTarget objNull;
                _gunner doWatch objNull;
                _gunner disableAI "TARGET";
                _gunner disableAI "AUTOTARGET";
                (group _gunner) setCombatMode "BLUE";
            };
        };
    } forEach _sites;
    private _budget = missionNamespace getVariable ["DRO2026_spawnBudgetFactor",1];
    sleep (2.25 + ((1 - _budget) * 2.75));
};