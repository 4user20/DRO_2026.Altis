params ["_origin", "_contact", ["_side", east], ["_operator", objNull], ["_allowPlayerControl", false]];
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {objNull};
if (!isNull _operator && {!alive _operator}) exitWith {objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetPos = _contact getOrDefault ["position", []];
if (count _targetPos < 2) exitWith {objNull};
if (!isNull _target && {!alive _target}) exitWith {objNull};

private _role = switch (_side) do {case west: {"FPV_WEST"}; case resistance: {"FPV_GUER"}; default {"FPV_EAST"}};
private _fallback = switch (_side) do {case west: {"B_UAV_01_F"}; case resistance: {"I_UAV_01_F"}; default {"O_UAV_01_F"}};
private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
private _isArmored = !isNull _target && {(_target isKindOf "Tank") || {_target isKindOf "Wheeled_APC_F"} || {_target isKindOf "Tracked_APC_F"}};
private _isMan = !isNull _target && {_target isKindOf "Man"};
private _preferred = _pool select {
    private _n = toLowerANSI _x;
    if (_isArmored) then {(_n find "pg7vl") >= 0} else {
        if (_isMan) then {(_n find "og7v") >= 0 || {(_n find "rkg") >= 0}} else {(_n find "ied") >= 0 || {(_n find "og7v") >= 0}}
    }
};
private _droneClass = if (count _preferred > 0) then {selectRandom _preferred} else {if (count _pool > 0) then {selectRandom _pool} else {_fallback}};
if (!isClass (configFile >> "CfgVehicles" >> _droneClass) || {!(_droneClass isKindOf "Air")}) then {_droneClass = _fallback};
private _usingNativeFPV = _droneClass != _fallback;

private _dir = _origin getDir _targetPos;
private _spawnPos = _origin getPos [25 + random 20, _dir];
_spawnPos set [2, 18 + random 8];
private _drone = createVehicle [_droneClass, _spawnPos, [], 0, "FLY"];
if (isNull _drone) exitWith {objNull};
private _crewGroup = _side createVehicleCrew _drone;
_drone setDir _dir;
_drone setVariable ["DRO2026_operator", _operator];
_drone setVariable ["DRO2026_manualControl", false];
_drone setVariable ["DRO2026_supportOwner", if (_allowPlayerControl) then {player} else {objNull}];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _drone]};
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
if (!isNull _crewGroup) then {_crewGroup setBehaviourStrong "CARELESS"; _crewGroup setCombatMode "BLUE"; _crewGroup setSpeedMode "FULL"};
[_drone, "FPV", _side] spawn DRO2026_fnc_trackIncomingDrone;

private _manualAction = -1;
if (_allowPlayerControl && {hasInterface} && {_side == playersSide}) then {
    _manualAction = player addAction [
        "<t color='#80d8ff'>Взять вызванный FPV под управление</t>",
        {
            params ["_targetObject", "_caller", "_actionId", "_arguments"];
            _arguments params ["_uav"];
            if (isNull _uav || {!alive _uav}) exitWith {};
            private _connected = _caller connectTerminalToUAV _uav;
            if (!_connected) exitWith {systemChat "Штаб: подключение не удалось. Установите совместимый UAV Terminal в слот навигации."};
            _uav setVariable ["DRO2026_manualControl", true];
            _caller action ["UAVTerminalOpen", _caller];
            systemChat "Штаб: Управление FPV передано оператору. После выхода из терминала автопилот продолжит полёт.";
        },
        [_drone], 8, false, true, "", "alive _target", 8
    ];
};

private _timeout = time + 210;
private _lastTargetSearch = -10;
private _lastWobbleUpdate = -10;
private _wobbleBearing = 0;
while {alive _drone && {time < _timeout}} do {
    private _manual = _drone getVariable ["DRO2026_manualControl", false];
    if (_manual && {hasInterface} && {getConnectedUAV player != _drone}) then {
        _drone setVariable ["DRO2026_manualControl", false];
        _manual = false;
    };

    if (!_manual) then {
        if (!isNull _target && {alive _target}) then {
            _targetPos = getPosATL _target;
        } else {
            // A stale contact does not make the FPV omniscient. It searches only in the last known local area.
            if ((time - _lastTargetSearch) > 2.5) then {
                _lastTargetSearch = time;
                private _candidates = nearestObjects [_targetPos, ["LandVehicle", "Man"], 180, true] select {
                    alive _x && {
                        private _objSide = side _x;
                        if (!isNull (driver _x)) then {_objSide = side (group (driver _x))};
                        _objSide != _side && {_objSide != civilian}
                    }
                };
                if (count _candidates > 0) then {
                    _candidates = [_candidates, [], {_x distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
                    _target = _candidates select 0;
                    _targetPos = getPosATL _target;
                };
            };
        };

        if ((time - _lastWobbleUpdate) > (0.7 + random 0.8)) then {
            _lastWobbleUpdate = time;
            _wobbleBearing = -4 + random 8;
        };
        private _distance = _drone distance2D _targetPos;
        private _aim = [_drone, _targetPos, 20, [70, 140, 240], 260, if (_distance > 400) then {7} else {2.5}] call DRO2026_fnc_calculateTerrainAwareAim;
        private _currentAGL = ASLToAGL (getPosASL _drone);
        private _aimAGL = ASLToAGL _aim;
        if (_distance > 300 && {_wobbleBearing != 0}) then {
            private _b = _currentAGL getDir _aimAGL;
            private _offset = _currentAGL getPos [(_currentAGL distance2D _aimAGL) min 120, _b + _wobbleBearing];
            private _offsetASL = AGLToASL _offset;
            _offsetASL set [2, _aim select 2];
            _aim = _offsetASL;
        };
        private _delta = _aim vectorDiff getPosASL _drone;
        private _length = vectorMagnitude _delta;
        if (_length > 0.1) then {
            private _vector = _delta vectorMultiply (1 / _length);
            private _speed = if (_distance > 450) then {38 + random 5} else {31 + random 7};
            _drone setVectorDirAndUp [_vector, [0,0,1]];
            _drone setVelocity (_vector vectorMultiply _speed);
        };
        if (_distance < 4.2) exitWith {
            if (_usingNativeFPV) then {
                // Trigger the addon vehicle's own Killed/Hit handling. No injected Titan warhead and no double explosion.
                _drone setDamage 1;
            } else {
                private _ammoPool = DRO2026_ammoRegistry getOrDefault ["FPV_AT_AMMO", []];
                if (_isArmored && {count _ammoPool > 0}) then {
                    private _ammo = createVehicle [selectRandom _ammoPool, getPosATL _drone, [], 0, "CAN_COLLIDE"];
                    _ammo setVelocity velocity _drone;
                } else {
                    createVehicle ["GrenadeHand", getPosATL _drone, [], 0, "CAN_COLLIDE"];
                };
                _drone setDamage 1;
            };
        };
    };
    sleep (if ((_drone distance2D _targetPos) > 500) then {0.32} else {0.22});
};
if (_manualAction >= 0 && {hasInterface}) then {player removeAction _manualAction};
if (alive _drone) then {deleteVehicleCrew _drone; deleteVehicle _drone};
_drone
