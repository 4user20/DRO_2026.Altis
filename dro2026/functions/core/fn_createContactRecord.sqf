params [
    "_owner",
    ["_target", objNull],
    ["_position", []],
    ["_confidence", 0.5],
    ["_classification", "UNKNOWN"],
    ["_id", ""],
    ["_source", "AI_KNOWLEDGE"],
    ["_uncertaintyRadius", -1],
    ["_subjectId", ""],
    ["_falseContactProbability", 0]
];

if !(_owner isEqualType "") exitWith {createHashMap};
if !(_classification isEqualType "") then {_classification = "UNKNOWN"};
if !(_source isEqualType "") then {_source = "AI_KNOWLEDGE"};
if (count _position < 2 && {!isNull _target}) then {_position = getPosATL _target};
if (count _position < 2) exitWith {createHashMap};

if (_id == "") then {
    if (!isNull _target) then {
        _id = _target getVariable ["DRO2026_contactId", ""];
        if (_id == "") then {
            _id = format ["C_%1_%2", floor diag_tickTime, floor random 1000000];
            _target setVariable ["DRO2026_contactId", _id, true];
        };
    } else {
        _id = format ["P_%1_%2_%3", round (_position select 0), round (_position select 1), _owner];
    };
};
if (_subjectId == "" && {!isNull _target}) then {
    _subjectId = _target getVariable ["DRO2026_networkNodeId", ""];
};

private _profile = switch (toUpperANSI _source) do {
    case "VISUAL": {[1.00, 24, 0.0025, 5]};
    case "MICRO_UAV": {[0.92, 45, 0.0045, 10]};
    case "TACTICAL_UAV": {[0.88, 85, 0.0040, 14]};
    case "HALE": {[0.82, 180, 0.0028, 16]};
    case "ELINT": {[0.74, 350, 0.0025, 9]};
    case "CIVILIAN": {[0.55, 280, 0.0100, 34]};
    case "COUNTERBATTERY": {[0.72, 420, 0.0120, 48]};
    default {[0.76, 95, 0.0060, 15]};
};
_profile params ["_sourceQuality", "_defaultUncertainty", "_decayRate", "_uncertaintyGrowth"];
if (_uncertaintyRadius < 0) then {_uncertaintyRadius = _defaultUncertainty};

createHashMapFromArray [
    ["schema", 2],
    ["id", _id],
    ["owner", _owner],
    ["subjectId", _subjectId],
    ["target", _target],
    ["position", +_position],
    ["positionMean", +_position],
    ["uncertaintyRadius", _uncertaintyRadius max 5],
    ["confidence", (_confidence max 0) min 1],
    ["classification", _classification],
    ["kind", _classification],
    ["sources", [toUpperANSI _source]],
    ["sourceQuality", _sourceQuality],
    ["decayRate", _decayRate],
    ["uncertaintyGrowth", _uncertaintyGrowth],
    ["velocityEstimate", [0,0,0]],
    ["lastSeen", time],
    ["createdAt", time],
    ["lastFusionAt", time],
    ["bdaState", "DETECTED"],
    ["engagedAt", -1],
    ["falseContactProbability", (_falseContactProbability max 0) min 0.8],
    ["marker", ""]
]