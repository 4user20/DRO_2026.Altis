params ["_origin", "_contact", ["_side", east], ["_operator", objNull]];
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
    if (_isArmored) then {(_n find "pg7vl") >= 0} else {if (_isMan) then {(_n find "og7v") >= 0 || {(_n find "rkg") >= 0}} else {(_n find "ied") >= 0 || {(_n find "og7v") >= 0}}}
};
private _droneClass = if (count _preferred > 0) then {selectRandom _preferred} else {if (count _pool > 0) then {selectRandom _pool} else {_fallback}};
if (!isClass (configFile >> "CfgVehicles" >> _droneClass)) then {_droneClass = _fallback};

private _dir = _origin getDir _targetPos;
private _spawnPos = _origin getPos [25 + random 20, _dir];
_spawnPos set [2, 25 + random 15];
private _drone = createVehicle [_droneClass, _spawnPos, [], 0, "FLY"];
if (isNull _drone) exitWith {objNull};
private _crewGroup = _side createVehicleCrew _drone;
_drone setDir _dir;
_drone setVariable ["DRO2026_operator", _operator];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _drone]};
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
if (!isNull _crewGroup) then {_crewGroup setBehaviourStrong "CARELESS"; _crewGroup setCombatMode "BLUE"; _crewGroup setSpeedMode "FULL"};
[_drone, "FPV", _side] spawn DRO2026_fnc_trackIncomingDrone;

private _timeout = time + 150;
while {alive _drone && {time < _timeout}} do {
    if (!isNull _target && {alive _target}) then {_targetPos = getPosATL _target};
    private _currentASL = getPosASL _drone;
    private _distance = _drone distance2D _targetPos;
    private _targetASL = AGLToASL _targetPos;
    private _aim = +_targetASL;
    if (_distance > 180) then {_aim set [2, (getTerrainHeightASL _targetPos) + 55]} else {_aim set [2, (_targetASL select 2) + 1.2]};
    private _delta = _aim vectorDiff _currentASL;
    private _length = vectorMagnitude _delta;
    if (_length > 0.1) then {
        private _vector = _delta vectorMultiply (1 / _length);
        _drone setVectorDirAndUp [_vector, [0,0,1]];
        _drone setVelocity (_vector vectorMultiply 44);
    };
    if (_distance < 6.5) exitWith {
        private _warhead = if (_isArmored) then {"M_Titan_AT"} else {"M_Titan_AP"};
        private _explosive = createVehicle [_warhead, getPosATL _drone, [], 0, "CAN_COLLIDE"];
        _explosive setVelocity velocity _drone;
        _drone setDamage 1;
    };
    sleep 0.12;
};
if (alive _drone) then {deleteVehicleCrew _drone; deleteVehicle _drone};
_drone
