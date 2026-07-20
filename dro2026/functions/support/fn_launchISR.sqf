params [
    "_position", ["_origin", []], ["_operator", objNull], ["_requestedType", "AUTO"],
    ["_siteId", ""]
];
if (!isServer) exitWith {objNull};
private _refundReservation = {
    DRO2026_resources set ["friendlyISRStock", (DRO2026_resources getOrDefault ["friendlyISRStock", 0]) + 1];
    DRO2026_lastISRRequest = -999;
};
private _siteOperational = {
    [_siteId] call DRO2026_fnc_isSiteOperational
};
if (!isNull _operator && {!alive _operator}) exitWith {call _refundReservation; objNull};
if !(call _siteOperational) exitWith {call _refundReservation; objNull};

private _sideSuffix = [playersSide] call DRO2026_fnc_getSideSuffix;
private _sideNumber = [playersSide] call DRO2026_fnc_getSideNumber;
private _fallback = switch (playersSide) do {
    case west: {"B_UAV_01_F"};
    case resistance: {"I_UAV_01_F"};
    default {"O_UAV_01_F"};
};
private _filterForSide = {
    params ["_classes"];
    _classes select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg &&
        {_x isKindOf "Air"} &&
        {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
    }
};

private _pool = [DRO2026_assetRegistry getOrDefault ["PLAYER_ISR_UAV", []]] call _filterForSide;
private _microPool = [DRO2026_assetRegistry getOrDefault [format ["ISR_MICRO_%1", _sideSuffix], []]] call _filterForSide;
private _tacticalPool = [DRO2026_assetRegistry getOrDefault [format ["ISR_TACTICAL_%1", _sideSuffix], []]] call _filterForSide;
private _halePool = [DRO2026_assetRegistry getOrDefault [format ["ISR_HALE_%1", _sideSuffix], []]] call _filterForSide;
private _combinedPool = _pool + _microPool + _tacticalPool + _halePool;
private _allAllowed = _combinedPool arrayIntersect _combinedPool;
private _findByTokens = {
    params ["_classes", "_tokens"];
    private _matches = _classes select {
        private _name = toLowerANSI _x;
        (_tokens findIf {(_name find _x) >= 0}) >= 0
    };
    if (count _matches > 0) then {selectRandom _matches} else {""}
};

private _class = "";
private _offMap = false;
private _requestUpper = toUpperANSI _requestedType;
private _selectionValid = true;
if ((_requestUpper find "CLASS:") == 0) then {
    private _exact = _requestedType select [6];
    if !(_exact in _allAllowed) then {
        _selectionValid = false;
        [format ["Отменён ISR launch: exact class %1 больше не доступен в реестре", _exact]] call DRO2026_fnc_log;
    } else {
        _class = _exact;
        private _lowerExact = toLowerANSI _exact;
        _offMap = !(_exact isKindOf "UAV_01_base_F") && {(_lowerExact find "mavic") < 0} && {(_lowerExact find "quad") < 0};
    };
} else {
    switch _requestUpper do {
        case "MICRO": {
            if (count _microPool > 0) then {_class = selectRandom _microPool};
        };
        case "RQ7": {
            _class = [_tacticalPool + _pool, ["rq7", "shadow"]] call _findByTokens;
            _offMap = _class != "";
        };
        case "MQ4A": {
            _class = [_halePool + _pool, ["mq4"]] call _findByTokens;
            _offMap = _class != "";
        };
        case "TACTICAL": {
            if (count _tacticalPool > 0) then {_class = selectRandom _tacticalPool; _offMap = true};
        };
        case "HALE": {
            if (count _halePool > 0) then {_class = selectRandom _halePool; _offMap = true};
        };
        case "AUTO": {
            if (count _allAllowed > 0) then {_class = selectRandom _allAllowed};
            if (_class == "") then {
                private _fallbackCfg = configFile >> "CfgVehicles" >> _fallback;
                if (isClass _fallbackCfg && {_fallback isKindOf "Air"} && {_sideNumber < 0 || {getNumber (_fallbackCfg >> "side") == _sideNumber}}) then {_class = _fallback};
            };
            if (_class != "") then {
                private _lowerAuto = toLowerANSI _class;
                _offMap = !(_class isKindOf "UAV_01_base_F") && {(_lowerAuto find "mavic") < 0} && {(_lowerAuto find "quad") < 0};
            };
        };
        default {_selectionValid = false};
    };
};
if (!_selectionValid || {_class == ""}) exitWith {
    [format ["Отменён ISR launch: профиль %1 не имеет совместимого класса выбранной стороны", _requestedType]] call DRO2026_fnc_log;
    call _refundReservation;
    objNull
};
private _classCfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _classCfg || {!(_class isKindOf "Air")} || {_sideNumber >= 0 && {getNumber (_classCfg >> "side") != _sideNumber}}) exitWith {
    call _refundReservation;
    objNull
};
if !(call _siteOperational) exitWith {call _refundReservation; objNull};

