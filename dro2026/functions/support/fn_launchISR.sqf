params ["_position", ["_origin", []], ["_operator", objNull], ["_requestedType", "AUTO"]];
if (!isNull _operator && {!alive _operator}) exitWith {objNull};

private _sideSuffix = switch (playersSide) do {
    case west: {"WEST"};
    case resistance: {"GUER"};
    default {"EAST"};
};
private _sideNumber = switch (playersSide) do {
    case east: {0};
    case west: {1};
    case resistance: {2};
    default {-1};
};
private _fallback = switch (playersSide) do {
    case west: {"B_UAV_01_F"};
    case resistance: {"I_UAV_01_F"};
    default {"O_UAV_01_F"};
};
private _filterForSide = {
    params ["_classes"];
    _classes select {
        isClass (configFile >> "CfgVehicles" >> _x) &&
        {_x isKindOf "Air"} &&
        {_sideNumber < 0 || {getNumber (configFile >> "CfgVehicles" >> _x >> "side") == _sideNumber}}
    }
};

private _pool = [DRO2026_assetRegistry getOrDefault ["PLAYER_ISR_UAV", []]] call _filterForSide;
private _microPool = [DRO2026_assetRegistry getOrDefault [format ["ISR_MICRO_%1", _sideSuffix], []]] call _filterForSide;
private _tacticalPool = [DRO2026_assetRegistry getOrDefault [format ["ISR_TACTICAL_%1", _sideSuffix], []]] call _filterForSide;
private _halePool = [DRO2026_assetRegistry getOrDefault [format ["ISR_HALE_%1", _sideSuffix], []]] call _filterForSide;
private _findByTokens = {
    params ["_classes", "_tokens"];
    private _matches = _classes select {
        private _name = toLowerANSI _x;
        (_tokens findIf {(_name find _x) >= 0}) >= 0
    };
    if (count _matches > 0) then {selectRandom _matches} else {""}
};

private _class = _fallback;
private _offMap = false;
switch (toUpperANSI _requestedType) do {
    case "MICRO": {
        if (count _microPool > 0) then {_class = selectRandom _microPool};
    };
    case "RQ7": {
        private _selected = [_tacticalPool + _pool, ["rq7", "shadow"]] call _findByTokens;
        if (_selected != "") then {_class = _selected; _offMap = true};
    };
    case "MQ4A": {
        private _selected = [_halePool + _pool, ["mq4"]] call _findByTokens;
        if (_selected != "") then {_class = _selected; _offMap = true};
    };
    case "TACTICAL": {
        if (count _tacticalPool > 0) then {_class = selectRandom _tacticalPool; _offMap = true};
    };
    case "HALE": {
        if (count _halePool > 0) then {_class = selectRandom _halePool; _offMap = true};
    };
    default {
        if (count _pool > 0) then {
            _class = if (count _microPool > 0 && {random 1 > 0.72}) then {
                selectRandom _microPool
            } else {
                if (count _tacticalPool > 0 && {random 1 > 0.45}) then {
                    _offMap = true;
                    selectRandom _tacticalPool
                } else {
                    if (count _halePool > 0 && {random 1 > 0.82}) then {
                        _offMap = true;
                        selectRandom _halePool
                    } else {
                        selectRandom _pool
                    }
                }
            };
        };
    };
};
if (!isClass (configFile >> "CfgVehicles" >> _class) || {!(_class isKindOf "Air")}) then {_class = _fallback};

private _lowerName = toLowerANSI _class;
private _isMicro = (_class isKindOf "UAV_01_base_F") || {(_lowerName find "mavic") >= 0} || {(_lowerName find "quad") >= 0};
private _isHALE = (_lowerName find "mq4") >= 0;
if (_isHALE) then {_offMap = true};
if (count _origin < 2) then {_origin = getPosATL player};
private _spawn = if (_offMap) then {
    private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", 90];
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
private _uav = createVehicle [_class, _spawn, [], 0, "FLY"];
if (isNull _uav) exitWith {
    DRO2026_resources set ["friendlyISRStock", (DRO2026_resources getOrDefault ["friendlyISRStock", 0]) + 1];
    objNull
};
private _group = playersSide createVehicleCrew _uav;
private _height = if (_isMicro) then {115} else {if (_isHALE) then {900} else {320}};
_uav flyInHeight _height;
_uav setVariable ["DRO2026_operator", _operator];
if (!isNull _operator) then {_operator setVariable ["DRO2026_activeUAV", _uav]};
DRO2026_activeDrones pushBack _uav;
DRO2026_managedVehicles pushBackUnique _uav;
if (!isNull _group) then {
    _group setBehaviourStrong "CARELESS";
    _group setCombatMode "BLUE";
    _group setSpeedMode "NORMAL";
};

private _end = time + (if (_isMicro) then {360} else {if (_isHALE) then {720} else {520}});
private _angle = random 360;
while {alive _uav && {time < _end} && {(isNull _operator) || {alive _operator}}} do {
    _angle = (_angle + 12 + random 16) mod 360;
    private _baseRadius = if (_isMicro) then {240} else {if (_isHALE) then {1600} else {650}};
    private _orbitRadius = (_baseRadius + (-80 + random 160)) max 160;
    private _orbit = _position getPos [_orbitRadius, _angle];
    _orbit set [2, _height + (-18 + random 36)];
    if (!isNull (driver _uav)) then {(driver _uav) doMove _orbit};

    private _ew = DRO2026_resources getOrDefault ["enemyEW", 0];
    private _scanRadius = if (_isMicro) then {
        linearConversion [0, 100, _ew, 950, 520, true]
    } else {
        if (_isHALE) then {
            linearConversion [0, 100, _ew, 2600, 1350, true]
        } else {
            linearConversion [0, 100, _ew, 1650, 880, true]
        }
    };
    private _baseConfidence = linearConversion [0, 100, _ew, 0.88, 0.58, true];

    {
        private _managedGroup = _x;
        if (!isNull _managedGroup && {(side _managedGroup) == enemySide} && {count units _managedGroup > 0}) then {
            private _target = vehicle (leader _managedGroup);
            if (alive _target && {_target distance2D _uav < _scanRadius}) then {
                private _targetASL = aimPos _target;
                if (_targetASL isEqualTo [0,0,0]) then {_targetASL = getPosASL _target vectorAdd [0,0,1.5]};
                private _visibility = _uav checkVisibility [eyePos _uav, _targetASL];
                if (_visibility > 0.08) then {
                    ["PLAYER", _target, getPosATL _target, (_baseConfidence + (_visibility * 0.1)) min 0.97, "БПЛА"] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedGroups;

    {
        private _sitePosition = _x getOrDefault ["position", []];
        if (count _sitePosition > 1 && {_sitePosition distance2D _uav < _scanRadius}) then {
            ["PLAYER", _x getOrDefault ["object", objNull], _sitePosition, (_baseConfidence + 0.05) min 0.92, _x getOrDefault ["type", "ОБЪЕКТ"]] call DRO2026_fnc_addContact;
        };
    } forEach (DRO2026_sites select {
        (_x getOrDefault ["type", ""]) find "ENEMY" >= 0 ||
        {(_x getOrDefault ["type", ""]) in ["ARTILLERY_SITE", "AIR_DEFENCE_SITE", "LOGISTICS_RUN", "CONVOY"]}
    });
    sleep 4;
};
if (alive _uav) then {
    if (!isNull (driver _uav)) then {(driver _uav) doMove _origin};
    sleep 25;
    if (alive _uav) then {deleteVehicleCrew _uav; deleteVehicle _uav};
};
_uav
