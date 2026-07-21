params [
    "_origin", "_contact", ["_side", east], ["_operator", objNull],
    ["_allowPlayerControl", false], ["_supportOwner", objNull], ["_requestedClass", ""],
    ["_reservationNodeId", ""], ["_siteId", ""], ["_missionId", ""]
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
private _siteOperational = {
    _siteId == "" || {[_siteId] call DRO2026_fnc_isSiteOperational}
};
if ((count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT) exitWith {call _refundReservation; objNull};
if (!isNull _operator && {!alive _operator}) exitWith {call _refundReservation; objNull};
if !(call _siteOperational) exitWith {call _refundReservation; objNull};
if !([_contact] call DRO2026_fnc_isLiveContactSubject) exitWith {call _refundReservation; objNull};
private _target = _contact getOrDefault ["target", objNull];
private _targetASL = +(_contact getOrDefault ["positionASL", _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]]]);
if (count _targetASL < 2) exitWith {call _refundReservation; objNull};
if (count _targetASL == 2) then {_targetASL pushBack (getTerrainHeightASL _targetASL)};
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
private _pool = +(DRO2026_assetRegistry getOrDefault [_role, []]);
private _allFPVClasses = [];
{_allFPVClasses append (DRO2026_assetRegistry getOrDefault [_x, []])} forEach ["FPV_WEST", "FPV_EAST", "FPV_GUER"];
_allFPVClasses = _allFPVClasses arrayIntersect _allFPVClasses;
if (missionNamespace getVariable ["DRO2026_droneRegistryInitialized", false]) then {
    private _sideKey = switch (_side) do {case west: {"WEST"}; case resistance: {"GUER"}; default {"EAST"}};
    {
        {
            if ((_x getOrDefault ["carrier", ""]) == "VEHICLE") then {
                _pool pushBackUnique (_x getOrDefault ["class", ""]);
            };
        } forEach (DRO2026_droneRegistry getOrDefault [format ["%1_%2", _x, _sideKey], []]);
    } forEach ["FPV_AP_TI", "FPV_AT_TI", "FPV_AP", "FPV_AT"];
};
_pool = _pool select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg &&
    {_x isKindOf "Air"} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
};
private _requestedClassAllowed = true;
if (_requestedClass != "") then {
    private _catalogAllowed = ([format ["FPV_CLASS_AUTO:%1", _requestedClass], _requestedClass] call DRO2026_fnc_supportCatalogContains) ||
        {[format ["FPV_CLASS_MANUAL:%1", _requestedClass], _requestedClass] call DRO2026_fnc_supportCatalogContains};
    _requestedClassAllowed = _requestedClass in _allFPVClasses && {_catalogAllowed};
};
if (!_requestedClassAllowed) exitWith {
    [format ["FPV exact class %1 отсутствует в опубликованном installed-assets catalog", _requestedClass]] call DRO2026_fnc_log;
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
        (_name find "_kvn_at") >= 0 || {(_name find "pg7vl") >= 0}
    } else {
        if (_isMan) then {
            (_name find "_kvn_ap") >= 0 || {(_name find "og7v") >= 0} || {(_name find "rkg") >= 0}
        } else {
            (_name find "_kvn_ap") >= 0 || {(_name find "ied") >= 0} || {(_name find "og7v") >= 0}
        }
    }
};
private _droneClass = if (_requestedClass != "") then {
    _requestedClass
} else {
    if (count _preferred > 0) then {
        private _fiberPreferred = _preferred select {[_x] call DRO2026_fnc_isFiberOpticDrone};
        if (DRO2026_alertLevel >= 0.62 && {count _fiberPreferred > 0}) then {selectRandom _fiberPreferred} else {selectRandom _preferred}
    } else {if (count _pool > 0) then {selectRandom _pool} else {_fallback}}
};
private _droneCfg = configFile >> "CfgVehicles" >> _droneClass;
if (!isClass _droneCfg || {!(_droneClass isKindOf "Air")} || {_requestedClass == "" && {_sideNumber >= 0 && {getNumber (_droneCfg >> "side") != _sideNumber}}}) exitWith {
    [format ["FPV launch cancelled: invalid class %1", _droneClass]] call DRO2026_fnc_log;
    call _refundReservation;
    objNull
};
private _usingNativeFPV = _droneClass != _fallback;