private _lowerName = toLowerANSI _class;
private _isMicro = (_class isKindOf "UAV_01_base_F") || {(_lowerName find "mavic") >= 0} || {(_lowerName find "quad") >= 0};
private _isHALE = (_lowerName find "mq4") >= 0;
private _source = if (_isMicro) then {"MICRO_UAV"} else {if (_isHALE) then {"HALE"} else {"TACTICAL_UAV"}};
if (_isHALE) then {_offMap = true};
if (count _origin < 2) then {_origin = ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode};
private _spawn = if (_offMap) then {
    private _axis = DRO2026_theaterLayout getOrDefault ["AXIS", DRO2026_theaterNodes getOrDefault ["AXIS", 90]];
    private _distance = if (_isHALE) then {12000} else {9000};
    private _raw = _position getPos [_distance, (_axis + 180) mod 360];
    private _margin = 300;
    [
        ((_raw select 0) max _margin) min (worldSize - _margin),
        ((_raw select 1) max _margin) min (worldSize - _margin),
        if (_isHALE) then {880} else {420}
    ]
} else {
    _origin vectorAdd [0, 0, if (_isMicro) then {90} else {210}]
};
private _spawnDirection = _spawn getDir _position;
private _uav = createVehicle [_class, _spawn, [], 0, "FLY"];
if (isNull _uav) exitWith {
    call _refundReservation;
    objNull
};
_uav setDir _spawnDirection;
_uav setPosATL _spawn;
private _group = playersSide createVehicleCrew _uav;
if (isNull _group || {isNull (driver _uav)}) exitWith {
    deleteVehicleCrew _uav;
    deleteVehicle _uav;
    if (!isNull _group) then {deleteGroup _group};
    call _refundReservation;
    objNull
};
private _height = if (_isMicro) then {115} else {if (_isHALE) then {900} else {320}};
private _initialSpeed = if (_isMicro) then {18} else {if (_isHALE) then {105} else {72}};
_uav setVelocity [sin _spawnDirection * _initialSpeed, cos _spawnDirection * _initialSpeed, 0];
_uav flyInHeight _height;
_uav setVariable ["DRO2026_operator", _operator];
_uav setVariable ["DRO2026_siteId", _siteId, true];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _uav]};
DRO2026_activeDrones pushBack _uav;
DRO2026_managedVehicles pushBackUnique _uav;
_group setBehaviourStrong "CARELESS";
_group setCombatMode "BLUE";
_group setSpeedMode "NORMAL";
["DRONE_LAUNCHED", createHashMapFromArray [["class", _class], ["role", "ISR"], ["source", _source], ["siteId", _siteId]], "FRIENDLY_ISR"] call DRO2026_fnc_emitEvent;

