params [
    "_origin", "_contact", ["_side", east], ["_operator", objNull],
    ["_allowPlayerControl", false], ["_supportOwner", objNull], ["_requestedClass", ""],
    ["_reservationNodeId", ""]
];
private _refundReservation = {
    if (_side == playersSide) then {
        DRO2026_resources set ["friendlyFPVStock", (DRO2026_resources getOrDefault ["friendlyFPVStock", 0]) + 1];
    } else {
        if (_reservationNodeId != "") then {
            [_reservationNodeId, "FPV_KITS", 1, "FPV_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
            [_reservationNodeId, "BATTERIES", 1, "FPV_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
            DRO2026_resources set ["enemyDroneStock", (DRO2026_resources getOrDefault ["enemyDroneStock", 0]) + 1];
        };
    };
};
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {call _refundReservation; objNull};
if (!isNull _operator && {!alive _operator}) exitWith {call _refundReservation; objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetPosition = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
if (count _targetPosition < 2) exitWith {call _refundReservation; objNull};
if (!isNull _target && {!alive _target}) exitWith {call _refundReservation; objNull};

private _role = switch (_side) do {
    case west: {"FPV_WEST"};
    case resistance: {"FPV_GUER"};
    default {"FPV_EAST"};
};
private _fallback = switch (_side) do {
    case west: {"B_UAV_01_F"};
    case resistance: {"I_UAV_01_F"};
    default {"O_UAV_01_F"};
};
private _sideNumber = switch (_side) do {case east: {0}; case west: {1}; case resistance: {2}; default {-1}};
private _pool = (DRO2026_assetRegistry getOrDefault [_role, []]) select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg &&
    {_x isKindOf "Air"} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
};
if (_requestedClass != "" && {!(_requestedClass in _pool)}) exitWith {
    [format ["FPV exact class %1 отсутствует в side-correct registry", _requestedClass]] call DRO2026_fnc_log;
    call _refundReservation;
    objNull
};
private _isArmored = !isNull _target && {
    (_target isKindOf "Tank") || {_target isKindOf "Wheeled_APC_F"} || {_target isKindOf "Tracked_APC_F"}
};
private _isMan = !isNull _target && {_target isKindOf "Man"};
private _preferred = _pool select {
    private _name = toLowerANSI _x;
    if (_isArmored) then {
        (_name find "pg7vl") >= 0
    } else {
        if (_isMan) then {
            (_name find "og7v") >= 0 || {(_name find "rkg") >= 0}
        } else {
            (_name find "ied") >= 0 || {(_name find "og7v") >= 0}
        }
    }
};
private _droneClass = if (_requestedClass != "") then {
    _requestedClass
} else {
    if (count _preferred > 0) then {selectRandom _preferred} else {if (count _pool > 0) then {selectRandom _pool} else {_fallback}}
};
private _droneCfg = configFile >> "CfgVehicles" >> _droneClass;
if (!isClass _droneCfg || {!(_droneClass isKindOf "Air")} || {_sideNumber >= 0 && {getNumber (_droneCfg >> "side") != _sideNumber}}) exitWith {
    [format ["FPV launch cancelled: invalid or cross-side class %1", _droneClass]] call DRO2026_fnc_log;
    call _refundReservation;
    objNull
};
private _usingNativeFPV = _droneClass != _fallback;

private _direction = _origin getDir _targetPosition;
private _spawnPosition = _origin getPos [25 + random 20, _direction];
_spawnPosition set [2, 18 + random 8];
private _drone = createVehicle [_droneClass, _spawnPosition, [], 0, "FLY"];
if (isNull _drone) exitWith {call _refundReservation; objNull};
_drone setPosATL _spawnPosition;
private _crewGroup = _side createVehicleCrew _drone;
if (isNull _crewGroup || {isNull (driver _drone)}) exitWith {
    deleteVehicleCrew _drone;
    deleteVehicle _drone;
    if (!isNull _crewGroup) then {deleteGroup _crewGroup};
    call _refundReservation;
    objNull
};
private _driver = driver _drone;
_driver disableAI "MOVE";
_driver disableAI "PATH";
_driver disableAI "TARGET";
_driver disableAI "AUTOTARGET";
_drone setVariable ["DRO2026_operator", _operator];
_drone setVariable ["DRO2026_manualControl", false, true];
_drone setVariable ["DRO2026_supportOwner", _supportOwner, true];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _drone]};
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
_crewGroup setBehaviourStrong "CARELESS";
_crewGroup setCombatMode "BLUE";
_crewGroup setSpeedMode "FULL";
private _initialDirection = [sin _direction, cos _direction, 0];
_drone setVelocity (_initialDirection vectorMultiply 24);
[_drone, format ["FPV %1", getText (_droneCfg >> "displayName")], _side] spawn DRO2026_fnc_trackIncomingDrone;

if (_allowPlayerControl && {!isNull _supportOwner} && {_side == playersSide}) then {
    [_drone] remoteExecCall ["DRO2026_fnc_offerFPVControl", _supportOwner, false];
};

private _applyFlightVector = {
    params ["_object", "_rawDirection", "_speed"];
    private _dirLength = vectorMagnitude _rawDirection;
    if (_dirLength <= 0.001) exitWith {};
    private _flightDirection = _rawDirection vectorMultiply (1 / _dirLength);
    private _right = _flightDirection vectorCrossProduct [0,0,1];
    private _rightLength = vectorMagnitude _right;
    if (_rightLength <= 0.001) then {_right = [1,0,0]; _rightLength = 1};
    _right = _right vectorMultiply (1 / _rightLength);
    private _up = _right vectorCrossProduct _flightDirection;
    private _upLength = vectorMagnitude _up;
    if (_upLength <= 0.001) then {_up = [0,0,1]} else {_up = _up vectorMultiply (1 / _upLength)};
    _object setVectorDirAndUp [_flightDirection, _up];
    _object setVelocity (_flightDirection vectorMultiply _speed);
};