private _targetATL = ASLToATL _targetASL;
private _direction = _origin getDir _targetATL;
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
_drone setVariable ["DRO2026_authorizedControllerUid", if (!isNull _supportOwner) then {getPlayerUID _supportOwner} else {""}, true];
_drone setVariable ["DRO2026_missionId", _missionId, true];
[_drone, "FPV_TERMINAL", "FPV_AUTOPILOT_STARTED", "NONE"] call DRO2026_fnc_setFlightAuthority;
_drone setVariable ["DRO2026_siteId", _siteId, true];
_drone setVariable ["ddtExclude", true, true];
_drone setVariable ["DRO2026_ownedFPV", true, true];
_crewGroup setVariable ["ddtExclude", true, true];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _drone]};
DRO2026_activeDrones pushBack _drone;
DRO2026_managedVehicles pushBackUnique _drone;
_crewGroup setBehaviourStrong "CARELESS";
_crewGroup setCombatMode "BLUE";
_crewGroup setSpeedMode "FULL";
private _initialDirection = [sin _direction, cos _direction, 0];
private _initialRight = _initialDirection vectorCrossProduct [0,0,1];
private _initialUp = _initialRight vectorCrossProduct _initialDirection;
_drone setVectorDirAndUp [_initialDirection, _initialUp];
_drone setVelocity (_initialDirection vectorMultiply 24);
private _eventSubject = if (_reservationNodeId != "") then {_reservationNodeId} else {if (_siteId != "") then {_siteId} else {"FPV_LAUNCH"}};
["DRONE_LAUNCHED", createHashMapFromArray [
    ["role", "FPV"], ["class", _droneClass], ["side", str _side],
    ["contactId", _contact getOrDefault ["id", ""]], ["subjectId", _contact getOrDefault ["subjectId", ""]],
    ["siteId", _siteId], ["reservationNodeId", _reservationNodeId], ["manual", _allowPlayerControl],
    ["spawnATL", +_spawnPosition], ["targetASL", +_targetASL], ["missionId", _missionId]
], _eventSubject] call DRO2026_fnc_emitEvent;
[_drone, format ["FPV %1", getText (_droneCfg >> "displayName")], _side] spawn DRO2026_fnc_trackIncomingDrone;

if (_allowPlayerControl && {!isNull _supportOwner} && {_side == playersSide}) then {
    [_drone] remoteExecCall ["DRO2026_fnc_offerFPVControl", owner _supportOwner, false];
};

// Delegated orientation contract: _applyFlightVector, vectorCrossProduct and setVectorDirAndUp
// are implemented and validated in DRO2026_fnc_fpvAttackController.
private _controllerStartedAt = time;
private _controllerResult = [_drone, _contact, _side, _operator, _usingNativeFPV, _isArmored, _siteId] call DRO2026_fnc_fpvAttackController;
["FPV_MISSION_RESULT", createHashMapFromArray [
    ["missionId", _missionId], ["result", _controllerResult], ["class", _droneClass],
    ["targetASL", +_targetASL], ["lastPositionASL", if (isNull _drone) then {[]} else {getPosASL _drone}],
    ["duration", time - _controllerStartedAt]
], _eventSubject] call DRO2026_fnc_emitEvent;
if (_controllerResult == "DDT_CONTROLLED") then {[_drone, "DRONE_TWEAKS", "DDT_TAKEOVER", "FPV_TERMINAL"] call DRO2026_fnc_setFlightAuthority};
if (_controllerResult in ["YIELDED", "DDT_CONTROLLED"]) exitWith {
    [_drone, _crewGroup] spawn {
        params ["_controlledDrone", "_controlledGroup"];
        waitUntil {
            uiSleep 2;
            isNull _controlledDrone || {!alive _controlledDrone} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}
        };
        private _activeIndex = DRO2026_activeDrones find _controlledDrone;
        if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
        if (!isNull _controlledDrone && {!alive _controlledDrone}) then {deleteVehicleCrew _controlledDrone};
        if (!isNull _controlledGroup && {count units _controlledGroup == 0}) then {deleteGroup _controlledGroup};
    };
    _drone
};

[_drone, "NONE", "FPV_MISSION_COMPLETE", _drone getVariable ["DRO2026_flightAuthority", "NONE"]] call DRO2026_fnc_setFlightAuthority;
private _activeIndex = DRO2026_activeDrones find _drone;
if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
if (!isNull _drone) then {
    deleteVehicleCrew _drone;
    if (alive _drone) then {deleteVehicle _drone};
};
if (!isNull _crewGroup) then {deleteGroup _crewGroup};
_drone
