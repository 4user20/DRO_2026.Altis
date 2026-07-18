params ["_anchor", "_minDistance", "_maxDistance", "_bearing", ["_spread", 80], ["_requireRoad", false], ["_minSeparation", 900]];
private _world = worldSize;
private _best = [];
private _bestScore = -1e9;
for "_i" from 0 to 70 do {
    private _distance = _minDistance + random ((_maxDistance - _minDistance) max 1);
    private _direction = _bearing - (_spread / 2) + random _spread;
    private _candidate = _anchor getPos [_distance, _direction];
    _candidate set [2, 0];
    private _inside = (_candidate select 0) > 650 && {(_candidate select 1) > 650} && {(_candidate select 0) < (_world - 650)} && {(_candidate select 1) < (_world - 650)};
    if (_inside && {!surfaceIsWater _candidate}) then {
        private _roadPenalty = 0;
        if (_requireRoad) then {
            private _road = [_candidate, 1250] call BIS_fnc_nearestRoad;
            if (!isNull _road) then {
                _roadPenalty = _candidate distance2D _road;
                _candidate = getPosATL _road;
            } else {
                _inside = false;
            };
        };
        if (_inside) then {
            private _safe = [_candidate, 0, 220, 7, 0, 0.35, 0, [], [_candidate, _candidate]] call BIS_fnc_findSafePos;
            if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
            private _separation = if (count DRO2026_reservedObjectivePositions == 0) then {99999} else {
                private _distances = DRO2026_reservedObjectivePositions apply {_candidate distance2D _x};
                selectMin _distances
            };
            private _score = (_separation min 5000) - (_roadPenalty * 0.25) - abs (_distance - ((_minDistance + _maxDistance) / 2));
            if (_separation >= _minSeparation && {_score > _bestScore}) then {_best = _candidate; _bestScore = _score};
        };
    };
};
if (count _best == 0) then {
    _best = _anchor getPos [(_minDistance + _maxDistance) / 2, _bearing];
    if (surfaceIsWater _best) then {_best = _anchor};
};
[_best select 0, _best select 1, 0]
