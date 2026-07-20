if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_enemyISRDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_enemyISRDirectorStarted",true];
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _sensorMultiplier = missionNamespace getVariable ["DRO2026_enemySensorIntervalMultiplier",1];
    sleep (((DRO2026_ENEMY_ISR_MIN_INTERVAL + random (DRO2026_ENEMY_ISR_MAX_INTERVAL - DRO2026_ENEMY_ISR_MIN_INTERVAL)) * _sensorMultiplier) min 1400);
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};
    if ((time - DRO2026_lastEnemyISR) < (DRO2026_ENEMY_ISR_MIN_INTERVAL * _sensorMultiplier)) then {continue};

    private _effects = [enemySide] call DRO2026_fnc_getOperationalEffects;
    private _sensorFactor = _effects getOrDefault ["sensorFactor",0];
    private _commandFactor = _effects getOrDefault ["commandFactor",0];
    if (_sensorFactor <= 0.08 || {_commandFactor <= 0.08}) then {continue};
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock",0];
    if (_stock <= 0 || {(count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT}) then {continue};

    private _sites = DRO2026_sites select {
        (_x getOrDefault ["type",""]) in ["FPV_TEAM","DRONE_SITE","STRATEGIC_DRONE_SITE"] && {
            private _operator = _x getOrDefault ["operator",objNull];
            !isNull _operator && {alive _operator} && {!((toUpperANSI (_x getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])}
        }
    };
    if (count _sites == 0) then {continue};

    private _searchTargets = [];
    {
        private _nodeId = _x;
        private _node = DRO2026_networkNodes get _nodeId;
        private _side = _node getOrDefault ["side",sideUnknown];
        private _status = toUpperANSI (_node getOrDefault ["status","ACTIVE"]);
        private _type = toUpperANSI (_node getOrDefault ["type","UNKNOWN"]);
        private _position = _node getOrDefault ["position",[]];
        if (_side == playersSide && {!(_status in ["DESTROYED","DISABLED","CANCELLED"])} && {count _position >= 2}) then {
            private _priority = switch _type do {
                case "HQ": {10};
                case "AA_LONG": {9};
                case "LOGISTICS_HUB": {9};
                case "ARTILLERY_SITE": {8};
                case "STRATEGIC_DRONE_SITE": {8};
                case "FARP": {8};
                case "FPV_TEAM": {7};
                default {5};
            };
            private _refs = (_node getOrDefault ["physicalRefs",[]]) select {!isNull _x && {alive _x}};
            private _object = if (count _refs > 0) then {_refs select 0} else {objNull};
            _searchTargets pushBack [_position,_type,_object,_nodeId,_priority];
        };
    } forEach keys DRO2026_networkNodes;
    {
        if (!isNull _x && {alive _x}) then {
            private _vehicle = vehicle _x;
            _searchTargets pushBack [getPosATL _vehicle,if (_vehicle == _x) then {"PLAYER_GROUP"} else {"PLAYER_VEHICLE"},_vehicle,format ["PLAYER:%1",getPlayerUID _x],if (_vehicle == _x) then {3} else {6}];
        };
    } forEach (allPlayers select {!(_x isKindOf "VirtualMan_F")});
    if (count _searchTargets == 0) then {continue};
    _searchTargets = [_searchTargets,[],{-((_x select 4) + random 1.5)},"ASCEND"] call BIS_fnc_sortBy;
    private _routeTargets = _searchTargets select [0,(count _searchTargets) min 4];

    private _site = selectRandom _sites;
    private _operator = _site getOrDefault ["operator",objNull];
    private _origin = _site getOrDefault ["position",["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
    private _sideNumber = [enemySide] call DRO2026_fnc_getSideNumber;
    private _pool = (DRO2026_assetRegistry getOrDefault ["ENEMY_ISR_UAV",[]]) select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg && {_x isKindOf "Air"} && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
    };
    if (count _pool == 0) then {continue};
    private _class = if (enemySide == east && {"RUS_VKS_forpostru" in _pool} && {random 1 < 0.62}) then {"RUS_VKS_forpostru"} else {selectRandom _pool};
    private _lower = toLowerANSI _class;
    private _isMicro = (_class isKindOf "UAV_01_base_F") || {(_lower find "mavic") >= 0} || {(_lower find "quad") >= 0};
    private _center = (_routeTargets select 0) select 0;
    private _spawn = if (_isMicro) then {_origin vectorAdd [0,0,85]} else {
        private _axis = DRO2026_theaterLayout getOrDefault ["AXIS",90];
        private _raw = _center getPos [9000 + random 4000,_axis mod 360];
        [((_raw select 0) max 350) min (worldSize - 350),((_raw select 1) max 350) min (worldSize - 350),420 + random 220]
    };
    private _direction = _spawn getDir _center;
    private _uav = createVehicle [_class,_spawn,[],0,"FLY"];
    if (isNull _uav) then {continue};
    _uav setDir _direction;
    _uav setPosATL _spawn;
    private _group = enemySide createVehicleCrew _uav;
    if (isNull _group || {isNull driver _uav}) then {
        deleteVehicleCrew _uav; deleteVehicle _uav; if (!isNull _group) then {deleteGroup _group}; continue
    };
    _group addVehicle _uav;
    private _height = if (_isMicro) then {105} else {if ((_lower find "forpost") >= 0) then {520} else {320}};
    private _speed = if (_isMicro) then {18} else {82};
    _uav setVelocity [sin _direction * _speed,cos _direction * _speed,0];
    _uav flyInHeight _height;
    _uav setVariable ["DRO2026_operator",_operator];
    _operator setVariable ["DRO2026_activeUAV",_uav];
    DRO2026_activeDrones pushBack _uav;
    DRO2026_managedVehicles pushBackUnique _uav;
    DRO2026_resources set ["enemyDroneStock",(_stock - 1) max 0];
    DRO2026_lastEnemyISR = time;
    _group setBehaviourStrong "CARELESS";
    _group setCombatMode "BLUE";
    _group setSpeedMode "NORMAL";
    ["DRONE_LAUNCHED",createHashMapFromArray [["role","ENEMY_ISR"],["class",_class],["sectors",count _routeTargets],["positionASL",getPosASL _uav]],"NODE_DRONE_REAR_01"] call DRO2026_fnc_emitEvent;

    [_uav,_routeTargets,_isMicro,_operator,_origin,_height,_group,_sensorFactor] spawn {
        params ["_uav","_routeTargets","_isMicro","_operator","_origin","_height","_group","_sensorFactor"];
        private _end = time + (if (_isMicro) then {360} else {620});
        private _routeIndex = 0;
        private _angle = random 360;
        private _lastSectorChange = -999;
        private _announced = false;
        while {alive _uav && {time < _end} && {alive _operator} && {!(missionNamespace getVariable ["DRO2026_missionEnding",false])}} do {
            if ((time - _lastSectorChange) > (55 + random 35)) then {_routeIndex = (_routeIndex + 1) mod (count _routeTargets); _lastSectorChange = time};
            private _sector = _routeTargets select _routeIndex;
            _sector params ["_sectorPos","_sectorType","_sectorObject","_sectorId","_sectorPriority"];
            _angle = (_angle + 13 + random 18) mod 360;
            private _radius = if (_isMicro) then {260 + random 170} else {650 + random 500};
            private _orbit = _sectorPos getPos [_radius,_angle];
            _orbit set [2,_height + (-20 + random 40)];
            if (!isNull driver _uav) then {(driver _uav) doMove _orbit};

            private _players = allPlayers select {!(_x isKindOf "VirtualMan_F")};
            if (!_announced && {(_players findIf {alive _x && {((vehicle _x) knowsAbout _uav) > 1.1 || {(vehicle _x) distance2D _uav < 900}}}) >= 0}) then {
                _announced = true;
                ["ACK","Штаб: В районе работает разведывательный БПЛА противника."] call DRO2026_fnc_hqVoice;
            };
            private _scanRadius = (if (_isMicro) then {950} else {2100}) * (_sensorFactor max 0.35);
            {
                if (alive _x) then {
                    private _friendly = vehicle _x;
                    if (_friendly distance2D _uav < _scanRadius) then {
                        private _aimASL = aimPos _friendly;
                        if (_aimASL isEqualTo [0,0,0]) then {_aimASL = getPosASL _friendly vectorAdd [0,0,1.5]};
                        private _visibility = [_uav,"VIEW"] checkVisibility [eyePos _uav,_aimASL];
                        if (_visibility > 0.10) then {
                            ["ENEMY",_friendly,getPosATL _friendly,(0.58 + (_visibility * 0.32)) min 0.94,if (_friendly == _x) then {"PLAYER_GROUP"} else {"PLAYER_VEHICLE"},if (_isMicro) then {"MICRO_UAV"} else {"TACTICAL_UAV"},if (_isMicro) then {55} else {140},format ["PLAYER:%1",getPlayerUID _x]] call DRO2026_fnc_addContact;
                            DRO2026_alertLevel = DRO2026_alertLevel max 0.54;
                        };
                    };
                };
            } forEach _players;
            {
                _x params ["_targetPos","_classification","_targetObject","_subjectId","_priority"];
                if (_targetPos distance2D _uav < _scanRadius) then {
                    private _visible = true;
                    if (!isNull _targetObject) then {
                        private _aimASL = aimPos _targetObject;
                        if (_aimASL isEqualTo [0,0,0]) then {_aimASL = ATLToASL (_targetPos vectorAdd [0,0,2])};
                        _visible = ([_uav,"VIEW"] checkVisibility [eyePos _uav,_aimASL]) > 0.08;
                    };
                    if (_visible) then {
                        ["ENEMY",_targetObject,_targetPos,(0.62 + (_priority * 0.025)) min 0.92,_classification,if (_isMicro) then {"MICRO_UAV"} else {"TACTICAL_UAV"},if (_isMicro) then {65} else {160},_subjectId] call DRO2026_fnc_addContact;
                        DRO2026_alertLevel = DRO2026_alertLevel max 0.58;
                    };
                };
            } forEach _routeTargets;
            sleep 5;
        };
        if (alive _uav && {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} && {!isNull driver _uav}) then {
            (driver _uav) doMove _origin;
            private _returnDeadline = time + 25;
            waitUntil {sleep 1; time > _returnDeadline || {!alive _uav} || {missionNamespace getVariable ["DRO2026_missionEnding",false]}};
        };
        private _index = DRO2026_activeDrones find _uav;
        if (_index >= 0) then {DRO2026_activeDrones deleteAt _index};
        if (!isNull _uav) then {deleteVehicleCrew _uav; if (alive _uav) then {deleteVehicle _uav}};
        if (!isNull _group) then {deleteGroup _group};
    };
};