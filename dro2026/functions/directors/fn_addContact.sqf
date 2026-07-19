params [
    "_owner",
    ["_target", objNull],
    ["_position", []],
    ["_confidence", 0.5],
    ["_classification", "UNKNOWN"],
    ["_source", "AI_KNOWLEDGE"],
    ["_uncertaintyRadius", -1],
    ["_subjectId", ""],
    ["_falseContactProbability", 0]
];
if (count _position < 2 && {!isNull _target}) then {_position = getPosATL _target};
if (count _position < 2) exitWith {createHashMap};

if (_subjectId == "") then {
    if (!isNull _target) then {_subjectId = _target getVariable ["DRO2026_networkNodeId", ""]};
    if (_subjectId == "" && {missionNamespace getVariable ["DRO2026_networkBuilt", false]}) then {
        private _near = (keys DRO2026_networkNodes) select {
            private _node = DRO2026_networkNodes get _x;
            (_node getOrDefault ["position", [0,0,0]]) distance2D _position < 900
        };
        if (count _near > 0) then {
            _near = [_near, [], {
                private _node = DRO2026_networkNodes get _x;
                (_node getOrDefault ["position", [0,0,0]]) distance2D _position
            }, "ASCEND"] call BIS_fnc_sortBy;
            _subjectId = _near select 0;
        };
    };
};

private _prototype = [_owner, _target, _position, _confidence, _classification, "", _source, _uncertaintyRadius, _subjectId, _falseContactProbability] call DRO2026_fnc_createContactRecord;
if (count _prototype == 0) exitWith {createHashMap};
private _id = _prototype getOrDefault ["id", ""];
private _index = DRO2026_contacts findIf {
    (_x getOrDefault ["id", ""]) == _id && {(_x getOrDefault ["owner", ""]) == _owner}
};
private _contact = createHashMap;
private _isNew = _index < 0;
private _oldBda = "";
private _oldConfidence = 0;

if (_index >= 0) then {
    _contact = DRO2026_contacts select _index;
    _oldConfidence = _contact getOrDefault ["confidence", 0];
    _oldBda = _contact getOrDefault ["bdaState", "DETECTED"];
    private _oldPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", +_position]];
    private _oldSeen = _contact getOrDefault ["lastSeen", time];
    private _dt = (time - _oldSeen) max 0.1;
    private _sourceQuality = _prototype getOrDefault ["sourceQuality", 0.7];
    private _oldWeight = (_oldConfidence max 0.15);
    private _newWeight = ((_confidence max 0.05) * _sourceQuality) max 0.05;
    private _totalWeight = _oldWeight + _newWeight;
    private _fusedPos = ((_oldPos vectorMultiply _oldWeight) vectorAdd (_position vectorMultiply _newWeight)) vectorMultiply (1 / _totalWeight);
    private _velocity = (_position vectorDiff _oldPos) vectorMultiply (1 / _dt);
    private _newConfidence = (1 - ((1 - _oldConfidence) * (1 - ((_confidence * _sourceQuality) min 0.98)))) min 0.99;
    private _oldUncertainty = _contact getOrDefault ["uncertaintyRadius", 120];
    private _newUncertainty = _prototype getOrDefault ["uncertaintyRadius", 120];
    private _fusedUncertainty = (((_oldUncertainty * _oldWeight) + (_newUncertainty * _newWeight)) / _totalWeight) max 5;

    _contact set ["position", +_fusedPos];
    _contact set ["positionMean", +_fusedPos];
    _contact set ["velocityEstimate", _velocity];
    _contact set ["uncertaintyRadius", _fusedUncertainty];
    _contact set ["confidence", _newConfidence];
    _contact set ["lastSeen", time];
    _contact set ["lastFusionAt", time];
    _contact set ["target", _target];
    if (_subjectId != "") then {_contact set ["subjectId", _subjectId]};
    if ((_confidence * _sourceQuality) >= (_oldConfidence * 0.72)) then {
        _contact set ["classification", _classification];
        _contact set ["kind", _classification];
    };
    private _sources = _contact getOrDefault ["sources", []];
    _sources pushBackUnique (toUpperANSI _source);
    _contact set ["sources", _sources];
    _contact set ["sourceQuality", (_contact getOrDefault ["sourceQuality", 0]) max _sourceQuality];
    _contact set ["decayRate", (_contact getOrDefault ["decayRate", 0.006]) min (_prototype getOrDefault ["decayRate", 0.006])];
    _contact set ["uncertaintyGrowth", ((_contact getOrDefault ["uncertaintyGrowth", 15]) + (_prototype getOrDefault ["uncertaintyGrowth", 15])) / 2];
    _contact set ["falseContactProbability", ((_contact getOrDefault ["falseContactProbability", 0]) min (_prototype getOrDefault ["falseContactProbability", 0]))];
} else {
    _contact = _prototype;
    DRO2026_contacts pushBack _contact;
};

private _bda = _contact getOrDefault ["bdaState", "DETECTED"];
if (!isNull _target && {!alive _target}) then {
    private _strongSource = (toUpperANSI _source) in ["VISUAL", "MICRO_UAV", "TACTICAL_UAV"];
    _bda = if (_strongSource && {_confidence >= 0.72}) then {"CONFIRMED_DESTROYED"} else {"PROBABLY_DESTROYED"};
} else {
    if (_bda in ["PROBABLY_DISABLED", "PROBABLY_DESTROYED"] && {!isNull _target} && {alive _target}) then {_bda = "CONFIRMED"};
    if ((_contact getOrDefault ["confidence", 0]) >= 0.78 && {_bda == "DETECTED"}) then {_bda = "CONFIRMED"};
};
_contact set ["bdaState", _bda];

private _nodeId = _contact getOrDefault ["subjectId", ""];
if (_owner == "PLAYER" && {_nodeId != ""} && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
    private _node = DRO2026_networkNodes get _nodeId;
    private _known = if ((_contact getOrDefault ["confidence", 0]) >= 0.78) then {"CONFIRMED"} else {"DETECTED"};
    _node set ["knownByPlayer", _known];
    _node set ["lastUpdatedAt", time];
    DRO2026_networkNodes set [_nodeId, _node];
};

if (_owner == "PLAYER") then {
    private _arguments = [
        _id,
        _contact getOrDefault ["positionMean", _position],
        _contact getOrDefault ["confidence", 0.5],
        _contact getOrDefault ["classification", _classification],
        false,
        _contact getOrDefault ["uncertaintyRadius", 80],
        _bda
    ];
    if (hasInterface) then {_arguments call DRO2026_fnc_syncContactMarker};
    if (isServer) then {_arguments remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false]};
};

private _crossedThreshold = _oldConfidence < 0.62 && {(_contact getOrDefault ["confidence", 0]) >= 0.62};
if (_isNew || {_crossedThreshold} || {_oldBda != _bda}) then {
    ["CONTACT_UPDATED", createHashMapFromArray [
        ["contactId", _id], ["owner", _owner], ["subjectId", _nodeId],
        ["confidence", _contact getOrDefault ["confidence", 0]], ["uncertainty", _contact getOrDefault ["uncertaintyRadius", 0]],
        ["classification", _contact getOrDefault ["classification", "UNKNOWN"]], ["bdaState", _bda], ["isNew", _isNew]
    ], _id] call DRO2026_fnc_emitEvent;
};
_contact