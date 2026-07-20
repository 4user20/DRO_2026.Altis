params [
    ["_owner", "", [""]],
    ["_target", objNull, [objNull]],
    ["_position", [], [[]]],
    ["_confidence", 0.5, [0]],
    ["_classification", "UNKNOWN", [""]],
    ["_id", "", [""]],
    ["_source", "AI_KNOWLEDGE", [""]],
    ["_uncertaintyRadius", -1, [0]],
    ["_subjectNetId", "", [""]],
    ["_falseContactProbability", 0, [0]],
    ["_uncertaintyGrowth", -1, [0]]
];
if (_owner == "") exitWith {createHashMap};
if (count _position < 2 && {!isNull _target}) then {_position = getPosASL _target};
if !(_position isEqualType [] && {count _position in [2,3]} && {(_position findIf {!(_x isEqualType 0)}) < 0}) exitWith {createHashMap};
if (count _position == 2) then {_position pushBack (getTerrainHeightASL _position)};
if (_confidence < 0 || {_confidence > 1}) exitWith {createHashMap};
if (_uncertaintyRadius < -1 || {_uncertaintyGrowth < -1}) exitWith {createHashMap};
if (_id == "") then {
    if (!isNull _target) then {
        _id = _target getVariable ["DRO2026_contactId", ""];
        if (_id == "") then {_id = format ["C_%1_%2", floor (diag_tickTime * 1000), floor random 1000000]; _target setVariable ["DRO2026_contactId", _id, true]};
    } else {_id = format ["P_%1_%2_%3", round (_position select 0), round (_position select 1), _owner]};
};
if (_id == "") exitWith {createHashMap};
if (_subjectNetId == "" && {!isNull _target}) then {
    _subjectNetId = netId _target;
    private _nodeId = _target getVariable ["DRO2026_networkNodeId", ""];
    if (_nodeId != "") then {_subjectNetId = _nodeId};
};
private _profile = switch (toUpperANSI _source) do {
    case "VISUAL": {[1.00,24,0.0025,5]}; case "MICRO_UAV": {[0.92,45,0.0045,10]};
    case "TACTICAL_UAV": {[0.88,85,0.0040,14]}; case "HALE": {[0.82,180,0.0028,16]};
    case "ELINT": {[0.74,350,0.0025,9]}; case "CIVILIAN": {[0.55,280,0.0100,34]};
    case "COUNTERBATTERY": {[0.72,420,0.0120,48]}; case "UAV_RECON": {[0.90,70,0.0042,12]};
    case "UAV_FPV": {[0.84,95,0.0060,16]}; case "UAV_BOMBER": {[0.86,85,0.0055,15]};
    case "UAV_FIBEROPTIC_AP": {[0.88,60,0.0045,11]}; case "UAV_FIBEROPTIC_AT": {[0.90,55,0.0042,10]};
    case "UAV_FIBEROPTIC_TI": {[0.94,42,0.0038,8]}; case "INFOSHARE": {[0.66,180,0.0090,26]};
    case "GROUND_AI": {[0.72,130,0.0075,20]}; default {[0.76,95,0.0060,15]};
};
_profile params ["_sourceQuality", "_defaultUncertainty", "_decayRate", "_defaultGrowth"];
if (_uncertaintyRadius < 0) then {_uncertaintyRadius = _defaultUncertainty};
if (_uncertaintyGrowth < 0) then {_uncertaintyGrowth = _defaultGrowth};
if (_uncertaintyRadius < 0 || {_uncertaintyGrowth < 0}) exitWith {createHashMap};
createHashMapFromArray [
    ["schema",3], ["id",_id], ["owner",_owner], ["subjectNetId",_subjectNetId], ["subjectObject",_target],
    ["subjectType",_classification], ["side",if (!isNull _target) then {side _target} else {sideUnknown}],
    ["state","DETECTED"], ["positionASL",+_position], ["uncertaintyRadius",_uncertaintyRadius],
    ["uncertaintyGrowthPerMinute",_uncertaintyGrowth], ["confidence",_confidence], ["lastSeenAt",time], ["lastUpdatedAt",time],
    ["sourceNodeId",if ((_subjectNetId find "NODE_") == 0) then {_subjectNetId} else {""}], ["sourceSensorId",toUpperANSI _source],
    ["classification",_classification], ["kind",_classification], ["sources",[toUpperANSI _source]],
    ["sourceQuality",_sourceQuality], ["decayRate",_decayRate], ["velocityEstimate",[0,0,0]], ["createdAt",time],
    ["falseContactProbability",(_falseContactProbability max 0) min 0.8], ["marker",""],
    ["subjectId",_subjectNetId], ["target",_target], ["position",+_position], ["positionMean",+_position],
    ["uncertaintyGrowth",_uncertaintyGrowth], ["lastSeen",time], ["lastFusionAt",time], ["bdaState","DETECTED"], ["engagedAt",-1]
]