private _timeout = time + 210;
private _lastWobbleUpdate = -10;
private _wobbleBearing = 0;
private _guidanceLostUntil = -1;
private _operatorQuality = if (!isNull _operator) then {0.65 + ((skill _operator) * 0.35)} else {0.72};
private _hadPhysicalTarget = !isNull _target;
private _targetLostAt = -1;

while {
    alive _drone &&
    {time < _timeout} &&
    {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}
} do {
    private _manual = _drone getVariable ["DRO2026_manualControl", false];
    if (!_manual) then {
        if (!isNull _target && {alive _target}) then {
            _targetPosition = getPosATL _target;
            _targetLostAt = -1;
        } else {
            if (_hadPhysicalTarget && {_targetLostAt < 0}) then {
                _targetLostAt = time;
                [format ["FPV сохраняет последнюю подтверждённую точку после потери цели %1", _contact getOrDefault ["id", ""]]] call DRO2026_fnc_log;
            };
        };

        private _distance = _drone distance2D _targetPosition;
        private _tick = if (_distance > 500) then {0.32} else {0.22};
        private _ewPressure = if (_side == playersSide) then {DRO2026_resources getOrDefault ["enemyEW", 0]} else {0};
        private _channelQuality = linearConversion [0, 100, _ewPressure, 1, DRO2026_FPV_MIN_CHANNEL_QUALITY, true];
        _channelQuality = (_channelQuality * _operatorQuality) max DRO2026_FPV_MIN_CHANNEL_QUALITY;

        if (_channelQuality < 0.68 && {time > _guidanceLostUntil} && {random 1 < ((1 - _channelQuality) * 0.012)}) then {
            _guidanceLostUntil = time + 0.6 + random 2.2;
        };
        if ((time - _lastWobbleUpdate) > (0.7 + random 0.8)) then {
            _lastWobbleUpdate = time;
            private _jitter = 4 + ((1 - _channelQuality) * 10);
            _wobbleBearing = -_jitter + random (_jitter * 2);
        };

        if (time > _guidanceLostUntil) then {
            private _lateralNoise = if (_distance > 400) then {7} else {2.5};
            _lateralNoise = _lateralNoise + ((1 - _channelQuality) * 8);
            private _aimASL = [
                _drone, _targetPosition, 20,
                [70, 140, 240], 260, _lateralNoise
            ] call DRO2026_fnc_calculateTerrainAwareAim;
            private _currentAGL = ASLToAGL getPosASL _drone;
            private _aimAGL = ASLToAGL _aimASL;
            if (_distance > 300 && {_wobbleBearing != 0}) then {
                private _bearing = _currentAGL getDir _aimAGL;
                private _offset = _currentAGL getPos [(_currentAGL distance2D _aimAGL) min 120, _bearing + _wobbleBearing];
                private _offsetASL = AGLToASL _offset;
                _offsetASL set [2, _aimASL select 2];
                _aimASL = _offsetASL;
            };

            private _delta = _aimASL vectorDiff getPosASL _drone;
            private _deltaLength = vectorMagnitude _delta;
            if (_deltaLength > 0.1) then {
                private _desiredDirection = _delta vectorMultiply (1 / _deltaLength);
                private _currentVelocity = velocity _drone;
                private _currentSpeed = vectorMagnitude _currentVelocity;
                private _currentDirection = if (_currentSpeed > 2) then {
                    _currentVelocity vectorMultiply (1 / _currentSpeed)
                } else {
                    vectorDir _drone
                };
                private _dot = (_currentDirection vectorDotProduct _desiredDirection) max -1 min 1;
                private _turnAngle = acos _dot;
                private _maxTurnStep = DRO2026_FPV_MAX_TURN_RATE * _tick * _channelQuality;
                private _responseCap = (DRO2026_FPV_BASE_RESPONSE * (0.8 + 0.4 * _channelQuality)) min 0.42;
                private _blend = if (_turnAngle > 0.01) then {(_maxTurnStep / _turnAngle) min _responseCap} else {1};
                private _blended = (_currentDirection vectorMultiply (1 - _blend)) vectorAdd (_desiredDirection vectorMultiply _blend);
                private _blendedLength = vectorMagnitude _blended;
                if (_blendedLength > 0.01) then {
                    private _newDirection = _blended vectorMultiply (1 / _blendedLength);
                    private _desiredSpeed = if (_distance > 450) then {40} else {33};
                    _desiredSpeed = _desiredSpeed * (0.88 + 0.12 * _channelQuality);
                    private _speedBlend = 0.16 + 0.18 * _channelQuality;
                    private _newSpeed = _currentSpeed + ((_desiredSpeed - _currentSpeed) * _speedBlend);
                    [_drone, _newDirection, _newSpeed] call _applyFlightVector;
                    private _closingSpeed = (velocity _drone) vectorDotProduct _desiredDirection;
                    if (_distance < 5.2 && {_closingSpeed > 6}) then {
                        if (_usingNativeFPV) then {
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
            };
        };
        sleep _tick;
    } else {
        sleep 0.2;
    };
};

private _activeIndex = DRO2026_activeDrones find _drone;
if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
if (!isNull _drone) then {
    deleteVehicleCrew _drone;
    if (alive _drone) then {deleteVehicle _drone};
};
if (!isNull _crewGroup) then {deleteGroup _crewGroup};
_drone
