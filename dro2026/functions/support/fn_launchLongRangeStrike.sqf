params ["_origin", "_contact", ["_side", east], ["_preferFP5", false], ["_operator", objNull], ["_requestedType", "AUTO"], ["_decoy", false]];
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {objNull};
if (!isNull _operator && {!alive _operator}) exitWith {objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetPos = _contact getOrDefault ["position", []];
if (count _targetPos < 2) exitWith {objNull};

private _vehicleClass = "";
private _ammoClass = "";
private _label = "ударный БПЛА";
private _req = toUpperANSI _requestedType;
if (_side == west && {_preferFP5}) then {
    private _ammoPool = DRO2026_ammoRegistry getOrDefault ["CRUISE_WEST", []];
    if (count _ammoPool > 0) then {_ammoClass = selectRandom _ammoPool; _label = "FP-5 Flamingo";};
};
if (_ammoClass == "") then {
    private _role = switch (_side) do {
        case west: {"LONG_RANGE_WEST"};
        case resistance: {"LONG_RANGE_GUER"};
        default {"LONG_RANGE_EAST"};
    };
    private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
    if (count _pool > 0) then {
        private _pickByToken = {
            params ["_tokenList"];
            private _matches = _pool select {
                private _n = toLowerANSI _x;
                (_tokenList findIf {(_n find _x) >= 0}) >= 0
            };
            if (count _matches > 0) then {selectRandom _matches} else {""}
        };
        switch _req do {
            case "FP1": {_vehicleClass = ["fp1"] call _pickByToken; _label = "FP-1";};
            case "FP2": {_vehicleClass = ["fp2"] call _pickByToken; _label = "FP-2";};
            case "BM35": {_vehicleClass = ["bm35"] call _pickByToken; _label = "BM-35";};
            case "SHAHED": {_vehicleClass = ["shahed","geran"] call _pickByToken; _label = "Shahed/Geran";};
            case "BULAVA": {_vehicleClass = ["fp2","bm35"] call _pickByToken; _label = "Bulava";};
            case "AUTO": {};
            default {};
        };
        if (_vehicleClass == "") then {
            private _preferred = [];
            if (_side == east && {random 1 < 0.72}) then {
                _preferred = _pool select {
                    private _n = toLowerANSI _x;
                    (_n find "shahed") >= 0 || {(_n find "geran") >= 0}
                };
            };
            if (_side == west && {random 1 < 0.82}) then {
                _preferred = _pool select {
                    private _n = toLowerANSI _x;
                    (_n find "fp1") >= 0 || {(_n find "fp2") >= 0} || {(_n find "bm35") >= 0}
                };
            };
            _vehicleClass = if (count _preferred > 0) then {selectRandom _preferred} else {selectRandom _pool};
        };
    };
};
if (_vehicleClass == "" && {_ammoClass == ""}) exitWith {objNull};

private _spawnDistance = if (_ammoClass != "") then {14000 + random 8000} else {8500 + random 6500};
private _baseBearing = _targetPos getDir _origin;
private _spawn2D = [];
for "_attempt" from 0 to 30 do {
    private _candidate = _targetPos getPos [_spawnDistance, _baseBearing + (-28 + random 56)];
    if ((_candidate select 0) > 350 && {(_candidate select 1) > 350} && {(_candidate select 0) < (worldSize - 350)} && {(_candidate select 1) < (worldSize - 350)}) exitWith {
        _spawn2D = _candidate;
    };
    _spawnDistance = (_spawnDistance * 0.92) max 7000;
};
if (count _spawn2D < 2) then {_spawn2D = _origin};

private _spawnASL = AGLToASL _spawn2D;
_spawnASL set [2, (getTerrainHeightASL _spawn2D) + 180 + random 90];
private _drone = objNull;
private _speed = 68;
if (_ammoClass != "") then {
    _drone = createVehicle [_ammoClass, ASLToAGL _spawnASL, [], 0, "CAN_COLLIDE"];
    _drone setPosASL _spawnASL;
    _speed = 180;
} else {
    _drone = createVehicle [_vehicleClass, ASLToAGL _spawnASL, [], 0, "FLY"];
    _drone setPosASL _spawnASL;
    private _group = _side createVehicleCrew _drone;
    if (!isNull _group) then {
        _group setBehaviourStrong "CARELESS";
        _group setCombatMode "BLUE";
        _group setSpeedMode "FULL";
    };
    private _lower = toLowerANSI _vehicleClass;
    if ((_lower find "shahed") >= 0 || {(_lower find "geran") >= 0}) then {_label = if (_label == "ударный БПЛА") then {"Shahed/Geran"} else {_label}; _speed = 52};
    if ((_lower find "bm35") >= 0) then {_label = if (_label == "ударный БПЛА") then {"BM-35"} else {_label}; _speed = 64};
    if ((_lower find "fp2") >= 0) then {_label = if (_label == "ударный БПЛА") then {"FP-2"} else {_label}; _speed = 72};
    if ((_lower find "fp1") >= 0) then {_label = if (_label == "ударный БПЛА") then {"FP-1"} else {_label}; _speed = 70};
};
if (isNull _drone) exitWith {objNull};
_drone setVariable ["DRO2026_operator", _operator];
_drone setVariable ["DRO2026_decoy", _decoy];
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
[_drone, _label, _side] spawn DRO2026_fnc_trackIncomingDrone;

private _route1 = _targetPos getPos [(_spawnDistance * 0.62), _targetPos getDir _spawn2D];
private _route2 = _targetPos getPos [(_spawnDistance * 0.30), (_targetPos getDir _spawn2D) + (-12 + random 24)];
private _timeout = time + 620;
while {alive _drone && {time < _timeout}} do {
    if (!isNull _target && {alive _target}) then {_targetPos = getPosATL _target};
    private _distance = _drone distance2D _targetPos;
    private _aim2D = if (_drone distance2D _route1 > 350) then {
        _route1
    } else {
        if (_drone distance2D _route2 > 300) then {_route2} else {_targetPos}
    };
    private _aimASL = AGLToASL _aim2D;
    if (_distance > 650) then {
        _aimASL set [2, (getTerrainHeightASL _aim2D) + 150];
    } else {
        _aimASL set [2, (getTerrainHeightASL _targetPos) + 8];
    };
    private _delta = _aimASL vectorDiff getPosASL _drone;
    private _length = vectorMagnitude _delta;
    if (_length > 0.1) then {
        private _vector = _delta vectorMultiply (1 / _length);
        _drone setVectorDirAndUp [_vector, [0,0,1]];
        _drone setVelocity (_vector vectorMultiply _speed);
    };
    if (_distance < 14) exitWith {
        if (_decoy) then {
            DRO2026_resources set ["enemyAirDefence", ((DRO2026_resources getOrDefault ["enemyAirDefence", 0]) - 6) max 0];
            DRO2026_resources set ["enemyEW", ((DRO2026_resources getOrDefault ["enemyEW", 0]) - 4) max 0];
            _drone setDamage 1;
        } else {
            private _explosive = createVehicle ["Bo_Mk82", getPosATL _drone, [], 0, "CAN_COLLIDE"];
            _explosive setVelocity velocity _drone;
            _drone setDamage 1;
        };
    };
    sleep 0.28;
};
if (alive _drone) then {
    if (_vehicleClass != "") then {deleteVehicleCrew _drone};
    deleteVehicle _drone;
};
_drone
