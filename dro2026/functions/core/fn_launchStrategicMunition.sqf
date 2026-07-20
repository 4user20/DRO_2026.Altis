params [
    ["_originATL",[],[[]]],
    ["_target",createHashMap,[createHashMap]],
    ["_launchSide",enemySide,[east]],
    ["_profile","CRUISE",[""]],
    ["_ammoClass","",[""]],
    ["_warheadYield",1,[0]],
    ["_radarCrossSection",0.65,[0]]
];
if (!isServer || {count _originATL < 2} || {count _target == 0}) exitWith {createHashMap};
private _profileUpper = toUpperANSI _profile;
private _targetASL = +(_target getOrDefault ["positionASL",[]]);
if (count _targetASL < 2) exitWith {createHashMap};
if (_ammoClass == "") then {
    private _ammoRole = switch _profileUpper do {
        case "FP5": {"STRIKE_AMMO_FP5"};
        case "FLAMINGO": {"STRIKE_AMMO_FP5"};
        case "FP2": {"STRIKE_AMMO_FP2"};
        case "BM35": {"STRIKE_AMMO_BM35"};
        case "SHAHED": {"STRIKE_AMMO_SHAHED"};
        default {""};
    };
    if (_ammoRole != "") then {
        private _pool = (DRO2026_ammoRegistry getOrDefault [_ammoRole,[]]) select {isClass (configFile >> "CfgAmmo" >> _x)};
        if (count _pool > 0) then {_ammoClass = _pool select 0};
    };
};
if (_ammoClass == "" && {_profileUpper in ["ISKANDER","BALLISTIC"]}) then {
    private _launcherRole = format ["BALLISTIC_MISSILE_%1",[_launchSide] call DRO2026_fnc_getSideSuffix];
    private _launchers = DRO2026_assetRegistry getOrDefault [_launcherRole,[]];
    {
        private _resolved = [_x] call DRO2026_fnc_resolveLauncherAmmo;
        if (_resolved != "" && {isClass (configFile >> "CfgAmmo" >> _resolved)}) exitWith {_ammoClass = _resolved};
    } forEach _launchers;
};
if (_ammoClass == "" || {!isClass (configFile >> "CfgAmmo" >> _ammoClass)}) exitWith {
    ["STRATEGIC","LAUNCH_REJECTED",createHashMapFromArray [["reason","NO_COMPATIBLE_AMMO"],["profile",_profileUpper]],_profileUpper] call DRO2026_fnc_logStructured;
    createHashMap
};
private _originASL = [_originATL,"ATL",objNull] call DRO2026_fnc_normalizePositionASL;
private _targetObject = _target getOrDefault ["object",objNull];
private _launchASL = +_originASL;
private _isBallistic = _profileUpper in ["ISKANDER","BALLISTIC"];
_launchASL set [2,(getTerrainHeightASL _originATL) + (if (_isBallistic) then {45} else {80})];
private _munitionObject = createVehicle [_ammoClass,ASLToAGL _launchASL,[],0,"CAN_COLLIDE"];
if (isNull _munitionObject) exitWith {createHashMap};
_munitionObject setPosASL _launchASL;
private _nominalSpeed = if (_isBallistic) then {310} else {if (_profileUpper in ["FP5","FLAMINGO"]) then {185} else {82}};
private _record = [_munitionObject,_profileUpper,_launchSide,_target,_warheadYield,_radarCrossSection,_nominalSpeed] call DRO2026_fnc_registerStrategicMunition;
if (count _record == 0) exitWith {deleteVehicle _munitionObject; createHashMap};
private _munitionId = _record getOrDefault ["id",""];
private _ammoCfg = configFile >> "CfgAmmo" >> _ammoClass;
if (getNumber (_ammoCfg >> "manualControl") > 0) then {_munitionObject setMissileTargetPos (ASLToATL _targetASL)};
private _initial = _targetASL vectorDiff _launchASL;
private _initialLength = vectorMagnitude _initial;
if (_initialLength > 0.1) then {
    private _direction = _initial vectorMultiply (1 / _initialLength);
    private _right = _direction vectorCrossProduct [0,0,1];
    if (vectorMagnitude _right < 0.01) then {_right = [1,0,0]};
    _right = _right vectorMultiply (1 / ((vectorMagnitude _right) max 0.01));
    private _up = _right vectorCrossProduct _direction;
    _munitionObject setVectorDirAndUp [_direction,_up];
    _munitionObject setVelocity (_direction vectorMultiply (if (_isBallistic) then {140} else {_nominalSpeed}));
};
[_record,_targetObject,_originASL,_targetASL,_isBallistic,_nominalSpeed] spawn {
    params ["_record","_targetObject","_originASL","_targetASL","_isBallistic","_speed"];
    private _object = _record getOrDefault ["object",objNull];
    private _munitionId = _record getOrDefault ["id",""];
    private _distanceTotal = (_originASL distance2D _targetASL) max 1;
    private _duration = (_distanceTotal / (_speed max 30)) max 18;
    private _started = time;
    private _deadline = time + (_duration * 2.2) + 45;
    private _impact = false;
    while {!isNull _object && {time < _deadline} && {!(missionNamespace getVariable ["DRO2026_missionEnding",false])}} do {
        if (_object getVariable ["DRO2026_intercepted",false]) exitWith {};
        if (!isNull _targetObject && {alive _targetObject}) then {_targetASL = getPosASL _targetObject};
        private _currentASL = getPosASL _object;
        private _horizontal = _currentASL distance2D _targetASL;
        private _elapsedRatio = (((time - _started) / _duration) max 0) min 1;
        private _aimASL = +_targetASL;
        if (_isBallistic) then {
            private _apex = 1100 + ((_distanceTotal / 12) min 1700);
            private _desiredAltitude = linearConversion [0,1,_elapsedRatio,_originASL select 2,_targetASL select 2,true] + (sin (_elapsedRatio * 180) * _apex);
            private _leadDistance = (_horizontal min 1800) max 250;
            _aimASL = _currentASL getPos [_leadDistance,_currentASL getDir _targetASL];
            _aimASL set [2,_desiredAltitude];
        } else {
            private _clearance = if (_horizontal > 1400) then {65} else {if (_horizontal > 450) then {38} else {6}};
            _aimASL = [_object,ASLToATL _targetASL,_clearance,[450,900,1500],800,20] call DRO2026_fnc_calculateTerrainAwareAim;
        };
        private _delta = _aimASL vectorDiff _currentASL;
        private _length = vectorMagnitude _delta;
        if (_length > 0.1) then {
            private _direction = _delta vectorMultiply (1 / _length);
            private _right = _direction vectorCrossProduct [0,0,1];
            if (vectorMagnitude _right < 0.01) then {_right = [1,0,0]};
            _right = _right vectorMultiply (1 / ((vectorMagnitude _right) max 0.01));
            private _up = _right vectorCrossProduct _direction;
            _object setVectorDirAndUp [_direction,_up];
            _object setVelocity (_direction vectorMultiply (_speed * (if (_isBallistic) then {0.75 + (0.45 * _elapsedRatio)} else {1})));
        };
        if (_horizontal < (if (_isBallistic) then {24} else {11}) && {abs ((_currentASL select 2) - (_targetASL select 2)) < 45}) exitWith {
            _impact = true;
            _record set ["state","IMPACT"];
            _record set ["impactAt",time];
            [_record,_currentASL,"IMPACT"] call DRO2026_fnc_resolveStrategicImpact;
            triggerAmmo _object;
        };
        sleep (if (_isBallistic) then {0.12} else {0.18});
    };
    if (!isNull _object && {!_impact} && {!(_object getVariable ["DRO2026_intercepted",false])}) then {deleteVehicle _object};
    private _registry = missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]];
    _registry = _registry select {(_x getOrDefault ["id",""]) != _munitionId};
    missionNamespace setVariable ["DRO2026_activeStrategicMunitions",_registry];
};
_record