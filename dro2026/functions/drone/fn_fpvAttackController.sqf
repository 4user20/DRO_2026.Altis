params [
    ["_drone", objNull], ["_contact", createHashMap], ["_side", east], ["_operator", objNull],
    ["_usingNativeFPV", true], ["_isArmored", false], ["_siteId", ""]
];
if (!isServer || {isNull _drone} || {!alive _drone}) exitWith {"INVALID"};
if (_drone getVariable ["ddtTasked", false]) exitWith {"DDT_CONTROLLED"};
if (_drone getVariable ["dro2026_fpvInitialized", false]) exitWith {"ALREADY_RUNNING"};
_drone setVariable ["dro2026_fpvInitialized", true];

private _target = _contact getOrDefault ["target", objNull];
private _targetPosition = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
if (count _targetPosition < 2) exitWith {_drone setVariable ["dro2026_fpvInitialized", false]; "NO_TARGET"};
private _fiberOptic = [_drone] call DRO2026_fnc_isFiberOpticDrone;
private _timeout = time + 210;
private _lastDistance = 1e10;
private _lastProgressCheck = time;
private _stuckCount = 0;
private _guidanceLostUntil = -1;
private _lastWobbleUpdate = -10;
private _wobbleBearing = 0;
private _operatorQuality = if (!isNull _operator) then {0.65 + ((skill _operator) * 0.35)} else {0.72};
private _result = "ABORTED";

private _applyFlightVector = {
    params ["_object", "_rawDirection", "_speed"];
    private _length = vectorMagnitude _rawDirection;
    if (_length <= 0.001) exitWith {};
    private _direction = _rawDirection vectorMultiply (1 / _length);
    private _right = _direction vectorCrossProduct [0,0,1];
    private _rightLength = vectorMagnitude _right;
    if (_rightLength <= 0.001) then {_right = [1,0,0]; _rightLength = 1};
    _right = _right vectorMultiply (1 / _rightLength);
    private _up = _right vectorCrossProduct _direction;
    private _upLength = vectorMagnitude _up;
    if (_upLength <= 0.001) then {_up = [0,0,1]} else {_up = _up vectorMultiply (1 / _upLength)};
    _object setVectorDirAndUp [_direction, _up];
    _object setVelocity (_direction vectorMultiply _speed);
};

