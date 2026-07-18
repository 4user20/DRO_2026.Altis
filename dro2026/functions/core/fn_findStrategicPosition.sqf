params ["_anchor", "_minDistance", "_maxDistance", "_bearing", ["_spread", 80], ["_requireRoad", false], ["_minSeparation", 900]];
private _world = worldSize;
private _best = [];
private _bestScore = -1e9;
private _bestAny = [];
private _bestAnyScore = -1e9;

for "_i" from 0 to 90 do {
    private _distanceFactor = 1 - (floor (_i / 30) * 0.14);
    private _distance = (_minDistance * _distanceFactor) + random (((_maxDistance - _minDistance) * _distanceFactor) max 1);
    private _direction = _bearing - (_spread / 2) + random _spread;
    private _candidate = _anchor getPos [_distance, _direction];
    _candidate set [2, 0];
    private _inside = (_candidate select 0) > 650 && {(_candidate select 1) > 650} && {(_candidate select 0) < (_world - 650)} && {(_candidate select 1) < (_world - 650)};
    if (_inside && {!surfaceIsWater _candidate}) then {
        private _roadPenalty = 0;
        if (_requireRoad) then {
            private _road = [_candidate, 1400] call BIS_fnc_nearestRoad;
            if (!isNull _road) then {
                _roadPenalty = _candidate distance2D _road;
                _candidate = getPosATL _road;
            } else {
                _inside = false;
            };
        };
        if (_inside) then {
            private _safe = [_candidate, 0, 240, 7, 0, 0.35, 0, [], [_candidate, _candidate]] call BIS_fnc_findSafePos;
            if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
            private _separation = if (count DRO2026_reservedObjectivePositions == 0) then {99999} else {
                private _distances = DRO2026_reservedObjectivePositions apply {_candidate distance2D _x};
                selectMin _distances
            };
            private _actualDistance = _anchor distance2D _candidate;
            private _score = (_separation min 5000) - (_roadPenalty * 0.25) - abs (_actualDistance - ((_minDistance + _maxDistance) / 2));
            if (_score > _bestAnyScore) then {_bestAny = _candidate; _bestAnyScore = _score};
            if (_separation >= _minSeparation && {_score > _bestScore}) then {_best = _candidate; _bestScore = _score};
        };
    };
};

if (count _best == 0) then {_best = _bestAny};
if (count _best == 0) then {
    // Last-resort ring search never returns the AO anchor unless the map geometry is completely unusable.
    for "_ring" from 1 to 20 do {
        private _distance = ((_minDistance max 1200) * (1 - (_ring * 0.035))) max 900;
        private _candidate = _anchor getPos [_distance, _bearing + (_ring * 37)];
        private _inside = (_candidate select 0) > 450 && {(_candidate select 1) > 450} && {(_candidate select 0) < (_world - 450)} && {(_candidate select 1) < (_world - 450)};
        if (_inside && {!surfaceIsWater _candidate}) exitWith {_best = _candidate};
    };
};
if (count _best == 0) then {
    private _fallback = [(_anchor select 0) max 700 min (_world - 700), (_anchor select 1) max 700 min (_world - 700), 0];
    _best = _fallback;
    [format ["Не удалось разнести стратегический узел от AO; применён ограниченный fallback %1", _best]] call DRO2026_fnc_log;
};
[_best select 0, _best select 1, 0]
