params [
    ["_object",objNull,[objNull]],
    ["_profile","CRUISE",[""]],
    ["_launchSide",enemySide,[east]],
    ["_target",createHashMap,[createHashMap]],
    ["_warheadYield",1,[0]],
    ["_radarCrossSection",0.65,[0]],
    ["_nominalSpeed",120,[0]]
];
if (!isServer || {isNull _object}) exitWith {createHashMap};
private _registry = missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]];
private _id = format ["MUN_%1_%2",floor (diag_tickTime * 1000),floor random 1000000];
private _record = createHashMapFromArray [
    ["schema",1],["id",_id],["object",_object],["profile",toUpperANSI _profile],
    ["launchSide",_launchSide],["targetSide",_target getOrDefault ["side",sideUnknown]],
    ["targetNodeId",_target getOrDefault ["nodeId",""]],
    ["targetPositionASL",+(_target getOrDefault ["positionASL",[]])],
    ["targetObject",_target getOrDefault ["object",objNull]],
    ["warheadYield",_warheadYield max 0.1],["radarCrossSection",(_radarCrossSection max 0.05) min 2],
    ["nominalSpeed",_nominalSpeed max 20],["state","INBOUND"],["detected",false],
    ["detectedBy",[]],["engagements",0],["intercepted",false],["interceptedBy",""],
    ["createdAt",time],["lastUpdatedAt",time],["impactAt",-1]
];
_object setVariable ["DRO2026_strategicMunitionId",_id,true];
_object setVariable ["DRO2026_launchSide",_launchSide,true];
_object setVariable ["DRO2026_strategicProfile",toUpperANSI _profile,true];
_registry pushBack _record;
missionNamespace setVariable ["DRO2026_activeStrategicMunitions",_registry];
["STRATEGIC_MUNITION_LAUNCHED",createHashMapFromArray [
    ["munitionId",_id],["profile",toUpperANSI _profile],["side",str _launchSide],
    ["targetNodeId",_target getOrDefault ["nodeId",""]],["targetPositionASL",+(_target getOrDefault ["positionASL",[]])]
],_id] call DRO2026_fnc_emitEvent;
_record