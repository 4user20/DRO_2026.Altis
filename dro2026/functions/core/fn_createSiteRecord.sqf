params [
    ["_type", "", [""]],
    ["_position", [], [[]]],
    ["_object", objNull, [objNull]],
    ["_objects", [], [[]]],
    ["_extra", createHashMap, [createHashMap]]
];
if (_type == "" || {count _position < 2} || {!({_x isEqualType 0} count (_position select [0,2]) == 2)}) exitWith {createHashMap};
_objects = _objects select {!isNull _x};
if (!isNull _object) then {_objects pushBackUnique _object};
private _friendly = (_type find "FRIENDLY") >= 0;
private _networkNodeId = switch true do {
    case (_type == "ENEMY_HQ"): {"NODE_ENEMY_HQ"};
    case (_type == "FRIENDLY_HQ"): {"NODE_FRIENDLY_HQ"};
    case (_type in ["LOGISTICS_HUB","LOGISTICS_RUN","CONVOY","SUPPLY_CONVOY"]): {if (_friendly) then {"NODE_FRIENDLY_LOGISTICS"} else {"NODE_LOGISTICS_01"}};
    case ((_type find "ARTILLERY") >= 0): {"NODE_ARTILLERY_01"};
    case ((_type find "FPV") >= 0): {if (_friendly) then {"NODE_FRIENDLY_FPV"} else {"NODE_FPV_FORWARD_01"}};
    case ((_type find "DRONE") >= 0 || {(_type find "UAV") >= 0}): {if (_friendly) then {"NODE_FRIENDLY_DRONES"} else {"NODE_DRONE_REAR_01"}};
    case ((_type find "EW") >= 0): {"NODE_EW_01"};
    case ((_type find "AA") >= 0 || {(_type find "AIR_DEFENCE") >= 0}): {if (_friendly) then {"NODE_FRIENDLY_AA_LONG"} else {"NODE_AA_LONG_01"}};
    default {""};
};
private _components = _extra getOrDefault ["components", createHashMapFromArray [["crew",[]],["guards",[]],["launchers",[]],["antennas",[]],["terminals",[]],["generators",[]],["stocks",[]],["transports",[]],["camouflage",[]],["staticProps",[]]]];
private _record = createHashMapFromArray [
    ["schema",3],["id",format ["SITE_%1_%2_%3",_type,floor diag_tickTime,floor random 1000000]],
    ["side",_extra getOrDefault ["side",if (_friendly) then {playersSide} else {enemySide}]],
    ["type",_type],["state","ACTIVE"],["status","ACTIVE"],["position",+_position],["positionASL",AGLToASL _position],
    ["locationId",_extra getOrDefault ["locationId",""]],["roadAnchorNetId",_extra getOrDefault ["roadAnchorNetId",""]],
    ["networkNodeId",_extra getOrDefault ["networkNodeId",_networkNodeId]],["object",_object],["objects",_objects],
    ["components",_components],["componentManaged",!(isNil {_extra get "components"})],["stocks",_extra getOrDefault ["stocks",createHashMap]],["capabilities",createHashMap],
    ["physicalState",if (count _objects > 0) then {"ACTIVE"} else {"VIRTUAL"}],
    ["createdAt",time],["lastUpdatedAt",time],["destroyedAt",-1],["background",false]
];
{_record set [_x,_extra get _x]} forEach keys _extra;
_networkNodeId = _record getOrDefault ["networkNodeId",""];
if (_networkNodeId != "") then {{_x setVariable ["DRO2026_networkNodeId",_networkNodeId,true]} forEach _objects};
_record