params [
    ["_siteTypes", [], [[], ""]],
    ["_allowedZones", [], [[]]],
    ["_requireRoad", false, [true]],
    ["_minObserverDistance", 1800, [0]],
    ["_reservationRadius", 900, [0]],
    ["_stream", "STRATEGIC_SITE", [""]]
];

if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized", false]) then {
    [] call DRO2026_fnc_initStrategicOperationData;
};
if (_siteTypes isEqualType "") then {_siteTypes = [_siteTypes]};
_siteTypes = _siteTypes apply {toUpperANSI _x};
_allowedZones = _allowedZones apply {toUpperANSI _x};

private _observers = allPlayers select {!isNull _x && {alive _x} && {!(_x isKindOf "VirtualMan_F")}};
private _best = createHashMapFromArray [
    ["ok",false],["code","NO_CANDIDATE"],["positionATL",[]],["positionASL",[]],
    ["road",objNull],["roadFound",false],["heading",0],["fallbackUsed",false],
    ["fallbackReason",""],["distanceToRoad",-1],["score",-1e12],["candidateId",""]
];

{
    _x params ["_candidateId","_type","_basePosition","_zone","_baseWeight","_radius","_roadPreferred","_source"];
    private _typeAllowed = count _siteTypes == 0 || {(toUpperANSI _type) in _siteTypes};
    private _zoneAllowed = count _allowedZones == 0 || {(toUpperANSI _zone) in _allowedZones};
    if (_typeAllowed && {_zoneAllowed} && {_basePosition isEqualType []} && {count _basePosition >= 2}) then {
        for "_sampleIndex" from 0 to 9 do {
            private _distance = if (_sampleIndex == 0) then {0} else {[_radius max 1, format ["%1_%2_DISTANCE",_stream,_candidateId], 0] call DRO2026_fnc_seededRandom};
            private _bearing = [360, format ["%1_%2_BEARING",_stream,_candidateId], 0] call DRO2026_fnc_seededRandom;
            private _sample = if (_distance <= 0) then {+_basePosition} else {_basePosition getPos [_distance,_bearing]};
            if (count _sample == 2) then {_sample pushBack 0};
            _sample set [2,0];

            if (!surfaceIsWater _sample) then {
                private _road = objNull;
                private _roads = _sample nearRoads 900;
                if (count _roads > 0) then {
                    _roads = [_roads,[],{_sample distance2D _x},"ASCEND"] call BIS_fnc_sortBy;
                    _road = _roads select 0;
                };
                private _roadRequiredNow = _requireRoad || {_roadPreferred};
                if (!_roadRequiredNow || {!isNull _road}) then {
                    private _positionATL = +_sample;
                    private _heading = _bearing;
                    private _distanceToRoad = -1;
                    if (!isNull _road) then {
                        _distanceToRoad = _positionATL distance2D _road;
                        private _connected = roadsConnectedTo _road;
                        if (count _connected > 0) then {_heading = _road getDir (_connected select 0)};
                        if (_roadRequiredNow && {_distanceToRoad > 180}) then {
                            _positionATL = getPosATL _road;
                            private _sideRoll = [1,format ["%1_%2_SIDE",_stream,_candidateId],0] call DRO2026_fnc_seededRandom;
                            private _sideBearing = if (_sideRoll < 0.5) then {_heading + 90} else {_heading + 270};
                            _positionATL = _positionATL getPos [25 + ([35,format ["%1_%2_OFFSET",_stream,_candidateId],0] call DRO2026_fnc_seededRandom),_sideBearing];
                        };
                    };
                    if (count _positionATL == 2) then {_positionATL pushBack 0};
                    _positionATL set [2,0];

                    private _normal = surfaceNormal _positionATL;
                    private _slopePenalty = (1 - (_normal param [2,1])) * 7000;
                    private _observerDistance = if (count _observers == 0) then {1e9} else {selectMin (_observers apply {_positionATL distance2D _x})};
                    private _reservedDistance = if (count DRO2026_reservedObjectivePositions == 0) then {1e9} else {selectMin (DRO2026_reservedObjectivePositions apply {_positionATL distance2D _x})};
                    if (_observerDistance >= _minObserverDistance && {_reservedDistance >= _reservationRadius}) then {
                        private _roadBonus = if (isNull _road) then {0} else {600 - ((_distanceToRoad max 0) min 600)};
                        private _score = _baseWeight * 20 + (_observerDistance min 7000) * 0.35 + (_reservedDistance min 4000) * 0.25 + _roadBonus - _slopePenalty;
                        if (_score > (_best getOrDefault ["score",-1e12])) then {
                            private _positionASL = [_positionATL select 0,_positionATL select 1,getTerrainHeightASL _positionATL];
                            _best = createHashMapFromArray [
                                ["ok",true],["code","OK"],["positionATL",_positionATL],["positionASL",_positionASL],
                                ["road",_road],["roadFound",!isNull _road],["heading",_heading],
                                ["fallbackUsed",_sampleIndex > 0],["fallbackReason",if (_sampleIndex > 0) then {"SEEDED_JITTER"} else {""}],
                                ["distanceToRoad",_distanceToRoad],["score",_score],["candidateId",_candidateId],
                                ["siteType",_type],["zone",_zone],["source",_source],
                                ["nearestObserverDistance",_observerDistance],["reservationDistance",_reservedDistance]
                            ];
                        };
                    };
                };
            };
        };
    };
} forEach DRO2026_strategicCandidateSites;

_best