while {
    alive _drone && {time < _timeout} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} &&
    {_siteId == "" || {[_siteId] call DRO2026_fnc_isSiteOperational}}
} do {
    if (_drone getVariable ["ddtTasked", false]) exitWith {_result = "DDT_CONTROLLED"};
    if (_drone getVariable ["DRO2026_manualControl", false]) then {uiSleep 0.2; continue};
    if ([_drone] call DRO2026_fnc_isExternallyControlledUAV) exitWith {_result = "YIELDED"};

    if (!isNull _target && {alive _target}) then {
        private _targetVelocity = velocity _target;
        private _distanceToTarget = _drone distance _target;
        private _leadTime = linearConversion [0, 1200, _distanceToTarget, 0.18, 1.15, true];
        _targetPosition = (getPosATL _target) vectorAdd (_targetVelocity vectorMultiply _leadTime);
    };

    private _distance2D = _drone distance2D _targetPosition;
    private _distance3D = _drone distance _targetPosition;
    private _tick = if (_distance2D > 500) then {0.32} else {0.22};
    private _ewPressure = if (_fiberOptic) then {0} else {[getPosATL _drone, _side, _drone] call DRO2026_fnc_getJammingAtPosition};
    private _channelQuality = if (_fiberOptic) then {1} else {linearConversion [0, 1, _ewPressure, 1, DRO2026_FPV_MIN_CHANNEL_QUALITY, true]};
    _channelQuality = (_channelQuality * _operatorQuality) max DRO2026_FPV_MIN_CHANNEL_QUALITY;

    if (!_fiberOptic && {_channelQuality < 0.68} && {time > _guidanceLostUntil} && {random 1 < ((1 - _channelQuality) * 0.012)}) then {
        _guidanceLostUntil = time + 0.6 + random 2.2;
    };
    if ((time - _lastWobbleUpdate) > (0.7 + random 0.8)) then {
        _lastWobbleUpdate = time;
        private _jitter = if (_fiberOptic) then {2.5} else {4 + ((1 - _channelQuality) * 10)};
        _wobbleBearing = -_jitter + random (_jitter * 2);
    };

    if ((time - _lastProgressCheck) >= 8) then {
        private _progress = _lastDistance - _distance2D;
        if (_progress < (4 max (_lastDistance * 0.02))) then {
            _stuckCount = _stuckCount + 1;
            private _recovery = (getPosATL _drone) getPos [55, (getDir _drone) + selectRandom [-70, 70]];
            _recovery set [2, ((getPosATL _drone) select 2) + 16];
            (driver _drone) doMove _recovery;
        } else {
            _stuckCount = 0;
        };
        _lastDistance = _distance2D;
        _lastProgressCheck = time;
        if (_stuckCount >= 2) exitWith {_result = "STUCK"};
    };

    if (time > _guidanceLostUntil) then {
        private _lateralNoise = if (_distance2D > 400) then {7} else {2.5};
        if (_fiberOptic) then {_lateralNoise = _lateralNoise * 0.55} else {_lateralNoise = _lateralNoise + ((1 - _channelQuality) * 8)};
        private _attackHeight = linearConversion [0, 500, _distance2D, 3.5, 20, true];
        private _aimASL = [_drone, _targetPosition, _attackHeight, [70, 140, 240], 260, _lateralNoise] call DRO2026_fnc_calculateTerrainAwareAim;
        if (_distance2D > 300 && {_wobbleBearing != 0}) then {
            private _currentAGL = ASLToAGL getPosASL _drone;
            private _aimAGL = ASLToAGL _aimASL;
            private _offset = _currentAGL getPos [(_currentAGL distance2D _aimAGL) min 120, (_currentAGL getDir _aimAGL) + _wobbleBearing];
            private _offsetASL = AGLToASL _offset;
            _offsetASL set [2, _aimASL select 2];
            _aimASL = _offsetASL;
        };
        private _delta = _aimASL vectorDiff getPosASL _drone;
        private _deltaLength = vectorMagnitude _delta;
        if (_deltaLength > 0.1) then {
            private _desired = _delta vectorMultiply (1 / _deltaLength);
            private _currentVelocity = velocity _drone;
            private _currentSpeed = vectorMagnitude _currentVelocity;
            private _currentDirection = if (_currentSpeed > 2) then {_currentVelocity vectorMultiply (1 / _currentSpeed)} else {vectorDir _drone};
            private _turnAngle = acos (((_currentDirection vectorDotProduct _desired) max -1) min 1);
            private _maxTurnStep = DRO2026_FPV_MAX_TURN_RATE * _tick * _channelQuality;
            private _blend = if (_turnAngle > 0.01) then {(_maxTurnStep / _turnAngle) min 0.40} else {1};
            private _blended = (_currentDirection vectorMultiply (1 - _blend)) vectorAdd (_desired vectorMultiply _blend);
            private _blendedLength = vectorMagnitude _blended;
            if (_blendedLength > 0.01) then {
                private _newDirection = _blended vectorMultiply (1 / _blendedLength);
                private _desiredSpeed = if (_distance2D > 450) then {40} else {33};
                private _newSpeed = _currentSpeed + ((_desiredSpeed - _currentSpeed) * (0.16 + 0.18 * _channelQuality));
                [_drone, _newDirection, _newSpeed] call _applyFlightVector;
            };
        };
    };

    if ((_distance2D < 3.2 && {_distance3D < 7.2}) || {_distance3D < 4.8}) exitWith {
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
        _result = "DETONATED";
    };
    uiSleep _tick;
};
_drone setVariable ["dro2026_fpvInitialized", false];
_result
