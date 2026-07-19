params ["_sequence"];
if (!isServer) exitWith {[]};
private _phase = [] call DRO2026_fnc_evaluateOperationPhase;
private _doctrine = DRO2026_operationState getOrDefault ["doctrine", "DRONE_HEAVY"];
private _weights = switch _doctrine do {
    case "ARTILLERY_HEAVY": {createHashMapFromArray [["ARTILLERY_FIRE",1.55],["FPV_ATTACK",0.85],["LONG_RANGE_ATTACK",0.9],["REINFORCE",0.8],["ROUTE_ADAPT",1.0]]};
    case "DEFENSIVE_NETWORK": {createHashMapFromArray [["ARTILLERY_FIRE",1.0],["FPV_ATTACK",0.9],["LONG_RANGE_ATTACK",0.7],["REINFORCE",1.25],["ROUTE_ADAPT",1.35]]};
    case "MOBILE_RESERVES": {createHashMapFromArray [["ARTILLERY_FIRE",0.8],["FPV_ATTACK",0.9],["LONG_RANGE_ATTACK",0.7],["REINFORCE",1.5],["ROUTE_ADAPT",1.25]]};
    default {createHashMapFromArray [["ARTILLERY_FIRE",0.9],["FPV_ATTACK",1.5],["LONG_RANGE_ATTACK",1.25],["REINFORCE",0.75],["ROUTE_ADAPT",0.9]]};
};
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner",""]) == "ENEMY" &&
    {(_x getOrDefault ["bdaState","DETECTED"]) != "CONFIRMED_DESTROYED"} &&
    {(time - (_x getOrDefault ["lastSeen",0])) < 320}
};
if (count _contacts > 0) then {_contacts = [_contacts,[],{-((_x getOrDefault ["confidence",0]) - ((_x getOrDefault ["uncertaintyRadius",0])/3000))},"ASCEND"] call BIS_fnc_sortBy};
private _best = if (count _contacts > 0) then {_contacts select 0} else {createHashMap};
private _confidence = _best getOrDefault ["confidence",0];
private _contactId = _best getOrDefault ["id",""];
private _candidates = [];
private _policy=missionNamespace getVariable ["DRO2026_aiPolicy",createHashMap];
private _policyActive=(_policy getOrDefault ["expiresAt",-1]) > time;
private _policyFactor={
    params ["_action"];
    if (!_policyActive) exitWith {1};
    switch (_action) do {
        case "FPV_ATTACK";
        case "ARTILLERY_FIRE";
        case "LONG_RANGE_ATTACK": {0.75 + 0.5 * (_policy getOrDefault ["strikePressure",0.5])};
        case "REINFORCE": {0.75 + 0.5 * (_policy getOrDefault ["reserveCommitment",0.45])};
        case "ROUTE_ADAPT": {0.75 + 0.5 * (_policy getOrDefault ["logisticsPriority",0.5])};
        default {1};
    }
};
private _add = {
    params ["_action","_nodeId","_base","_cost","_minConfidence",["_constraints",createHashMap]];
    private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
    if (count _node == 0 || {(_node getOrDefault ["status","ACTIVE"]) in ["DESTROYED","DISABLED"]}) exitWith {};
    if (_minConfidence > 0 && {_confidence < _minConfidence}) exitWith {};
    private _exposure = if ((_node getOrDefault ["knownByPlayer","UNKNOWN"]) in ["CONFIRMED","TRACKED"]) then {0.22} else {0.05};
    private _phaseWeight = switch _phase do {case "RECON": {if (_action in ["FPV_ATTACK","ARTILLERY_FIRE"]) then {0.65} else {0.85}}; case "COUNTERATTACK": {if (_action in ["REINFORCE","FPV_ATTACK"]) then {1.25} else {1}}; default {1}};
    private _utility = (_base * (_weights getOrDefault [_action,1]) * (_confidence max 0.45) * _phaseWeight * ([_action] call _policyFactor)) - _cost - _exposure;
    private _index = count _candidates;
    _candidates pushBack createHashMapFromArray [
        ["id",format ["CAND_%1_%2",_sequence,_index]],["action",_action],["actor",_nodeId],["contactId",_contactId],
        ["utility",_utility],["resourceCost",_cost],["createdAt",time],["constraints",_constraints]
    ];
};
["FPV_ATTACK","NODE_FPV_FORWARD_01",0.78,0.10,DRO2026_CONTACT_REQUIRED_FOR_FPV,createHashMapFromArray [["maxSalvo",3]]] call _add;
["ARTILLERY_FIRE","NODE_ARTILLERY_01",0.72,0.12,0.58] call _add;
["LONG_RANGE_ATTACK","NODE_DRONE_REAR_01",0.82,0.22,DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE] call _add;
if (DRO2026_alertLevel > 0.48) then {["REINFORCE","NODE_ENEMY_HQ",0.62,0.16,0] call _add};
private _recentInterdiction = (DRO2026_eventLog findIf {(_x getOrDefault ["type",""]) == "DELIVERY_INTERDICTED" && {(time - (_x getOrDefault ["createdAt",0])) < 600}}) >= 0;
if (_recentInterdiction) then {["ROUTE_ADAPT","NODE_LOGISTICS_01",0.74,0.04,0] call _add};
_candidates
