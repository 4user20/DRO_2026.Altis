params ["_jobType", "_sequence", "_candidates"];
if (!isServer) exitWith {[]};
private _pairs = {params ["_map",["_limit",32]]; private _out=[]; private _keys=keys _map; {_out pushBack [_x,_map get _x]; if (count _out >= _limit) exitWith {}} forEach _keys; _out};
private _operation = [
    ["phase",DRO2026_operationState getOrDefault ["phase","RECON"]],
    ["doctrine",DRO2026_operationState getOrDefault ["doctrine","DRONE_HEAVY"]],
    ["alert",DRO2026_alertLevel], ["networkHealth",DRO2026_operationState getOrDefault ["networkHealth",1]],
    ["intelQuality",DRO2026_intelQuality], ["civilianTrust",DRO2026_operationState getOrDefault ["civilianTrust",55]],
    ["operationScore",DRO2026_operationState getOrDefault ["operationScore",0]], ["playerNoise",DRO2026_operationState getOrDefault ["playerNoise",0]]
];
private _activeEnemyAI = 0; {if (!isNull _x && {side _x == enemySide}) then {_activeEnemyAI = _activeEnemyAI + ({alive _x} count units _x)}} forEach DRO2026_managedGroups;
private _performance = [["fpsAverage",DRO2026_fpsAverage],["activeEnemyAI",_activeEnemyAI],["activeDrones",count DRO2026_activeDrones],["activeConvoys",count DRO2026_activeConvoys],["managedGroups",count DRO2026_managedGroups]];
private _nodes=[];
{
    private _node=DRO2026_networkNodes get _x; private _stocks=_node getOrDefault ["stocks",createHashMap];
    _nodes pushBack [_x,_node getOrDefault ["type","UNKNOWN"],_node getOrDefault ["status","ACTIVE"],_node getOrDefault ["knownByPlayer","UNKNOWN"],_node getOrDefault ["health",1],[_stocks,24] call _pairs,_node getOrDefault ["capabilities",[]]];
    if (count _nodes >= 20) exitWith {};
} forEach (keys DRO2026_networkNodes);
private _edges=[];
{
    private _edge=DRO2026_networkEdges get _x;
    _edges pushBack [_x,_edge getOrDefault ["from",""],_edge getOrDefault ["to",""],_edge getOrDefault ["status","OPEN"],_edge getOrDefault ["risk",0],_edge getOrDefault ["interdictionPressure",0],_edge getOrDefault ["escortLevel",0],((_edge getOrDefault ["nextDeliveryAt",time])-time) max 0,_edge getOrDefault ["cargoTypes",[]]];
    if (count _edges >= 20) exitWith {};
} forEach (keys DRO2026_networkEdges);
private _contacts = DRO2026_contacts select {(_x getOrDefault ["owner",""]) == "ENEMY" && {(time - (_x getOrDefault ["lastSeen",0])) < 600}};
_contacts = [_contacts,[],{-((_x getOrDefault ["confidence",0]) - ((_x getOrDefault ["uncertaintyRadius",0])/3000))},"ASCEND"] call BIS_fnc_sortBy;
private _contactRows=[];
{
    _contactRows pushBack [_x getOrDefault ["id",""],_x getOrDefault ["classification","UNKNOWN"],_x getOrDefault ["confidence",0],_x getOrDefault ["uncertaintyRadius",0],time-(_x getOrDefault ["lastSeen",time]),_x getOrDefault ["bdaState","DETECTED"],_x getOrDefault ["subjectId",""],_x getOrDefault ["velocityEstimate",[0,0,0]],_x getOrDefault ["value",0.5]];
    if (count _contactRows >= 12) exitWith {};
} forEach _contacts;
private _events=[]; private _start=(count DRO2026_eventLog - 30) max 0;
{
    private _payload=_x getOrDefault ["payload",createHashMap];
    _events pushBack [_x getOrDefault ["id",""],_x getOrDefault ["type",""],time-(_x getOrDefault ["createdAt",time]),_x getOrDefault ["sourceId","SYSTEM"],[_payload,16] call _pairs];
} forEach (DRO2026_eventLog select [_start,(count DRO2026_eventLog)-_start]);
private _candidateRows=[];
{
    private _constraints=_x getOrDefault ["constraints",createHashMap];
    _candidateRows pushBack [_x getOrDefault ["id",""],_x getOrDefault ["action",""],_x getOrDefault ["actor",""],_x getOrDefault ["contactId",""],_x getOrDefault ["utility",0],_x getOrDefault ["resourceCost",0],[_constraints,12] call _pairs];
} forEach _candidates;
private _policy=missionNamespace getVariable ["DRO2026_aiPolicy",createHashMap];
[
    "0.1",_jobType,missionNamespace getVariable ["DRO2026_aiMissionId","UNKNOWN"],_sequence,time,
    _operation,_performance,_nodes,_edges,_contactRows,_events,_candidateRows,[_policy,16] call _pairs
]
