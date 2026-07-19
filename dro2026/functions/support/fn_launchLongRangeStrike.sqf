params [
    "_origin", "_contact", ["_side", east], ["_preferFP5", false], ["_operator", objNull],
    ["_requestedType", "AUTO"], ["_decoy", false], ["_salvoIndex", 0], ["_salvoSize", 1], ["_reservedStock", false]
];
private _refundReserved = {
    if (_reservedStock && {_side == playersSide}) then {
        private _poolName = if (_decoy) then {"friendlyDecoyStock"} else {"friendlyLongRangeStock"};
        DRO2026_resources set [_poolName, (DRO2026_resources getOrDefault [_poolName, 0]) + 1];
        if ((toUpperANSI _requestedType) == "FP5") then {DRO2026_resources set ["friendlyFP5Stock", (DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) + 1]};
    };
};
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {call _refundReserved; objNull};
if (!isNull _operator && {!alive _operator}) exitWith {call _refundReserved; objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
if (count _targetPos < 2) exitWith {call _refundReserved; objNull};

private _vehicleClass = "";
private _ammoClass = "";
private _launcherClass = "";
private _label = "ударный БПЛА";
private _req = toUpperANSI _requestedType;
private _exactClass = if ((_req find "CLASS:") == 0) then {_requestedType select [6]} else {""};
private _sideSuffix = if (_side == west) then {"WEST"} else {if (_side == resistance) then {"GUER"} else {"EAST"}};
private _role = format ["LONG_RANGE_%1", _sideSuffix];
private _pool = DRO2026_assetRegistry getOrDefault [_role, []];

private _pickVehicle = {
    private _tokens = _this;
    private _matches = _pool select {
        private _n = toLowerANSI _x;
        (_tokens findIf {(_n find _x) >= 0}) >= 0 && {_x isKindOf "Air"}
    };
    if (count _matches > 0) then {selectRandom _matches} else {""}
};
private _pickLauncher = {
    params ["_launcherRole"];
    private _launchers = DRO2026_assetRegistry getOrDefault [_launcherRole, []];
    if (count _launchers > 0) then {selectRandom _launchers} else {""}
};
private _pickAmmoFallback = {
    params ["_ammoRole"];
    private _ammoPool = DRO2026_ammoRegistry getOrDefault [_ammoRole, []];
    if (count _ammoPool > 0) then {_ammoPool select 0} else {""}
};

if (_exactClass != "" && {_exactClass in _pool} && {_exactClass isKindOf "Air"}) then {
    _vehicleClass = _exactClass;
    _label = getText (configFile >> "CfgVehicles" >> _exactClass >> "displayName");
    if (_label == "") then {_label = _exactClass};
} else {
    switch _req do {
        case "FP1": {
            _label = "FP-1";
            _launcherClass = [format ["LAUNCHER_FP1_%1", _sideSuffix]] call _pickLauncher;
            _ammoClass = [_launcherClass] call DRO2026_fnc_resolveLauncherAmmo;
            if (_ammoClass == "") then {_ammoClass = ["STRIKE_AMMO_FP1"] call _pickAmmoFallback};
        };
        case "FP2": {
            _label = "FP-2";
            _vehicleClass = ["fp2"] call _pickVehicle;
            if (_vehicleClass == "") then {
                _launcherClass = [format ["LAUNCHER_FP2_%1", _sideSuffix]] call _pickLauncher;
                _ammoClass = [_launcherClass] call DRO2026_fnc_resolveLauncherAmmo;
                if (_ammoClass == "") then {_ammoClass = ["STRIKE_AMMO_FP2"] call _pickAmmoFallback};
            };
        };
        case "BM35": {
            _label = "BM-35";
            _vehicleClass = ["bm35"] call _pickVehicle;
            if (_vehicleClass == "") then {
                _launcherClass = [format ["LAUNCHER_BM35_%1", _sideSuffix]] call _pickLauncher;
                _ammoClass = [_launcherClass] call DRO2026_fnc_resolveLauncherAmmo;
                if (_ammoClass == "") then {_ammoClass = ["STRIKE_AMMO_BM35"] call _pickAmmoFallback};
            };
        };
        case "BULAVA": {
            _label = "Bulava";
            _launcherClass = [format ["LAUNCHER_BULAVA_%1", _sideSuffix]] call _pickLauncher;
            _ammoClass = [_launcherClass] call DRO2026_fnc_resolveLauncherAmmo;
        };
        case "FP5": {
            _label = "FP-5 Flamingo";
            _launcherClass = ["LAUNCHER_FP5_WEST"] call _pickLauncher;
            _ammoClass = [_launcherClass] call DRO2026_fnc_resolveLauncherAmmo;
            if (_ammoClass == "") then {_ammoClass = ["STRIKE_AMMO_FP5"] call _pickAmmoFallback};
        };
        case "SHAHED": {
            _label = "Shahed/Geran";
            _vehicleClass = ["shahed", "geran"] call _pickVehicle;
            if (_vehicleClass == "") then {_ammoClass = ["STRIKE_AMMO_SHAHED"] call _pickAmmoFallback};
        };
        default {
            private _preferred = [];
            if (_side == east && {random 1 < 0.72}) then {
                _preferred = _pool select {private _n = toLowerANSI _x; (_n find "shahed") >= 0 || {(_n find "geran") >= 0}};
            };
            if (_side == west && {random 1 < 0.82}) then {
                _preferred = _pool select {private _n = toLowerANSI _x; (_n find "fp2") >= 0 || {(_n find "bm35") >= 0}};
            };
            _vehicleClass = if (count _preferred > 0) then {selectRandom _preferred} else {if (count _pool > 0) then {selectRandom _pool} else {""}};
            if (_vehicleClass != "") then {
                private _n = toLowerANSI _vehicleClass;
                if ((_n find "shahed") >= 0 || {(_n find "geran") >= 0}) then {_label = "Shahed/Geran"};
                if ((_n find "bm35") >= 0) then {_label = "BM-35"};
                if ((_n find "fp2") >= 0) then {_label = "FP-2"};
            };
        };
    };
};

if (_vehicleClass == "" && {_ammoClass == ""}) exitWith {
    [format ["Отменён запуск %1: не найден летающий класс или штатный боеприпас пусковой", _req]] call DRO2026_fnc_log;
    call _refundReserved;
    objNull
};
if (_vehicleClass != "" && {!(_vehicleClass isKindOf "Air")}) exitWith {
    [format ["Отменён запуск %1: %2 не является Air", _req, _vehicleClass]] call DRO2026_fnc_log;
    call _refundReserved;
    objNull
};

private _spawnDistance = if (_ammoClass != "") then {12000 + random 6000} else {8000 + random 5000};
private _baseBearing = _targetPos getDir _origin;
private _formationOffset = (_salvoIndex - ((_salvoSize - 1) / 2)) * 7;
private _spawn2D = [];
for "_attempt" from 0 to 30 do {
    private _candidate = _targetPos getPos [_spawnDistance, _baseBearing + _formationOffset + (-18 + random 36)];
    if ((_candidate select 0) > 350 && {(_candidate select 1) > 350} && {(_candidate select 0) < (worldSize - 350)} && {(_candidate select 1) < (worldSize - 350)}) exitWith {_spawn2D = _candidate};
    _spawnDistance = (_spawnDistance * 0.92) max 6500;
};
if (count _spawn2D < 2) then {_spawn2D = _origin};

private _spawnASL = AGLToASL _spawn2D;
_spawnASL set [2, (getTerrainHeightASL _spawn2D) + 130 + random 70];
private _drone = objNull;
private _isProjectile = _ammoClass != "";
private _speed = 66;
if (_isProjectile) then {
    _drone = createVehicle [_ammoClass, ASLToAGL _spawnASL, [], 0, "CAN_COLLIDE"];
    _drone setPosASL _spawnASL;
    _speed = if (_req == "FP5") then {185} else {82};
} else {
    _drone = createVehicle [_vehicleClass, ASLToAGL _spawnASL, [], 0, "FLY"];
    _drone setPosASL _spawnASL;
    private _group = _side createVehicleCrew _drone;
    if (isNull _group || {isNull driver _drone}) exitWith {
        deleteVehicleCrew _drone;
        deleteVehicle _drone;
        _drone = objNull;
    };
    _group setBehaviourStrong "CARELESS";
    _group setCombatMode "BLUE";
    _group setSpeedMode "FULL";
    private _lower = toLowerANSI _vehicleClass;
    if ((_lower find "shahed") >= 0 || {(_lower find "geran") >= 0}) then {_speed = 52};
    if ((_lower find "bm35") >= 0) then {_speed = 64};
    if ((_lower find "fp2") >= 0) then {_speed = 72};
};
if (isNull _drone) exitWith {call _refundReserved; objNull};
_drone setVariable ["DRO2026_operator", _operator];
_drone setVariable ["DRO2026_decoy", _decoy];
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
[_drone, _label, _side] spawn DRO2026_fnc_trackIncomingDrone;

if (_decoy) then {
    _drone addEventHandler ["Killed", {
        params ["_decoyVehicle", "_killer"];
        if (!isNull _killer) then {
            ["PLAYER", vehicle _killer, getPosATL (vehicle _killer), 0.88, "РАСКРЫТОЕ_ПВО"] call DRO2026_fnc_addContact;
            DRO2026_resources set ["enemyAirDefence", ((DRO2026_resources getOrDefault ["enemyAirDefence", 0]) - 4) max 0];
        };
    }];
};

private _timeout = time + 760;
private _lastSearch = -10;
while {alive _drone && {time < _timeout} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
    if (!isNull _target && {alive _target}) then {_targetPos = getPosATL _target};
    private _distance = _drone distance2D _targetPos;

    if (_distance < 1100 && {(isNull _target || {!alive _target})} && {(time - _lastSearch) > 2.5}) then {
        _lastSearch = time;
        private _hostileSide = if (_side == playersSide) then {enemySide} else {playersSide};
        private _candidates = nearestObjects [_targetPos, ["LandVehicle", "Air", "Man"], 650, true] select {
            alive _x && {
                private _objSide = side _x;
                if (!isNull (driver _x)) then {_objSide = side (group (driver _x))};
                _objSide == _hostileSide
            }
        };
        if (count _candidates > 0) then {
            _candidates = [_candidates, [], {
                private _score = 0;
                if (_x isKindOf "Tank") then {_score = _score + 7};
                if (_x isKindOf "Air") then {_score = _score + 6};
                if (_x isKindOf "Car") then {_score = _score + 4};
                if (_x isKindOf "Man") then {_score = _score + 1};
                _score - ((_x distance2D _targetPos) / 1000)
            }, "DESCEND"] call BIS_fnc_sortBy;
            _target = _candidates select 0;
            _targetPos = getPosATL _target;
        };
    };

    private _clearance = if (_distance > 1200) then {95} else {if (_distance > 350) then {45} else {8}};
    private _aimASL = [_drone, _targetPos, _clearance, [350, 750, 1300], 700, 18] call DRO2026_fnc_calculateTerrainAwareAim;
    private _delta = _aimASL vectorDiff getPosASL _drone;
    private _length = vectorMagnitude _delta;
    if (_length > 0.1) then {
        private _vector = _delta vectorMultiply (1 / _length);
        private _pulse = 1 + ((sin ((diag_tickTime + _salvoIndex) * 38)) * 0.035);
        _drone setVectorDirAndUp [_vector, [0,0,1]];
        _drone setVelocity (_vector vectorMultiply (_speed * _pulse));
    };

    if (_distance < 7) exitWith {
        if (_decoy) then {
            if (_isProjectile) then {deleteVehicle _drone} else {_drone setDamage 1};
        } else {
            if (_isProjectile) then {
                triggerAmmo _drone;
            } else {
                _drone setDamage 1;
            };
        };
    };
    sleep (if (_distance > 2500) then {0.55} else {0.28});
};
private _activeIndex = DRO2026_activeDrones find _drone;
if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
if (alive _drone) then {
    if (!_isProjectile) then {deleteVehicleCrew _drone};
    deleteVehicle _drone;
};
_drone
