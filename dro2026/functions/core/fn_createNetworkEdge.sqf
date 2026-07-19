params [
    "_id",
    "_from",
    "_to",
    ["_cargoTypes", []],
    ["_capacity", 1],
    ["_travelTime", 600],
    ["_route", []]
];

if (!isServer) exitWith {createHashMap};
if !(_id isEqualType "" && {_from isEqualType ""} && {_to isEqualType ""}) exitWith {createHashMap};
if (_id == "" || {_from == ""} || {_to == ""}) exitWith {createHashMap};
if (isNil {DRO2026_networkNodes get _from} || {isNil {DRO2026_networkNodes get _to}}) exitWith {createHashMap};
if !(_cargoTypes isEqualType []) then {_cargoTypes = []};
if !(_route isEqualType []) then {_route = []};

private _existing = DRO2026_networkEdges getOrDefault [_id, createHashMap];
private _record = createHashMapFromArray [
    ["schema", 1],
    ["id", _id],
    ["from", _from],
    ["to", _to],
    ["cargoTypes", +_cargoTypes],
    ["capacity", (_capacity max 1)],
    ["travelTime", (_travelTime max 30)],
    ["route", +_route],
    ["risk", _existing getOrDefault ["risk", 0.12]],
    ["status", _existing getOrDefault ["status", "OPEN"]],
    ["interdictionPressure", _existing getOrDefault ["interdictionPressure", 0]],
    ["lastDeliveryAt", _existing getOrDefault ["lastDeliveryAt", -1]],
    ["nextDeliveryAt", _existing getOrDefault ["nextDeliveryAt", time + _travelTime]],
    ["createdAt", _existing getOrDefault ["createdAt", time]],
    ["lastUpdatedAt", time]
];
DRO2026_networkEdges set [_id, _record];
_record