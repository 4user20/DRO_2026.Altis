params [
    "_type",
    "_position",
    ["_object", objNull],
    ["_objects", []],
    ["_extra", createHashMap]
];

if !(_type isEqualType "") exitWith {createHashMap};
if (_type == "" || {!(_position isEqualType [])} || {count _position < 2}) exitWith {createHashMap};
if !(_objects isEqualType []) then {_objects = []};
if (!isNull _object) then {_objects pushBackUnique _object};
_objects = _objects select {!isNull _x};

private _networkNodeId = switch _type do {
    case "ENEMY_HQ": {"NODE_ENEMY_HQ"};
    case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
    case "LOGISTICS_RUN": {"NODE_LOGISTICS_01"};
    case "CONVOY": {"NODE_LOGISTICS_01"};
    case "ARTILLERY_SITE": {"NODE_ARTILLERY_01"};
    case "FPV_TEAM": {"NODE_FPV_FORWARD_01"};
    case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
    case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
    case "STRATEGIC_DRONE_SITE": {"NODE_DRONE_REAR_01"};
    case "EW_SITE": {"NODE_EW_01"};
    case "AIR_DEFENCE_SITE": {"NODE_AA_LONG_01"};
    case "ENEMY_LAYERED_AA": {"NODE_AA_LONG_01"};
    default {""};
};

private _record = createHashMapFromArray [
    ["schema", 2],
    ["id", format ["SITE_%1_%2_%3", _type, floor diag_tickTime, floor random 1000000]],
    ["type", _type],
    ["networkNodeId", _networkNodeId],
    ["position", +_position],
    ["object", _object],
    ["objects", _objects],
    ["status", "ACTIVE"],
    ["physicalState", if (count _objects > 0) then {"ACTIVE"} else {"VIRTUAL"}],
    ["createdAt", time],
    ["lastUpdatedAt", time],
    ["destroyedAt", -1],
    ["background", false]
];

private _emptyMap = createHashMap;
if (_extra isEqualType _emptyMap) then {
    {_record set [_x, _extra get _x]} forEach keys _extra;
};
_networkNodeId = _record getOrDefault ["networkNodeId", _networkNodeId];
if (_networkNodeId != "") then {
    {_x setVariable ["DRO2026_networkNodeId", _networkNodeId, true]} forEach _objects;
    if (!isNull _object) then {_object setVariable ["DRO2026_networkNodeId", _networkNodeId, true]};
};
_record