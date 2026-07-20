params [["_request",createHashMap,[createHashMap]],["_requester",objNull,[objNull]]];
private _requestId = _request getOrDefault ["requestId",""];
private _reject = {params ["_code","_message"]; [false,_code,_message,_requestId,createHashMap] call DRO2026_fnc_makeResult};
if (!isServer) exitWith {[_request] call DRO2026_fnc_submitSupportRequest};
if (isNull _requester || {!alive _requester} || {!isPlayer _requester}) exitWith {["REQUESTER_INVALID","Requester is not a live player"] call _reject};
private _sideSuffix = [playersSide] call DRO2026_fnc_getSideSuffix; private _role = format ["INTERCEPTOR_%1",_sideSuffix];
private _interceptors = (DRO2026_assetRegistry getOrDefault [_role,[]]) select {
    private _descriptor = DRO2026_assetDescriptors getOrDefault [_x,createHashMap];
    isClass (configFile >> "CfgVehicles" >> _x) && {_x isKindOf "Air"} && {_descriptor getOrDefault ["canEngageAir",false]} && {"AIR_INTERCEPT" in (_descriptor getOrDefault ["capabilities",[]])}
};
private _requestedClass = _request getOrDefault ["assetClass",""]; if (_requestedClass != "") then {_interceptors = _interceptors select {_x == _requestedClass}};
if (count _interceptors == 0) exitWith {["NO_COMPATIBLE_INTERCEPTOR","No verified P1-Sun/Sting interceptor with air-capable muzzle/ammo is available"] call _reject};
private _target = objNull; private _targetMode = _request getOrDefault ["targetMode","OBJECT"];
if (_targetMode == "OBJECT") then {_target = objectFromNetId (_request getOrDefault ["targetObjectNetId",""])};
if (_targetMode == "CONTACT") then {private _contactId = _request getOrDefault ["contactId",""]; private _index = DRO2026_contacts findIf {(_x getOrDefault ["id",""]) == _contactId && {[_x] call DRO2026_fnc_isLiveContactSubject}}; if (_index >= 0) then {_target = (DRO2026_contacts select _index) getOrDefault ["subjectObject",objNull]}};
private _hostileUav = {
    params ["_candidate"];
    if (isNull _candidate || {!alive _candidate} || {!(_candidate isKindOf "Air")}) exitWith {false};
    private _cfg = configFile >> "CfgVehicles" >> typeOf _candidate;
    private _unmanned = getNumber (_cfg >> "isUav") > 0 || {isNull (effectiveCommander _candidate)};
    private _candidateSide = side _candidate; if (count crew _candidate > 0) then {_candidateSide = side (group ((crew _candidate) select 0))};
    _unmanned && {_candidateSide == enemySide}
};
if (isNull _target) then {private _candidates = ((vehicles + DRO2026_activeDrones) arrayIntersect (vehicles + DRO2026_activeDrones)) select {[_x] call _hostileUav}; if (count _candidates > 0) then {_candidates = [_candidates,[],{-((speed _x) + ((_x distance2D _requester) max 1) / -1000)},"ASCEND"] call BIS_fnc_sortBy; _target = _candidates select 0}};
if !([_target] call _hostileUav) exitWith {["TARGET_NOT_HOSTILE_UAV","Select a live hostile UAV or use AUTO"] call _reject};
private _class = _interceptors select 0; private _descriptor = DRO2026_assetDescriptors getOrDefault [_class,createHashMap];
private _airMuzzles = _descriptor getOrDefault ["airMuzzles",[]]; if (count _airMuzzles == 0) exitWith {["NO_COMPATIBLE_WEAPON","Interceptor has no verified air-capable muzzle"] call _reject};
private _sourceNodeId = "NODE_FRIENDLY_AA_LONG"; private _sourceNode = DRO2026_networkNodes getOrDefault [_sourceNodeId,createHashMap];
if (count _sourceNode == 0) exitWith {["SOURCE_NODE_MISSING","Friendly air-defence node is unavailable"] call _reject};
private _stocks = _sourceNode getOrDefault ["stocks",createHashMap]; if ((_stocks getOrDefault ["AA_MISSILES",0]) < 1) exitWith {["INSUFFICIENT_STOCK","No interceptor missile remains at the friendly AA node"] call _reject};
private _sourceASL = AGLToASL (_sourceNode getOrDefault ["position",getPosATL _requester]); private _targetASL = getPosASL _target; private _distance = _sourceASL distance2D _targetASL;
private _envelope = (_descriptor getOrDefault ["engagementRange",14000]) max 2500; if (_distance > _envelope) exitWith {["OUT_OF_RANGE","Hostile UAV is outside the verified interceptor envelope"] call _reject};
[_sourceNodeId,"AA_MISSILES",-1,"INTERCEPTOR_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
private _refund = {[_sourceNodeId,"AA_MISSILES",1,"INTERCEPTOR_REFUND"] call DRO2026_fnc_changeNetworkNodeStock};
private _spawnASL = _targetASL getPos [((_distance min 5500) max 2500),((_targetASL getDir _sourceASL)+(-12+random 24)) mod 360]; _spawnASL set [2,(getTerrainHeightASL _spawnASL)+350];
private _interceptor = createVehicle [_class,ASLToAGL _spawnASL,[],0,"FLY"];
if (isNull _interceptor) exitWith {call _refund; ["SPAWN_FAILED","Interceptor could not be materialized"] call _reject};
_interceptor setPosASL _spawnASL;
private _group = playersSide createVehicleCrew _interceptor;
if (isNull _group || {isNull (driver _interceptor)}) exitWith {deleteVehicleCrew _interceptor; deleteVehicle _interceptor; if (!isNull _group) then {deleteGroup _group}; call _refund; ["NO_CREW","Interceptor crew could not be materialized"] call _reject};
[_group,false] call DRO2026_fnc_registerManagedGroup; DRO2026_managedVehicles pushBackUnique _interceptor;
[_interceptor,"ARMA_AI","INTERCEPT_ROUTE","NONE"] call DRO2026_fnc_setFlightAuthority;
_group setBehaviourStrong "COMBAT"; _group setCombatMode "RED"; _group setSpeedMode "FULL";
_interceptor reveal [_target,4]; (driver _interceptor) doTarget _target;
[_group,_interceptor,_spawnASL,_targetASL,"STRIKE",500,500] call DRO2026_fnc_buildWaypointFlightPlan;
private _missionId = format ["INT_%1_%2",floor (diag_tickTime*1000),floor random 100000];
["INTERCEPT","LAUNCHED",createHashMapFromArray [["missionId",_missionId],["class",_class],["target",netId _target],["muzzle",_airMuzzles select 0]],_missionId] call DRO2026_fnc_logStructured;
[_missionId,_interceptor,_group,_target,_airMuzzles] spawn {
    params ["_missionId","_interceptor","_group","_target","_airMuzzles"];
    private _deadline = time + 240; private _shots = 0; private _maxShots = 3;
    while {alive _interceptor && {alive _target} && {time < _deadline} && {!(missionNamespace getVariable ["DRO2026_missionEnding",false])}} do {
        _interceptor reveal [_target,4]; if (!isNull (driver _interceptor)) then {(driver _interceptor) doTarget _target};
        if (_interceptor distance _target < 2600 && {_shots < _maxShots} && {canFire _interceptor}) then {
            private _muzzle = _airMuzzles select (_shots mod count _airMuzzles); private _aim = _interceptor aimedAtTarget [_target,_muzzle];
            if (_aim > 0.25) then {private _fired = _interceptor fireAtTarget [_target,_muzzle]; if (!_fired && {!isNull (driver _interceptor)}) then {(driver _interceptor) doFire _target}; _shots = _shots + 1};
        };
        sleep 2;
    };
    private _result = if (!alive _target) then {"KILL"} else {if (!alive _interceptor) then {"FAILED"} else {if (time >= _deadline) then {"LOST_TARGET"} else {"MISS"}}};
    ["INTERCEPT",_result,createHashMapFromArray [["missionId",_missionId],["target",netId _target],["shots",_shots]],_missionId] call DRO2026_fnc_logStructured;
    if (!isNull _interceptor) then {[_interceptor,"NONE","INTERCEPT_COMPLETE",_interceptor getVariable ["DRO2026_flightAuthority","NONE"]] call DRO2026_fnc_setFlightAuthority; deleteVehicleCrew _interceptor; if (alive _interceptor) then {deleteVehicle _interceptor}};
    if (!isNull _group) then {deleteGroup _group};
};
[true,"LAUNCHED","Interceptor launched against the selected hostile UAV",_requestId,createHashMapFromArray [["missionId",_missionId],["assetClass",_class],["targetObjectNetId",netId _target]]] call DRO2026_fnc_makeResult
