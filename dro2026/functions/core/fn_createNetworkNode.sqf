params [
    "_id",
    "_type",
    "_side",
    "_position",
    ["_components", createHashMap],
    ["_stocks", createHashMap],
    ["_capabilities", []],
    ["_status", "ACTIVE"],
    ["_physicalState", "VIRTUAL"]
];

if (!isServer) exitWith {createHashMap};
if !(_id isEqualType "" && {_type isEqualType ""} && {_position isEqualType []}) exitWith {createHashMap};
if (_id == "" || {_type == ""} || {count _position < 2}) exitWith {createHashMap};

private _emptyMap = createHashMap;
if !(_components isEqualType _emptyMap) then {_components = createHashMap};
if !(_stocks isEqualType _emptyMap) then {_stocks = createHashMap};
if !(_capabilities isEqualType []) then {_capabilities = []};

private _existing = DRO2026_networkNodes getOrDefault [_id, createHashMap];
private _createdAt = _existing getOrDefault ["createdAt", time];
private _record = createHashMapFromArray [
    ["schema", 1],
    ["id", _id],
    ["type", _type],
    ["side", _side],
    ["position", +_position],
    ["status", _status],
    ["physicalState", _physicalState],
    ["physicalRefs", _existing getOrDefault ["physicalRefs", []]],
    ["components", _components],
    ["stocks", _stocks],
    ["capabilities", +_capabilities],
    ["emissionState", _existing getOrDefault ["emissionState", "PASSIVE"]],
    ["knownByPlayer", _existing getOrDefault ["knownByPlayer", "UNKNOWN"]],
    ["knownByEnemy", _existing getOrDefault ["knownByEnemy", "CONFIRMED"]],
    ["createdAt", _createdAt],
    ["lastUpdatedAt", time],
    ["destroyedAt", _existing getOrDefault ["destroyedAt", -1]]
];

DRO2026_networkNodes set [_id, _record];
_record