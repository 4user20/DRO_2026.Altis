if (!isServer) exitWith {};
while {!DRO2026_missionEnding} do {
    sleep (300 + random 260);
    if (DRO2026_alertLevel < 0.62 || {DRO2026_fpsAverage < 25}) then {continue};
    private _pool = DRO2026_assetRegistry getOrDefault ["AIR_EAST", []];
    if (count _pool == 0) then {continue};

    private _groundTargets = [];
    {
        private _target = _x getOrDefault ["target", objNull];
        if (!isNull _target && {alive _target} && {(_x getOrDefault ["owner", ""]) == "ENEMY"} && {(_x getOrDefault ["confidence", 0]) >= 0.72} && {(time - (_x getOrDefault ["lastSeen", 0])) < 260}) then {
            _groundTargets pushBackUnique _target;
        };
    } forEach DRO2026_contacts;
    if (alive player) then {_groundTargets pushBackUnique (vehicle player)};

    private _airTargets = DRO2026_activeDrones select {
        !isNull _x && {alive _x} && {
            private _crew = crew _x;
            count _crew > 0 && {side (group (_crew select 0)) == playersSide}
        }
    };
    if ((vehicle player) isKindOf "Air" && {alive (vehicle player)}) then {_airTargets pushBackUnique vehicle player};

    private _class = if (count _airTargets > 0 && {isClass (configFile >> "CfgVehicles" >> "RUS_VKS_su57")} && {random 1 > 0.55}) then {"RUS_VKS_su57"} else {selectRandom _pool};
    private _targetPool = if ((toLowerANSI _class find "su57") >= 0 && {count _airTargets > 0}) then {_airTargets} else {_groundTargets};
    if (count _targetPool == 0) then {continue};
    private _target = selectRandom _targetPool;
    private _targetPos = getPosATL _target;
    private _spawn = _targetPos getPos [9500 + random 3000, 80 + (-15 + random 30)];
    private _isHeli = _class isKindOf "Helicopter";
    private _alt = if (_isHeli) then {240} else {620 + random 220};
    _spawn set [2, _alt];
    private _air = createVehicle [_class, _spawn, [], 0, "FLY"];
    if (isNull _air) then {continue};
    private _grp = enemySide createVehicleCrew _air;
    if (!isNull _grp) then {
        [_grp, false] call DRO2026_fnc_registerManagedGroup;
        _grp setBehaviourStrong "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";
    };
    DRO2026_managedVehicles pushBackUnique _air;
    _air flyInHeight (if (_isHeli) then {110} else {430});
    _air reveal [_target, 4];
    if (!isNull (driver _air)) then {
        (driver _air) doTarget _target;
        (driver _air) doMove _targetPos;
    };
    [_air, _target, _targetPos] spawn {
        params ["_air", "_target", "_targetPos"];
        private _deadline = time + 260;
        private _engaged = false;
        while {alive _air && {time < _deadline}} do {
            if (!isNull _target && {alive _target}) then {
                _targetPos = getPosATL _target;
                if (!isNull (driver _air)) then {(driver _air) doTarget _target};
                if (!_engaged && {_air distance2D _target < 2600}) then {
                    _engaged = true;
                    _air fireAtTarget [_target];
                };
            };
            if (_engaged && {(isNull _target || {!alive _target}) || {_air distance2D _targetPos < 500}}) exitWith {};
            sleep 1;
        };
        private _egress = _targetPos getPos [10000, 270 + (-15 + random 30)];
        _egress set [2, if (_air isKindOf "Helicopter") then {300} else {760}];
        if (!isNull (driver _air)) then {(driver _air) doMove _egress};
        private _exitDeadline = time + 180;
        waitUntil {sleep 2; !alive _air || {_air distance2D _targetPos > 8500} || {time > _exitDeadline}};
        if (alive _air) then {deleteVehicleCrew _air; deleteVehicle _air};
    };
};
