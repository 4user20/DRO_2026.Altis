if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep (DRO2026_ENEMY_ISR_MIN_INTERVAL + random (DRO2026_ENEMY_ISR_MAX_INTERVAL - DRO2026_ENEMY_ISR_MIN_INTERVAL));
    if ((time - DRO2026_lastEnemyISR) < DRO2026_ENEMY_ISR_MIN_INTERVAL) then {continue};
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];
    if (_stock <= 0 || {(count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT}) then {continue};

    private _sites = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) in ["FPV_TEAM", "DRONE_SITE", "STRATEGIC_DRONE_SITE"] && {
            private _operator = _x getOrDefault ["operator", objNull];
            !isNull _operator && {alive _operator}
        }
    };
    if (count _sites == 0) then {continue};

    private _searchTargets = [];
    {
        private _site = _x;
        private _type = _site getOrDefault ["type", "FRIENDLY_SITE"];
        if (_type in ["FRIENDLY_HQ", "FRIENDLY_DRONE_SITE", "FRIENDLY_FPV_SITE", "FRIENDLY_LAYERED_AA", "FRIENDLY_LOGISTICS", "FRIENDLY_ARTILLERY"]) then {
            private _pos = _site getOrDefault ["position", []];
            if (count _pos > 1) then {
                private _priority = switch _type do {
                    case "FRIENDLY_HQ": {10};
                    case "FRIENDLY_LAYERED_AA": {9};
                    case "FRIENDLY_ARTILLERY": {8};
                    case "FRIENDLY_DRONE_SITE": {8};
                    case "FRIENDLY_FPV_SITE": {7};
                    case "FRIENDLY_LOGISTICS": {7};
                    default {5};
                };
                _searchTargets pushBack [_pos, _type, _site getOrDefault ["object", objNull], _site getOrDefault ["id", ""], _priority];
            };
        };
    } forEach DRO2026_sites;
    {
        private _position = _x getOrDefault ["position", []];
        if (count _position > 1) then {_searchTargets pushBack [_position, _x getOrDefault ["type", "FRIENDLY_POSITION"], _x getOrDefault ["object", objNull], _x getOrDefault ["id", ""], 5]};
    } forEach DRO2026_friendlyPositions;
    {
        if (!isNull _x && {alive _x}) then {
            private _vehicle = vehicle _x;
            _searchTargets pushBack [getPosATL _vehicle, if (_vehicle == _x) then {"PLAYER_GROUP"} else {"PLAYER_VEHICLE"}, _vehicle, format ["PLAYER:%1", getPlayerUID _x], if (_vehicle == _x) then {3} else {6}];
        };
    } forEach allPlayers;
    {
        private _asset = DRO2026_supportAssets get _x;
        if (!isNull _asset && {alive _asset}) then {
            _searchTargets pushBack [getPosATL _asset, if ((_x find "ARTY_") == 0) then {"FRIENDLY_ARTILLERY"} else {"FRIENDLY_SUPPORT"}, _asset, format ["SUPPORT:%1", netId _asset], 8];
        };
    } forEach keys DRO2026_supportAssets;
    if (count _searchTargets == 0) then {continue};
    _searchTargets = [_searchTargets, [], {-((_x select 4) + random 2)}, "ASCEND"] call BIS_fnc_sortBy;
    private _routeTargets = _searchTargets select [0, (count _searchTargets) min 4];

    private _site = selectRandom _sites;
    private _operator = _site getOrDefault ["operator", objNull];
    private _origin = _site getOrDefault ["position", ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
    private _pool = DRO2026_assetRegistry getOrDefault ["ENEMY_ISR_UAV", []];
    _pool = _pool select {isClass (configFile >> "CfgVehicles" >> _x) && {_x isKindOf "Air"}};
    private _class = "";
    if (enemySide == east && {"RUS_VKS_forpostru" in _pool} && {random 1 < 0.62}) then {_class = "RUS_VKS_forpostru"};
    if (_class == "" && {count _pool > 0}) then {_class = selectRandom _pool};
    if (_class == "") then {_class = if (enemySide == west) then {"B_UAV_02_dynamicLoadout_F"} else {if (enemySide == resistance) then {"I_UAV_02_dynamicLoadout_F"} else {"O_UAV_02_dynamicLoadout_F"}}};
    if (!isClass (configFile >> "CfgVehicles" >> _class)) then {continue};

    private _lower = toLowerANSI _class;
    private _isMicro = (_class isKindOf "UAV_01_base_F") || {(_lower find "mavic") >= 0} || {(_lower find "quad") >= 0};
    private _isLongRangeISR = !_isMicro;
    private _searchCenter = (_routeTargets select 0) select 0;
    private _spawn = if (_isLongRangeISR) then {
        private _axis = DRO2026_theaterLayout getOrDefault ["AXIS", 90];
        private _raw = _searchCenter getPos [9000 + random 4000, _axis mod 360];
        [((_raw select 0) max 350) min (worldSize - 350), ((_raw select 1) max 350) min (worldSize - 350), 420 + random 220]
    } else {
        _origin vectorAdd [0, 0, 85]
    };
    private _uav = createVehicle [_class, _spawn, [], 0, "FLY"];
    if (isNull _uav) then {continue};
    private _group = enemySide createVehicleCrew _uav;
    if (isNull _group || {isNull driver _uav}) then {
        deleteVehicleCrew _uav;
        deleteVehicle _uav;
        continue;
    };

    private _height = if (_isMicro) then {105} else {if ((_lower find "forpost") >= 0) then {520} else {320}};
    _uav flyInHeight _height;
    _uav setVariable ["DRO2026_operator", _operator];
    _operator setVariable ["DRO2026_activeUAV", _uav];
    DRO2026_activeDrones pushBack _uav;
    DRO2026_managedVehicles pushBackUnique _uav;
    DRO2026_resources set ["enemyDroneStock", (_stock - 1) max 0];
    DRO2026_lastEnemyISR = time;
    _group setBehaviourStrong "CARELESS";
    _group setCombatMode "BLUE";
    _group setSpeedMode "NORMAL";
    ["DRONE_LAUNCHED", createHashMapFromArray [["role", "ENEMY_ISR"], ["class", _class], ["sectors", count _routeTargets]], "NODE_DRONE_REAR_01"] call DRO2026_fnc_emitEvent;

    [_uav, _routeTargets, _isMicro, _operator, _origin, _height] spawn {
        params ["_uav", "_routeTargets", "_isMicro", "_operator", "_origin", "_height"];
        private _end = time + (if (_isMicro) then {360} else {620});
        private _routeIndex = 0;
        private _angle = random 360;
        private _lastSectorChange = -999;
        private _announced = false;
        while {alive _uav && {time < _end} && {alive _operator} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
            if ((time - _lastSectorChange) > (55 + random 35)) then {
                _routeIndex = (_routeIndex + 1) mod (count _routeTargets);
                _lastSectorChange = time;
            };
            private _sector = _routeTargets select _routeIndex;
            _sector params ["_sectorPos", "_sectorType", "_sectorObject", "_sectorId", "_sectorPriority"];
            _angle = (_angle + 13 + random 18) mod 360;
            private _radius = if (_isMicro) then {260 + random 170} else {650 + random 500};
            private _orbit = _sectorPos getPos [_radius, _angle];
            _orbit set [2, _height + (-20 + random 40)];
            if (!isNull driver _uav) then {(driver _uav) doMove _orbit};

            if (!_announced && {(allPlayers findIf {alive _x && {((vehicle _x) knowsAbout _uav) > 1.1 || {(vehicle _x) distance2D _uav < 900}}}) >= 0}) then {
                _announced = true;
                ["ACK", "Штаб: В районе работает разведывательный БПЛА противника."] call DRO2026_fnc_hqVoice;
            };

            private _scanRadius = if (_isMicro) then {950} else {2100};
            {
                private _playerUnit = _x;
                if (alive _playerUnit) then {
                    private _friendly = vehicle _playerUnit;
                    if (_friendly distance2D _uav < _scanRadius) then {
                        private _to = aimPos _friendly;
                        if (_to isEqualTo [0,0,0]) then {_to = getPosASL _friendly vectorAdd [0,0,1.5]};
                        private _vis = ([_uav, "VIEW"] checkVisibility [eyePos _uav, _to]);
                        if (_vis > 0.10) then {
                            private _classification = if (_friendly == _playerUnit) then {"PLAYER_GROUP"} else {"PLAYER_VEHICLE"};
                            ["ENEMY", _friendly, getPosATL _friendly, (0.58 + (_vis * 0.32)) min 0.94, _classification, if (_isMicro) then {"MICRO_UAV"} else {"TACTICAL_UAV"}, if (_isMicro) then {55} else {140}, format ["PLAYER:%1", getPlayerUID _playerUnit]] call DRO2026_fnc_addContact;
                            DRO2026_alertLevel = DRO2026_alertLevel max 0.54;
                        };
                    };
                };
            } forEach allPlayers;

            {
                _x params ["_targetPos", "_classification", "_targetObject", "_subjectId", "_priority"];
                if (_targetPos distance2D _uav < _scanRadius) then {
                    private _visible = true;
                    if (!isNull _targetObject) then {
                        private _aim = aimPos _targetObject;
                        if (_aim isEqualTo [0,0,0]) then {_aim = AGLToASL (_targetPos vectorAdd [0,0,2])};
                        _visible = ([_uav, "VIEW"] checkVisibility [eyePos _uav, _aim]) > 0.08;
                    };
                    if (_visible) then {
                        private _confidence = (0.62 + (_priority * 0.025)) min 0.92;
                        ["ENEMY", _targetObject, _targetPos, _confidence, _classification, if (_isMicro) then {"MICRO_UAV"} else {"TACTICAL_UAV"}, if (_isMicro) then {65} else {160}, _subjectId] call DRO2026_fnc_addContact;
                        DRO2026_alertLevel = DRO2026_alertLevel max 0.58;
                    };
                };
            } forEach _routeTargets;
            sleep 5;
        };
        if (alive _uav) then {
            if (!isNull driver _uav) then {(driver _uav) doMove _origin};
            sleep 20;
            if (alive _uav) then {deleteVehicleCrew _uav; deleteVehicle _uav};
        };
        private _index = DRO2026_activeDrones find _uav;
        if (_index >= 0) then {DRO2026_activeDrones deleteAt _index};
    };
};
