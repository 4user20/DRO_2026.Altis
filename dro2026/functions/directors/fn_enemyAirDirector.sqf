if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep (300 + random 260);
    if (DRO2026_alertLevel < 0.62 || {DRO2026_fpsAverage < 25}) then {continue};

    private _enemySideNumber = switch (enemySide) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
    private _pool = (DRO2026_assetRegistry getOrDefault ["ENEMY_CAS_AIR", []]) select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg &&
        {_x isKindOf "Air"} &&
        {_enemySideNumber < 0 || {getNumber (_cfg >> "side") == _enemySideNumber}}
    };
    if (count _pool == 0) then {continue};

    private _groundTargets = [];
    {
        private _target = _x getOrDefault ["target", objNull];
        if (!isNull _target && {alive _target} && {(_x getOrDefault ["owner", ""]) == "ENEMY"} && {(_x getOrDefault ["confidence", 0]) >= 0.72} && {(time - (_x getOrDefault ["lastSeen", 0])) < 260}) then {
            _groundTargets pushBackUnique _target;
        };
    } forEach DRO2026_contacts;

    private _airTargets = DRO2026_activeDrones select {
        !isNull _x && {alive _x} && {
            private _crew = crew _x;
            count _crew > 0 && {side (group (_crew select 0)) == playersSide}
        }
    };
    private _humanPlayers = allPlayers select {!(_x isKindOf "VirtualMan_F")};
    {
        if (!isNull _x && {alive _x}) then {
            private _playerVehicle = vehicle _x;
            if (!isNull _playerVehicle && {alive _playerVehicle}) then {
                if (_playerVehicle isKindOf "Air") then {
                    _airTargets pushBackUnique _playerVehicle;
                } else {
                    _groundTargets pushBackUnique _playerVehicle;
                };
            };
        };
    } forEach _humanPlayers;

    private _su57Available = enemySide == east && {"RUS_VKS_su57" in _pool};
    private _class = if (count _airTargets > 0 && {_su57Available} && {random 1 > 0.55}) then {"RUS_VKS_su57"} else {selectRandom _pool};
    private _targetPool = if ((toLowerANSI _class find "su57") >= 0 && {count _airTargets > 0}) then {_airTargets} else {_groundTargets};
    if (count _targetPool == 0) then {continue};
    private _target = selectRandom _targetPool;
    if (isNull _target || {!alive _target}) then {continue};

    private _targetPos = getPosATL _target;
    private _spawn = _targetPos getPos [9500 + random 3000, 80 + (-15 + random 30)];
    private _isHeli = _class isKindOf "Helicopter";
    private _alt = if (_isHeli) then {240} else {620 + random 220};
    _spawn set [2, _alt];
    private _spawnDirection = _spawn getDir _targetPos;
    private _air = createVehicle [_class, _spawn, [], 0, "FLY"];
    if (isNull _air) then {continue};
    // BI's FLY special only guarantees airborne placement when crew already exists.
    // This vehicle is created empty, so set direction before explicit ATL position.
    _air setDir _spawnDirection;
    _air setPosATL _spawn;

    private _grp = enemySide createVehicleCrew _air;
    if (isNull _grp || {isNull (driver _air)}) then {
        deleteVehicleCrew _air;
        deleteVehicle _air;
        if (!isNull _grp) then {deleteGroup _grp};
        continue;
    };

    [_grp, false] call DRO2026_fnc_registerManagedGroup;
    _grp setBehaviourStrong "COMBAT";
    _grp setCombatMode "RED";
    _grp setSpeedMode "FULL";
    private _initialSpeed = if (_isHeli) then {38} else {145};
    _air setVelocity [sin _spawnDirection * _initialSpeed, cos _spawnDirection * _initialSpeed, 0];
    DRO2026_managedVehicles pushBackUnique _air;
    _air flyInHeight (if (_isHeli) then {110} else {430});
    _air reveal [_target, 4];
    (driver _air) doTarget _target;
    (driver _air) doMove _targetPos;

    [_air, _target, _targetPos, _grp] spawn {
        params ["_air", "_target", "_targetPos", "_grp"];
        private _deadline = time + 260;
        private _engaged = false;
        private _lastFireOrder = -10;
        while {alive _air && {time < _deadline} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
            if (!isNull _target && {alive _target}) then {
                _targetPos = getPosATL _target;
                private _driver = driver _air;
                if (!isNull _driver) then {
                    _driver doTarget _target;
                    if (_air distance2D _target < 2600 && {(time - _lastFireOrder) > 6}) then {
                        _lastFireOrder = time;
                        _engaged = true;
                        _driver doFire _target;
                        private _gunner = gunner _air;
                        if (!isNull _gunner && {_gunner != _driver}) then {
                            _gunner doTarget _target;
                            _gunner doFire _target;
                        };
                    };
                };
            };
            if (_engaged && {(isNull _target || {!alive _target}) || {_air distance2D _targetPos < 500}}) exitWith {};
            sleep 1;
        };
        private _egress = _targetPos getPos [10000, 270 + (-15 + random 30)];
        _egress set [2, if (_air isKindOf "Helicopter") then {300} else {760}];
        if (!isNull (driver _air)) then {(driver _air) doMove _egress};
        private _exitDeadline = time + 180;
        waitUntil {
            sleep 2;
            !alive _air ||
            {_air distance2D _targetPos > 8500} ||
            {time > _exitDeadline} ||
            {missionNamespace getVariable ["DRO2026_missionEnding", false]}
        };
        if (!isNull _air) then {
            deleteVehicleCrew _air;
            if (alive _air) then {deleteVehicle _air};
        };
        if (!isNull _grp) then {deleteGroup _grp};
    };
};