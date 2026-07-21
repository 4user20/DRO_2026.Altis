if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_enemyAirDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_enemyAirDirectorStarted",true];
missionNamespace setVariable ["DRO2026_activeEnemyAirMissions",0];
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _effects = [enemySide] call DRO2026_fnc_getOperationalEffects;
    private _interval = (260 + random 260) * (_effects getOrDefault ["decisionIntervalMultiplier",1]);
    sleep (_interval min 1100);
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};
    if (DRO2026_alertLevel < 0.55 || {DRO2026_fpsAverage < 25} || {(missionNamespace getVariable ["DRO2026_activeEnemyAirMissions",0]) >= 1}) then {continue};

    private _farpId = "NODE_FARP_01";
    private _farp = DRO2026_networkNodes getOrDefault [_farpId,createHashMap];
    private _farpStatus = toUpperANSI (_farp getOrDefault ["status","DISABLED"]);
    private _stocks = _farp getOrDefault ["stocks",createHashMap];
    if (count _farp == 0 || {_farpStatus in ["DESTROYED","DISABLED","CANCELLED"]} || {(_stocks getOrDefault ["HELICOPTER_MUNITIONS",0]) < 1} || {(_stocks getOrDefault ["FUEL",0]) < 1}) then {continue};

    private _enemySideNumber = [enemySide] call DRO2026_fnc_getSideNumber;
    private _pool = (DRO2026_assetRegistry getOrDefault ["ENEMY_CAS_AIR", []]) select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg && {_x isKindOf "Air"} && {_enemySideNumber < 0 || {getNumber (_cfg >> "side") == _enemySideNumber}}
    };
    if (count _pool == 0) then {continue};

    // No omniscient fallback: air missions require a fresh ENEMY contact produced by ISR/ground sensors.
    private _contacts = DRO2026_contacts select {
        (_x getOrDefault ["owner",""]) == "ENEMY" &&
        {(_x getOrDefault ["confidence",0]) >= 0.72} &&
        {(_x getOrDefault ["uncertaintyRadius",9999]) <= 260} &&
        {(time - (_x getOrDefault ["lastSeen",0])) < 240} &&
        {!((toUpperANSI (_x getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"])} && {
            private _target = _x getOrDefault ["target",objNull];
            !isNull _target && {alive _target}
        }
    };
    if (count _contacts == 0) then {continue};
    _contacts = [_contacts,[],{
        private _kind = toUpperANSI (_x getOrDefault ["classification",""]);
        private _priority = _x getOrDefault ["confidence",0];
        if ((_kind find "HQ") >= 0 || {(_kind find "AA") >= 0} || {(_kind find "ARTILLERY") >= 0}) then {_priority = _priority + 0.5};
        -_priority
    },"ASCEND"] call BIS_fnc_sortBy;
    private _contact = _contacts select 0;
    private _target = _contact getOrDefault ["target",objNull];
    if (isNull _target || {!alive _target}) then {continue};

    private _helicopters = _pool select {_x isKindOf "Helicopter"};
    private _planes = _pool - _helicopters;
    private _class = if (count _helicopters > 0 && {random 1 < 0.72}) then {selectRandom _helicopters} else {if (count _planes > 0) then {selectRandom _planes} else {selectRandom _pool}};
    private _home = +(_farp getOrDefault ["position",[]]);
    if (count _home < 2) then {continue};
    private _targetATL = getPosATL _target;
    private _spawn = _home getPos [500 + random 350,_home getDir _targetATL];
    private _isHeli = _class isKindOf "Helicopter";
    _spawn set [2,if (_isHeli) then {80} else {520}];
    private _air = createVehicle [_class,_spawn,[],0,"FLY"];
    if (isNull _air) then {continue};
    _air setDir (_spawn getDir _targetATL);
    _air setPosATL _spawn;
    private _group = enemySide createVehicleCrew _air;
    if (isNull _group || {isNull driver _air}) then {
        deleteVehicleCrew _air; deleteVehicle _air; if (!isNull _group) then {deleteGroup _group}; continue
    };
    _group addVehicle _air;
    [_group,false] call DRO2026_fnc_registerManagedGroup;
    DRO2026_managedVehicles pushBackUnique _air;
    private _weapon = [_air] call DRO2026_fnc_getStandoffWeapon;
    if !(_weapon getOrDefault ["ok",false]) then {
        deleteVehicleCrew _air; deleteVehicle _air; deleteGroup _group; continue
    };

    [_farpId,"HELICOPTER_MUNITIONS",-1,"AIR_MISSION_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
    [_farpId,"FUEL",-1,"AIR_MISSION_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
    missionNamespace setVariable ["DRO2026_activeEnemyAirMissions",(missionNamespace getVariable ["DRO2026_activeEnemyAirMissions",0]) + 1];
    private _missionId = format ["ENEMY_STANDOFF_%1_%2",floor (diag_tickTime*1000),floor random 100000];
    [_air,_target,enemySide,_home,_missionId,_group,_farpId] spawn {
        params ["_air","_target","_side","_home","_missionId","_group","_farpId"];
        private _result = [_air,_target,_side,_home,_missionId] call DRO2026_fnc_executeStandoffAirMission;
        if !(_result getOrDefault ["ok",false]) then {
            [_farpId,"HELICOPTER_MUNITIONS",1,"AIR_MISSION_NO_RELEASE_REFUND"] call DRO2026_fnc_changeNetworkNodeStock;
        };
        private _return = +_home; _return set [2,if (_air isKindOf "Helicopter") then {100} else {650}];
        if (!isNull _air && {alive _air} && {!isNull driver _air}) then {(driver _air) doMove _return};
        private _deadline = time + 180;
        waitUntil {sleep 2; isNull _air || {!alive _air} || {_air distance2D _home < 500} || {time > _deadline} || {missionNamespace getVariable ["DRO2026_missionEnding",false]}};
        if (!isNull _air) then {deleteVehicleCrew _air; if (alive _air) then {deleteVehicle _air}};
        if (!isNull _group) then {deleteGroup _group};
        missionNamespace setVariable ["DRO2026_activeEnemyAirMissions",((missionNamespace getVariable ["DRO2026_activeEnemyAirMissions",1]) - 1) max 0];
        ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","COMPLETE"],["result",_result getOrDefault ["code",""]]],_missionId] call DRO2026_fnc_emitEvent;
    };
};