private _end = time + (if (_isMicro) then {360} else {if (_isHALE) then {720} else {520}});
private _angle = random 360;
private _lastEWProvocation = -999;
private _lastFalseContact = -999;
while {
    alive _uav &&
    {time < _end} &&
    {(isNull _operator) || {alive _operator}} &&
    {call _siteOperational} &&
    {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}
} do {
    _angle = (_angle + 12 + random 16) mod 360;
    private _baseRadius = if (_isMicro) then {240} else {if (_isHALE) then {1600} else {650}};
    private _orbitRadius = (_baseRadius + (-80 + random 160)) max 160;
    private _orbit = _position getPos [_orbitRadius, _angle];
    _orbit set [2, _height + (-18 + random 36)];
    if (!isNull (driver _uav)) then {(driver _uav) doMove _orbit};

    private _jamming = [getPosATL _uav, playersSide] call DRO2026_fnc_getJammingAtPosition;
    if (_jamming > 0.10 && {(time - _lastEWProvocation) > 55}) then {
        private _ewNode = DRO2026_networkNodes getOrDefault ["NODE_EW_01", createHashMap];
        if (count _ewNode > 0 && {!((_ewNode getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED"])}) then {
            _ewNode set ["emissionState", "BURST"];
            _ewNode set ["lastEmission", time];
            DRO2026_networkNodes set ["NODE_EW_01", _ewNode];
            private _ewPosition = _ewNode getOrDefault ["position", _position];
            private _estimate = _ewPosition getPos [120 + random (320 + 420 * _jamming), random 360];
            ["PLAYER", objNull, _estimate, 0.48 + (0.20 * _jamming), "ВЕРОЯТНЫЙ РЭБ", "ELINT", 260 + (420 * _jamming), "NODE_EW_01", 0.08] call DRO2026_fnc_addContact;
            ["EMISSION_DETECTED", createHashMapFromArray [["nodeId", "NODE_EW_01"], ["mode", "BURST"], ["jamming", _jamming]], "NODE_EW_01"] call DRO2026_fnc_emitEvent;
            ["NODE_EW_01"] spawn {
                params ["_nodeId"];
                sleep 28;
                private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
                private _status = _node getOrDefault ["status", "ACTIVE"];
                if (count _node > 0 && {!(_status in ["DESTROYED", "DISABLED", "CANCELLED"])} && {(_node getOrDefault ["emissionState", ""]) == "BURST"}) then {
                    _node set ["emissionState", "PASSIVE"];
                    DRO2026_networkNodes set [_nodeId, _node];
                };
            };
            _lastEWProvocation = time;
        };
    };

    private _nominalRadius = if (_isMicro) then {950} else {if (_isHALE) then {2600} else {1650}};
    private _scanRadius = _nominalRadius * (1 - (0.52 * _jamming));
    private _baseConfidence = (if (_isMicro) then {0.88} else {if (_isHALE) then {0.82} else {0.86}}) - (0.28 * _jamming);
    private _baseUncertainty = (if (_isMicro) then {42} else {if (_isHALE) then {170} else {82}}) + (310 * _jamming);

    {
        private _managedGroup = _x;
        if (!isNull _managedGroup && {(side _managedGroup) == enemySide} && {count units _managedGroup > 0}) then {
            private _target = vehicle (leader _managedGroup);
            if (alive _target && {_target distance2D _uav < _scanRadius}) then {
                private _targetASL = aimPos _target;
                if (_targetASL isEqualTo [0,0,0]) then {_targetASL = getPosASL _target vectorAdd [0,0,1.5]};
                private _visibility = ([_uav, "VIEW"] checkVisibility [eyePos _uav, _targetASL]);
                if (_visibility > 0.08) then {
                    ["PLAYER", _target, getPosATL _target, (_baseConfidence + (_visibility * 0.1)) min 0.97, "БПЛА", _source, _baseUncertainty] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedGroups;

    {
        private _siteRecord = _x;
        private _sitePosition = _siteRecord getOrDefault ["position", []];
        if (count _sitePosition > 1 && {_sitePosition distance2D _uav < _scanRadius}) then {
            [
                "PLAYER", _siteRecord getOrDefault ["object", objNull], _sitePosition,
                (_baseConfidence + 0.05) min 0.92, _siteRecord getOrDefault ["type", "ОБЪЕКТ"],
                _source, _baseUncertainty, _siteRecord getOrDefault ["networkNodeId", ""], 0.03 + (0.10 * _jamming)
            ] call DRO2026_fnc_addContact;
        };
    } forEach (DRO2026_sites select {
        private _status = _x getOrDefault ["status", "ACTIVE"];
        private _object = _x getOrDefault ["object", objNull];
        !(_status in ["DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"]) &&
        {isNull _object || {alive _object}} && {
            (_x getOrDefault ["type", ""]) find "ENEMY" >= 0 ||
            {(_x getOrDefault ["type", ""]) in ["ARTILLERY_SITE", "AIR_DEFENCE_SITE", "LOGISTICS_HUB", "LOGISTICS_RUN", "CONVOY", "EW_SITE", "FPV_TEAM", "STRATEGIC_DRONE_SITE"]}
        }
    });

    if (_jamming > 0.55 && {(time - _lastFalseContact) > 70} && {random 1 < (0.08 * _jamming)}) then {
        private _falsePosition = _position getPos [350 + random 1100, random 360];
        ["PLAYER", objNull, _falsePosition, 0.28 + random 0.18, selectRandom ["ВОЗМОЖНАЯ ТЕХНИКА", "РАДИОИЗЛУЧЕНИЕ", "НЕЯСНЫЙ ОБЪЕКТ"], _source, 420 + random 500, "", 0.55 + (0.25 * _jamming)] call DRO2026_fnc_addContact;
        _lastFalseContact = time;
    };
    sleep 4;
};

private _returned = false;
if (
    alive _uav &&
    {call _siteOperational} &&
    {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} &&
    {!isNull (driver _uav)}
) then {
    (driver _uav) doMove _origin;
    private _returnDeadline = time + (if (_isMicro) then {75} else {if (_isHALE) then {240} else {190}});
    private _recoveryRadius = if (_isMicro) then {120} else {350};
    waitUntil {
        sleep 2;
        !alive _uav ||
        {_uav distance2D _origin < _recoveryRadius} ||
        {time > _returnDeadline} ||
        {!(call _siteOperational)} ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    _returned = alive _uav &&
        {_uav distance2D _origin < _recoveryRadius} &&
        {call _siteOperational} &&
        {!(missionNamespace getVariable ["DRO2026_missionEnding", false])};
};
if (_returned) then {
    DRO2026_resources set ["friendlyISRStock", (DRO2026_resources getOrDefault ["friendlyISRStock", 0]) + 1];
};
private _activeIndex = DRO2026_activeDrones find _uav;
if (_activeIndex >= 0) then {DRO2026_activeDrones deleteAt _activeIndex};
if (!isNull _uav) then {
    deleteVehicleCrew _uav;
    if (alive _uav) then {deleteVehicle _uav};
};
if (!isNull _group) then {deleteGroup _group};
private _eventType = if (_returned) then {"DRONE_RECOVERED"} else {"DRONE_LOST"};
[_eventType, createHashMapFromArray [["class", _class], ["role", "ISR"], ["returned", _returned], ["siteId", _siteId]], "FRIENDLY_ISR"] call DRO2026_fnc_emitEvent;
_uav
