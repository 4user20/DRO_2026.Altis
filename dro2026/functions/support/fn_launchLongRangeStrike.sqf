params [
    "_origin", "_contact", ["_side", east], ["_preferFP5", false], ["_operator", objNull],
    ["_requestedType", "AUTO"], ["_decoy", false], ["_salvoIndex", 0], ["_salvoSize", 1],
    ["_reservedStock", false], ["_reservationNodeId", "NODE_DRONE_REAR_01"], ["_siteId", ""]
];
private _req = toUpperANSI _requestedType;
private _refundReserved = {
    if (!_reservedStock) exitWith {};
    if (_side == playersSide) then {
        private _poolName = if (_decoy) then {
            "friendlyDecoyStock"
        } else {
            if (_req == "FP5") then {"friendlyFP5Stock"} else {"friendlyLongRangeStock"}
        };
        DRO2026_resources set [_poolName, (DRO2026_resources getOrDefault [_poolName, 0]) + 1];
    } else {
        if (_reservationNodeId != "") then {
            [_reservationNodeId, "LONG_RANGE_DRONES", 1, "LONG_RANGE_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
            [_reservationNodeId, "FUEL", 1, "LONG_RANGE_LAUNCH_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
        };
        DRO2026_resources set ["enemyLongRangeStock", (DRO2026_resources getOrDefault ["enemyLongRangeStock", 0]) + 1];
    };
};
private _siteOperational = {
    _siteId == "" || {[_siteId] call DRO2026_fnc_isSiteOperational}
};
private _contactOperational = {
    private _targetObject = _contact getOrDefault ["target", objNull];
    private _subjectId = _contact getOrDefault ["subjectId", ""];
    !((_contact getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]) &&
    {isNull _targetObject || {alive _targetObject}} &&
    {_subjectId == "" || {[_contact] call DRO2026_fnc_isLiveContactSubject}}
};
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {call _refundReserved; objNull};
if (!isNull _operator && {!alive _operator}) exitWith {call _refundReserved; objNull};
if !(call _siteOperational) exitWith {call _refundReserved; objNull};
if !(call _contactOperational) exitWith {call _refundReserved; objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
if (count _targetPos < 2) exitWith {call _refundReserved; objNull};

private _vehicleClass = "";
private _ammoClass = "";
private _launcherClass = "";
private _label = "ударный БПЛА";
private _exactClass = if ((_req find "CLASS:") == 0) then {_requestedType select [6]} else {""};
private _sideSuffix = [_side] call DRO2026_fnc_getSideSuffix;
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
private _role = format ["LONG_RANGE_%1", _sideSuffix];
private _pool = (DRO2026_assetRegistry getOrDefault [_role, []]) select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg &&
    {_x isKindOf "Air"} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
};

private _pickVehicle = {
    private _tokens = _this;
    private _matches = _pool select {
        private _n = toLowerANSI _x;
        (_tokens findIf {(_n find _x) >= 0}) >= 0
    };
    if (count _matches > 0) then {selectRandom _matches} else {""}
};
private _pickLauncher = {
    params ["_launcherRole"];
    private _launchers = (DRO2026_assetRegistry getOrDefault [_launcherRole, []]) select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
    };
    if (count _launchers > 0) then {selectRandom _launchers} else {""}
};
private _pickAmmoFallback = {
    params ["_ammoRole"];
    private _ammoPool = (DRO2026_ammoRegistry getOrDefault [_ammoRole, []]) select {
        isClass (configFile >> "CfgAmmo" >> _x)
    };
    if (count _ammoPool > 0) then {_ammoPool select 0} else {""}
};

private _selectionValid = true;
if (_exactClass != "") then {
    private _catalogAllowed = [format ["STRIKE_CLASS:%1", _exactClass], _exactClass] call DRO2026_fnc_supportCatalogContains;
    if (!_catalogAllowed || {!isClass (configFile >> "CfgVehicles" >> _exactClass)} || {!(_exactClass isKindOf "Air")}) then {
        _selectionValid = false;
        [format ["Отменён exact launch: %1 отсутствует в installed-assets catalog", _exactClass]] call DRO2026_fnc_log;
    } else {
        _vehicleClass = _exactClass;
        _label = getText (configFile >> "CfgVehicles" >> _exactClass >> "displayName");
        if (_label == "") then {_label = _exactClass};
    };
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
        case "AUTO": {
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
        default {_selectionValid = false};
    };
};
if (!_selectionValid) exitWith {call _refundReserved; objNull};

if (_ammoClass != "" && {!isClass (configFile >> "CfgAmmo" >> _ammoClass)}) then {
    [format ["Отменён запуск %1: боеприпас %2 отсутствует в CfgAmmo", _req, _ammoClass]] call DRO2026_fnc_log;
    _ammoClass = "";
};
if (_vehicleClass == "" && {_ammoClass == ""}) exitWith {
    [format ["Отменён запуск %1: не найден летающий класс или штатный боеприпас пусковой", _req]] call DRO2026_fnc_log;
    call _refundReserved;
    objNull
};
if (_vehicleClass != "") then {
    private _vehicleCfg = configFile >> "CfgVehicles" >> _vehicleClass;
    if (!isClass _vehicleCfg || {!(_vehicleClass isKindOf "Air")} || {_exactClass == "" && {_sideNumber >= 0 && {getNumber (_vehicleCfg >> "side") != _sideNumber}}}) exitWith {
        [format ["Отменён запуск %1: %2 не является доступным Air-классом", _req, _vehicleClass]] call DRO2026_fnc_log;
        call _refundReserved;
        _vehicleClass = "";
    };
};
if (_vehicleClass == "" && {_ammoClass == ""}) exitWith {objNull};
if !(call _siteOperational) exitWith {call _refundReserved; objNull};
if !(call _contactOperational) exitWith {call _refundReserved; objNull};

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
private _crewGroup = grpNull;
private _isProjectile = _ammoClass != "";
private _speed = 66;
if (_isProjectile) then {
    _drone = createVehicle [_ammoClass, ASLToAGL _spawnASL, [], 0, "CAN_COLLIDE"];
    if (!isNull _drone) then {
        _drone setPosASL _spawnASL;
        _speed = if (_req == "FP5") then {185} else {82};
    };
} else {
    _drone = createVehicle [_vehicleClass, ASLToAGL _spawnASL, [], 0, "FLY"];
    if (!isNull _drone) then {
        _drone setPosASL _spawnASL;
        _crewGroup = _side createVehicleCrew _drone;
        if (isNull _crewGroup || {isNull (driver _drone)}) then {
            deleteVehicleCrew _drone;
            deleteVehicle _drone;
            if (!isNull _crewGroup) then {deleteGroup _crewGroup};
            _drone = objNull;
            _crewGroup = grpNull;
        } else {
            _crewGroup setBehaviourStrong "CARELESS";
            _crewGroup setCombatMode "BLUE";
            _crewGroup setSpeedMode "FULL";
            private _driver = driver _drone;
            _driver enableAI "MOVE";
            _driver enableAI "PATH";
            _driver enableAI "TARGET";
            _driver enableAI "AUTOTARGET";
            private _lower = toLowerANSI _vehicleClass;
            if ((_lower find "shahed") >= 0 || {(_lower find "geran") >= 0}) then {_speed = 52};
            if ((_lower find "bm35") >= 0) then {_speed = 64};
            if ((_lower find "fp2") >= 0) then {_speed = 72};
        };
    };
};
if (isNull _drone) exitWith {call _refundReserved; objNull};
if (_side == playersSide && {_req == "FP5"}) then {
    DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
};
_drone setVariable ["DRO2026_operator", _operator];
_drone setVariable ["DRO2026_decoy", _decoy];
_drone setVariable ["DRO2026_launchSide", _side];
_drone setVariable ["DRO2026_siteId", _siteId, true];
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
private _launchClass = if (_isProjectile) then {_ammoClass} else {_vehicleClass};
private _eventSubject = if (_reservationNodeId != "") then {_reservationNodeId} else {if (_siteId != "") then {_siteId} else {"LONG_RANGE_LAUNCH"}};
["DRONE_LAUNCHED", createHashMapFromArray [
    ["role", "LONG_RANGE"], ["type", _requestedType], ["class", _launchClass], ["projectile", _isProjectile],
    ["side", str _side], ["contactId", _contact getOrDefault ["id", ""]], ["subjectId", _contact getOrDefault ["subjectId", ""]],
    ["siteId", _siteId], ["reservationNodeId", _reservationNodeId], ["decoy", _decoy],
    ["salvoIndex", _salvoIndex], ["salvoSize", _salvoSize], ["flightAuthority", if (_isProjectile) then {"FPV_TERMINAL"} else {"ARMA_AI"}]
], _eventSubject] call DRO2026_fnc_emitEvent;
[_drone, _label, _side] spawn DRO2026_fnc_trackIncomingDrone;

if (_decoy) then {
    _drone addEventHandler ["Killed", {
        params ["_decoyVehicle", "_killer"];
        if (!isNull _killer) then {
            private _launchSide = _decoyVehicle getVariable ["DRO2026_launchSide", playersSide];
            private _hostileSide = if (_launchSide == playersSide) then {enemySide} else {playersSide};
            private _killerVehicle = vehicle _killer;
            private _killerSide = side _killerVehicle;
            if (_killerVehicle isKindOf "Man") then {_killerSide = side (group _killerVehicle)};
            if (count crew _killerVehicle > 0) then {_killerSide = side (group ((crew _killerVehicle) select 0))};
            if (_killerSide == _hostileSide) then {
                ["PLAYER", _killerVehicle, getPosATL _killerVehicle, 0.88, "РАСКРЫТОЕ_ПВО"] call DRO2026_fnc_addContact;
                DRO2026_resources set ["enemyAirDefence", ((DRO2026_resources getOrDefault ["enemyAirDefence", 0]) - 4) max 0];
            };
        };
    }];
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
private _initialDelta = (AGLToASL _targetPos) vectorDiff _spawnASL;
if (_isProjectile) then {
    [_drone, "FPV_TERMINAL", "PROJECTILE_GUIDANCE_REQUIRED", "NONE"] call DRO2026_fnc_setFlightAuthority;
    [_drone, _initialDelta, _speed] call _applyFlightVector;
} else {
    [_drone, "ARMA_AI", "WAYPOINT_MACRO_ROUTE", "NONE"] call DRO2026_fnc_setFlightAuthority;
    private _initialLength = vectorMagnitude _initialDelta;
    if (_initialLength > 0.01) then {_drone setVelocity ((_initialDelta vectorMultiply (1 / _initialLength)) vectorMultiply (_speed max 32))};
    [_crewGroup, _drone, _spawnASL, AGLToASL _targetPos, if (_decoy) then {"SEARCH"} else {"STRIKE"}, 800 + random 500, 280 + random 160] call DRO2026_fnc_buildWaypointFlightPlan;
};
private _timeout = time + 760;
private _terminalDeadline = -1;
while {alive _drone && {time < _timeout} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
    if (!isNull _target && {alive _target}) then {_targetPos = getPosATL _target};
    private _distance = _drone distance2D _targetPos;
    private _authority = _drone getVariable ["DRO2026_flightAuthority", "NONE"];
    if (!_isProjectile && {_distance < 950} && {_authority == "ARMA_AI"}) then {
        if ([_drone, "FPV_TERMINAL", "FINAL_INGRESS", "ARMA_AI"] call DRO2026_fnc_setFlightAuthority) then {_terminalDeadline = time + 45; if (!isNull (driver _drone)) then {(driver _drone) disableAI "PATH"}};
    };
    private _terminalActive = _isProjectile || {(_drone getVariable ["DRO2026_flightAuthority", "NONE"]) == "FPV_TERMINAL"};
    if (_terminalActive) then {
        if (!_isProjectile && {_terminalDeadline > 0 && {time > _terminalDeadline}}) exitWith {};
        private _clearance = if (_distance > 350) then {45} else {8};
        private _aimASL = [_drone, _targetPos, _clearance, [350,750,1300], 700, 18] call DRO2026_fnc_calculateTerrainAwareAim;
        private _delta = _aimASL vectorDiff getPosASL _drone; private _length = vectorMagnitude _delta;
        if (_length > 0.1) then {private _vector = _delta vectorMultiply (1 / _length); private _pulse = 1 + ((sin ((diag_tickTime + _salvoIndex) * 38)) * 0.035); [_drone,_vector,_speed*_pulse] call _applyFlightVector};
    };
    if (_distance < 7) then {if (_decoy) then {if (_isProjectile) then {deleteVehicle _drone} else {_drone setDamage 1}} else {if (_isProjectile) then {triggerAmmo _drone} else {_drone setDamage 1}}};
    sleep (if (_terminalActive) then {0.28} else {1.5});
};
[_drone, "NONE", "MISSION_COMPLETE", _drone getVariable ["DRO2026_flightAuthority", "NONE"]] call DRO2026_fnc_setFlightAuthority;
private _activeIndex = DRO2026_activeDrones find _drone;
if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
if (!isNull _drone) then {
    if (!_isProjectile) then {deleteVehicleCrew _drone};
    if (alive _drone) then {deleteVehicle _drone};
};
if (!isNull _crewGroup) then {deleteGroup _crewGroup};
_drone
