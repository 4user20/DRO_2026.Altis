params [
    ["_ownerKey",""] ,
    ["_target",objNull,[objNull]],
    ["_position",[],[[]]],
    ["_confidence",0.5,[0]],
    ["_classification","UNKNOWN",[""]],
    ["_id","",[""]],
    ["_source","AI_KNOWLEDGE",[""]],
    ["_uncertaintyRadius",-1,[0]],
    ["_subjectNetId","",[""]],
    ["_falseContactProbability",0,[0]],
    ["_uncertaintyGrowth",-1,[0]],
    ["_metadata",createHashMap,[createHashMap]]
];
private _normalizedOwner = switch true do {
    case (_ownerKey isEqualType ""): {_ownerKey};
    case (_ownerKey isEqualType 0): {format ["NETWORK_OWNER_%1",_ownerKey]};
    case (_ownerKey isEqualType objNull): {
        if (isNull _ownerKey) then {""} else {
            private _ownerNetId = netId _ownerKey;
            if (_ownerNetId == "") then {format ["OBJECT_%1",hashValue _ownerKey]} else {_ownerNetId}
        }
    };
    case (_ownerKey isEqualType west): {format ["SIDE_%1",toUpperANSI str _ownerKey]};
    default {""};
};
if (_normalizedOwner == "") exitWith {createHashMap};

private _defaultSpace = if (!isNull _target && {toUpperANSI _source == "PLAYER_DESIGNATION"}) then {"ATL"} else {"ASL"};
private _positionSpace = toUpperANSI (_metadata getOrDefault ["positionSpace",_defaultSpace]);
_position = [_position,_positionSpace,_target] call DRO2026_fnc_normalizePositionASL;
if (count _position != 3) exitWith {createHashMap};
if (_confidence < 0 || {_confidence > 1}) exitWith {createHashMap};
if (_uncertaintyRadius < -1 || {_uncertaintyGrowth < -1}) exitWith {createHashMap};

if (_id == "") then {
    if (!isNull _target) then {
        _id = _target getVariable ["DRO2026_contactId",""];
        if (_id == "") then {
            _id = format ["C_%1_%2",floor (diag_tickTime * 1000),floor random 1000000];
            _target setVariable ["DRO2026_contactId",_id,true];
        };
    } else {
        _id = format ["P_%1_%2_%3",round (_position select 0),round (_position select 1),_normalizedOwner];
    };
};
if (_id == "") exitWith {createHashMap};

private _stableSubjectId = _metadata getOrDefault ["stableSubjectId",""];
if ((_subjectNetId find "NODE_") == 0) then {
    if (_stableSubjectId == "") then {_stableSubjectId = _subjectNetId};
    _subjectNetId = "";
};
if (_subjectNetId == "" && {!isNull _target}) then {_subjectNetId = netId _target};
if (_stableSubjectId == "" && {!isNull _target}) then {
    _stableSubjectId = _target getVariable ["DRO2026_networkNodeId",""];
    if (_stableSubjectId == "") then {
        _stableSubjectId = _target getVariable ["DRO2026_stableSubjectId",_id];
        _target setVariable ["DRO2026_stableSubjectId",_stableSubjectId,true];
    };
};
if (_stableSubjectId == "") then {_stableSubjectId = if (_subjectNetId != "") then {_subjectNetId} else {_id}};

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
_profile params ["_sourceQuality","_defaultUncertainty","_decayRate","_defaultGrowth"];
if (_uncertaintyRadius < 0) then {_uncertaintyRadius = _defaultUncertainty};
if (_uncertaintyGrowth < 0) then {_uncertaintyGrowth = _defaultGrowth};
if (_uncertaintyRadius < 0 || {_uncertaintyGrowth < 0}) exitWith {createHashMap};

private _networkOwner = _metadata getOrDefault ["networkOwner",if (!isNull _target) then {owner _target} else {-1}];
private _sourceObject = _metadata getOrDefault ["sourceObject",objNull];
private _sourceId = _metadata getOrDefault ["sourceId",toUpperANSI _source];
private _record = createHashMapFromArray [
    ["schema",4],["contactId",_id],["id",_id],["ownerKey",_normalizedOwner],["owner",_normalizedOwner],
    ["object",_target],["subjectObject",_target],["target",_target],
    ["netId",_subjectNetId],["subjectNetId",_subjectNetId],["targetNetId",_subjectNetId],
    ["stableSubjectId",_stableSubjectId],["subjectId",_stableSubjectId],
    ["sourceId",_sourceId],["sourceObject",_sourceObject],["networkOwner",_networkOwner],
    ["subjectType",_classification],["classification",_classification],["kind",_classification],
    ["side",if (!isNull _target) then {side _target} else {sideUnknown}],
    ["state","ACTIVE"],["terminalReason",""],["terminalAt",-1],
    ["positionSpace","ASL"],["positionASL",+_position],["position",+_position],["positionMean",+_position],["lastKnownPosition",+_position],
    ["uncertaintyRadius",_uncertaintyRadius],["uncertaintyGrowthPerMinute",_uncertaintyGrowth],
    ["uncertaintyGrowth",_uncertaintyGrowth],["confidence",_confidence],
    ["createdAt",time],["lastConfirmedAt",time],["lastSeenAt",time],["lastUpdatedAt",time],
    ["lastSeen",time],["lastFusionAt",time],
    ["sourceNodeId",if ((_stableSubjectId find "NODE_") == 0) then {_stableSubjectId} else {""}],
    ["sourceSensorId",toUpperANSI _source],["sources",[toUpperANSI _source]],
    ["sourceQuality",_sourceQuality],["decayRate",_decayRate],["velocityEstimate",[0,0,0]],
    ["falseContactProbability",(_falseContactProbability max 0) min 0.8],["marker",""],
    ["bdaState","DETECTED"],["engagedAt",-1],["reservationId",""]
];
private _protectedKeys = [
    "schema","contactId","id","ownerKey","owner","object","subjectObject","target",
    "netId","subjectNetId","targetNetId","stableSubjectId","subjectId","state",
    "terminalReason","terminalAt","positionSpace","positionASL","position","positionMean",
    "lastKnownPosition","createdAt","lastConfirmedAt","lastSeenAt","lastUpdatedAt"
];
{
    if !(_x in _protectedKeys) then {_record set [_x,_metadata get _x]};
} forEach keys _metadata;
_record
