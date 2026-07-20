params [
    ["_anchor", [], [[]]], ["_minDistance", 1800, [0]], ["_maxDistance", 8000, [0]],
    ["_preferredBearing", 0, [0]], ["_requireRoad", true, [true]], ["_deepRear", false, [true]], ["_reservationRadius", 900, [0]]
];
if (count _anchor < 2) exitWith {createHashMapFromArray [["ok", false], ["code", "ANCHOR_INVALID"]]};
private _livingPlayers = allPlayers select {!isNull _x && {!(_x isKindOf "VirtualMan_F")} && {alive _x}};
private _controlledUAVs = allUnitsUAV select {private _control = UAVControl _x; count _control >= 2 && {!isNull (_control select 0)}};
private _observers = _livingPlayers + _controlledUAVs;
private _minPlayerDistance = (((worldSize * 0.05) max 1800) min 5000) * (if (_deepRear) then {1.35} else {1});
private _candidatePositions = [];
if (!isNil "AOLocations") then {{private _position = _x param [0, []]; if (_position isEqualType [] && {count _position > 1}) then {_candidatePositions pushBackUnique +_position}} forEach AOLocations};
private _locationTypes = ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "CityCenter", "Strategic", "FlatAreaCity", "FlatAreaCitySmall"];
{_candidatePositions pushBackUnique (locationPosition _x)} forEach (nearestLocations [_anchor, _locationTypes, _maxDistance max 6000]);
for "_index" from 0 to 80 do {_candidatePositions pushBack (_anchor getPos [_minDistance + random ((_maxDistance - _minDistance) max 1), _preferredBearing - 80 + random 160])};
private _best = createHashMapFromArray [["ok", false], ["code", "NO_CANDIDATE"], ["score", -1e12]];
{
    private _candidate = +_x;
    if (count _candidate > 1 && {!surfaceIsWater _candidate}) then {
        private _distance = _anchor distance2D _candidate;
        if (_distance >= _minDistance && {_distance <= _maxDistance}) then {
            private _nearestObserver = if (count _observers == 0) then {1e9} else {selectMin (_observers apply {_candidate distance2D _x})};
            private _reservedDistance = if (count DRO2026_reservedObjectivePositions == 0) then {1e9} else {selectMin (DRO2026_reservedObjectivePositions apply {_candidate distance2D _x})};
            if (_nearestObserver >= _minPlayerDistance && {_reservedDistance >= _reservationRadius}) then {
                private _roads = _candidate nearRoads 650;
                private _road = if (count _roads > 0) then {_roads select 0} else {objNull};
                if (!_requireRoad || {!isNull _road}) then {
                    private _connectedRoads = if (isNull _road) then {[]} else {roadsConnectedTo _road};
                    if (!_requireRoad || {count _connectedRoads > 0}) then {
                        private _roadPosition = if (isNull _road) then {_candidate} else {getPosATL _road};
                        private _roadDirection = if (count _connectedRoads == 0) then {_preferredBearing} else {_road getDir (_connectedRoads select 0)};
                        private _sideOffset = _roadPosition getPos [22 + random 28, _roadDirection + selectRandom [75,105,255,285]];
                        private _safe = [_sideOffset,0,110,9,0,0.32,0,[],[_sideOffset,_sideOffset]] call BIS_fnc_findSafePos;
                        if !(_safe isEqualTo [0,0,0]) then {_sideOffset = _safe};
                        private _normal = surfaceNormal _sideOffset;
                        private _slopePenalty = (1 - (_normal select 2)) * 6000;
                        private _buildings = count (nearestObjects [_sideOffset, ["House","Building"], 350]);
                        private _combatPenalty = if ((nearestObjects [_sideOffset,["Man","LandVehicle"],180]) findIf {alive _x && {side _x != civilian}} >= 0) then {900} else {0};
                        private _roadPenalty = if (isNull _road) then {500} else {_sideOffset distance2D _road};
                        private _bearingPenalty = abs (((_anchor getDir _sideOffset) - _preferredBearing + 540) mod 360 - 180) * 3;
                        private _score = (_nearestObserver min 9000) + (_reservedDistance min 4000) + (_buildings min 12) * 45 + count _connectedRoads * 90 - _slopePenalty - _roadPenalty * 5 - _bearingPenalty - _combatPenalty;
                        if (_score > (_best getOrDefault ["score", -1e12])) then {
                            _best = createHashMapFromArray [["ok",true],["code","OK"],["position",[_sideOffset select 0,_sideOffset select 1,0]],["positionASL",AGLToASL _sideOffset],["road",_road],["roadAnchorNetId",if (isNull _road) then {""} else {netId _road}],["roadDirection",_roadDirection],["score",_score],["nearestPlayerDistance",_nearestObserver]];
                        };
                    };
                };
            };
        };
    };
} forEach _candidatePositions;
_best
