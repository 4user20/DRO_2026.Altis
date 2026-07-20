params [
    ["_anchor",[],[[]]],["_minDistance",1800,[0]],["_maxDistance",8000,[0]],
    ["_preferredBearing",0,[0]],["_requireRoad",true,[true]],["_deepRear",false,[true]],
    ["_reservationRadius",900,[0]]
];
private _result = createHashMapFromArray [
    ["ok",false],["code","NO_CANDIDATE"],["positionATL",[]],["positionASL",[]],
    ["position",[]],["road",objNull],["roadFound",false],["roadAnchorNetId",""],
    ["heading",_preferredBearing],["roadDirection",_preferredBearing],
    ["fallbackUsed",false],["fallbackReason",""],["distanceToRoad",-1],
    ["score",-1e12],["nearestPlayerDistance",-1]
];
if !(_anchor isEqualType [] && {count _anchor >= 2}) exitWith {
    _result set ["code","ANCHOR_INVALID"]; _result
};
private _normalizeATL = {
    params ["_position"];
    if !(_position isEqualType [] && {count _position >= 2}) exitWith {[]};
    [
        _position param [0,0,[0]],
        _position param [1,0,[0]],
        _position param [2,0,[0]]
    ]
};
private _anchor3D = [_anchor] call _normalizeATL;
private _livingPlayers = allPlayers select {!isNull _x && {!(_x isKindOf "VirtualMan_F")} && {alive _x}};
private _controlledUAVs = allUnitsUAV select {
    private _control = UAVControl _x;
    count _control >= 2 && {!isNull (_control select 0)}
};
private _observers = _livingPlayers + _controlledUAVs;
private _minPlayerDistance = (((worldSize * 0.05) max 1800) min 5000) * (if (_deepRear) then {1.35} else {1});
private _candidatePositions = [];
if (!isNil "AOLocations") then {
    {
        private _position = _x param [0,[]];
        private _normalized = [_position] call _normalizeATL;
        if (count _normalized == 3) then {_candidatePositions pushBackUnique _normalized};
    } forEach AOLocations;
};
private _locationTypes = ["NameCityCapital","NameCity","NameVillage","NameLocal","CityCenter","Strategic","FlatAreaCity","FlatAreaCitySmall"];
{
    private _locationAGL = locationPosition _x;
    if (_locationAGL isEqualType [] && {count _locationAGL >= 2}) then {
        _candidatePositions pushBackUnique [
            _locationAGL param [0,0,[0]],
            _locationAGL param [1,0,[0]],
            0
        ];
    };
} forEach (nearestLocations [_anchor3D,_locationTypes,_maxDistance max 6000]);
for "_index" from 0 to 80 do {
    _candidatePositions pushBack ([_anchor3D getPos [
        _minDistance + random ((_maxDistance - _minDistance) max 1),
        _preferredBearing - 80 + random 160
    ]] call _normalizeATL);
};

