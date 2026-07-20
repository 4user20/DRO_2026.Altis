params [
    ["_attackerSide",enemySide,[east]],
    ["_profile","CRUISE",[""]],
    ["_minimumKnowledge","TRACKED",[""]]
];
if !(missionNamespace getVariable ["DRO2026_networkBuilt",false]) exitWith {createHashMap};
private _targetSide = if (_attackerSide == enemySide) then {playersSide} else {enemySide};
private _knowledgeKey = if (_attackerSide == enemySide) then {"knownByEnemy"} else {"knownByPlayer"};
private _knowledgeRank = createHashMapFromArray [["UNKNOWN",0],["SUSPECTED",1],["DETECTED",2],["TRACKED",3],["CONFIRMED",4]];
private _required = _knowledgeRank getOrDefault [toUpperANSI _minimumKnowledge,3];
private _profileUpper = toUpperANSI _profile;
private _seriousTypes = ["HQ","LOGISTICS_HUB","AA_LONG","STRATEGIC_DRONE_SITE","ARTILLERY_SITE","FARP","BALLISTIC_MISSILE_SITE"];
private _civilians = allUnits select {alive _x && {side _x == civilian}};
private _candidates = [];
{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes get _nodeId;
    private _status = toUpperANSI (_node getOrDefault ["status","ACTIVE"]);
    private _type = toUpperANSI (_node getOrDefault ["type","UNKNOWN"]);
    private _side = _node getOrDefault ["side",sideUnknown];
    private _knowledge = toUpperANSI (_node getOrDefault [_knowledgeKey,"UNKNOWN"]);
    private _rank = _knowledgeRank getOrDefault [_knowledge,0];
    private _positionATL = _node getOrDefault ["position",[]];
    if (_side == _targetSide && {!(_status in ["DESTROYED","DISABLED","CANCELLED"])} && {_rank >= _required} && {count _positionATL >= 2}) then {
        private _serious = _type in _seriousTypes;
        if (!(_profileUpper in ["ISKANDER","BALLISTIC"]) || {_serious}) then {
            private _positionASL = [_positionATL,"ATL",objNull] call DRO2026_fnc_normalizePositionASL;
            private _nearestCivilian = if (count _civilians == 0) then {1e9} else {selectMin (_civilians apply {_positionATL distance2D _x})};
            private _civilianSafe = _nearestCivilian >= (if (_profileUpper in ["ISKANDER","BALLISTIC"]) then {450} else {220});
            if (_civilianSafe) then {
                private _base = switch _type do {
                    case "HQ": {11.0};
                    case "AA_LONG": {10.0};
                    case "LOGISTICS_HUB": {9.6};
                    case "BALLISTIC_MISSILE_SITE": {9.2};
                    case "STRATEGIC_DRONE_SITE": {8.8};
                    case "ARTILLERY_SITE": {8.2};
                    case "FARP": {7.8};
                    case "FPV_TEAM": {6.2};
                    case "AA_SHORAD": {6.0};
                    default {4.0};
                };
                private _statusFactor = if (_status == "DEGRADED") then {0.65} else {1};
                private _stockValue = 0;
                private _stocks = _node getOrDefault ["stocks",createHashMap];
                { _stockValue = _stockValue + ((_stocks getOrDefault [_x,0]) min 20) * 0.025 } forEach keys _stocks;
                private _jitter = [0.7,format ["TARGET_%1_%2",_profileUpper,_nodeId],-0.35] call DRO2026_fnc_seededRandom;
                private _score = (_base + _stockValue + ((_rank - _required) * 0.35) + _jitter) * _statusFactor;
                private _refs = (_node getOrDefault ["physicalRefs",[]]) select {!isNull _x && {alive _x}};
                private _object = if (count _refs > 0) then {_refs select 0} else {objNull};
                _candidates pushBack createHashMapFromArray [
                    ["ok",true],["nodeId",_nodeId],["nodeType",_type],["side",_targetSide],
                    ["positionATL",+_positionATL],["positionASL",+_positionASL],["object",_object],
                    ["knowledge",_knowledge],["score",_score],["serious",_serious],
                    ["nearestCivilianDistance",_nearestCivilian]
                ];
            };
        };
    };
} forEach keys DRO2026_networkNodes;
if (count _candidates == 0) exitWith {createHashMapFromArray [["ok",false],["code","NO_CONFIRMED_STRATEGIC_TARGET"]]};
_candidates = [_candidates,[],{-(_x getOrDefault ["score",0])},"ASCEND"] call BIS_fnc_sortBy;
_candidates select 0