private _evaluate = {
    params ["_candidate","_allowRoadFallback"];
    private _candidate3D = [_candidate] call _normalizeATL;
    if (count _candidate3D != 3 || {surfaceIsWater _candidate3D}) exitWith {};
    private _distance = _anchor3D distance2D _candidate3D;
    if (_distance < _minDistance || {_distance > _maxDistance}) exitWith {};
    private _nearestObserver = if (count _observers == 0) then {1e9} else {
        selectMin (_observers apply {_candidate3D distance2D _x})
    };
    private _reservedDistance = if (count DRO2026_reservedObjectivePositions == 0) then {1e9} else {
        selectMin (DRO2026_reservedObjectivePositions apply {_candidate3D distance2D _x})
    };
    if (_nearestObserver < _minPlayerDistance || {_reservedDistance < _reservationRadius}) exitWith {};

    private _roads = _candidate3D nearRoads (if (_allowRoadFallback) then {1600} else {650});
    private _road = if (count _roads > 0) then {
        ([_roads,[],{_candidate3D distance2D _x},"ASCEND"] call BIS_fnc_sortBy) select 0
    } else {objNull};
    if (_requireRoad && {isNull _road}) exitWith {};
    private _connectedRoads = if (isNull _road) then {[]} else {roadsConnectedTo [_road,_allowRoadFallback]};
    if (_requireRoad && {count _connectedRoads == 0} && {!_allowRoadFallback}) exitWith {};

    private _roadPosition = if (isNull _road) then {_candidate3D} else {[getPosATL _road] call _normalizeATL};
    private _roadDirection = if (count _connectedRoads == 0) then {_preferredBearing} else {_road getDir (_connectedRoads select 0)};
    private _sideOffset = [_roadPosition getPos [22 + random 28,_roadDirection + selectRandom [75,105,255,285]]] call _normalizeATL;
    private _safe = [_sideOffset,0,110,9,0,0.32,0,[],[_sideOffset,_sideOffset]] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) then {_sideOffset = [_safe] call _normalizeATL};
    if (count _sideOffset != 3) exitWith {};

    private _normal = surfaceNormal _sideOffset;
    private _slopePenalty = (1 - (_normal param [2,1,[0]])) * 6000;
    private _buildings = count (nearestObjects [_sideOffset,["House","Building"],350]);
    private _combatPenalty = if ((nearestObjects [_sideOffset,["Man","LandVehicle"],180]) findIf {
        alive _x && {side _x != civilian}
    } >= 0) then {900} else {0};
    private _distanceToRoad = if (isNull _road) then {-1} else {_sideOffset distance2D _road};
    private _roadPenalty = if (_distanceToRoad < 0) then {500} else {_distanceToRoad};
    private _bearingPenalty = abs (((_anchor3D getDir _sideOffset) - _preferredBearing + 540) mod 360 - 180) * 3;
    private _score = (_nearestObserver min 9000) + (_reservedDistance min 4000) +
        (_buildings min 12) * 45 + count _connectedRoads * 90 -
        _slopePenalty - _roadPenalty * 5 - _bearingPenalty - _combatPenalty;
    if (_score > (_result getOrDefault ["score",-1e12])) then {
        private _positionATL = +_sideOffset;
        private _positionASL = ATLToASL _positionATL;
        _result = createHashMapFromArray [
            ["ok",true],["code","OK"],["positionATL",_positionATL],["position",+_positionATL],
            ["positionASL",_positionASL],["road",_road],["roadFound",!isNull _road],
            ["roadAnchorNetId",if (isNull _road) then {""} else {netId _road}],
            ["heading",_roadDirection],["roadDirection",_roadDirection],
            ["fallbackUsed",_allowRoadFallback],["fallbackReason",if (_allowRoadFallback) then {"EXPANDED_ROAD_RADIUS"} else {""}],
            ["distanceToRoad",_distanceToRoad],["score",_score],["nearestPlayerDistance",_nearestObserver]
        ];
    };
};

{[_x,false] call _evaluate} forEach _candidatePositions;
if !(_result getOrDefault ["ok",false]) then {
    {[_x,true] call _evaluate} forEach _candidatePositions;
};
if !(_result getOrDefault ["ok",false]) then {
    private _fallback = [_anchor3D,0,900,9,0,0.35,0,[],[_anchor3D,_anchor3D]] call BIS_fnc_findSafePos;
    _fallback = [_fallback] call _normalizeATL;
    if (count _fallback == 3 && {!surfaceIsWater _fallback} && {!_requireRoad}) then {
        _result set ["ok",true];
        _result set ["code","FALLBACK_SAFE_POSITION"];
        _result set ["positionATL",+_fallback];
        _result set ["position",+_fallback];
        _result set ["positionASL",ATLToASL _fallback];
        _result set ["fallbackUsed",true];
        _result set ["fallbackReason","NO_ROAD_REQUIRED_SAFE_POSITION"];
    } else {
        _result set ["code",if (_requireRoad) then {"ROAD_REQUIRED_NOT_FOUND"} else {"NO_SAFE_POSITION"}];
        _result set ["fallbackUsed",true];
        _result set ["fallbackReason","SPAWN_MUST_BE_SKIPPED"];
    };
};
_result
