if (!isServer) exitWith {};
if !(missionNamespace getVariable ["DRO2026_networkBuilt", false]) exitWith {};

private _siteNodeId = {
    params ["_type", "_position"];
    switch _type do {
        case "ENEMY_HQ": {"NODE_ENEMY_HQ"};
        case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
        case "ARTILLERY_SITE": {"NODE_ARTILLERY_01"};
        case "FPV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "STRATEGIC_DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "EW_SITE": {"NODE_EW_01"};
        case "AIR_DEFENCE_SITE": {
            private _long = DRO2026_networkNodes getOrDefault ["NODE_AA_LONG_01", createHashMap];
            private _short = DRO2026_networkNodes getOrDefault ["NODE_AA_SHORAD_01", createHashMap];
            if ((_position distance2D (_long getOrDefault ["position", _position])) <= (_position distance2D (_short getOrDefault ["position", _position]))) then {"NODE_AA_LONG_01"} else {"NODE_AA_SHORAD_01"}
        };
        case "ENEMY_LAYERED_AA": {"NODE_AA_LONG_01"};
        default {""};
    }
};

private _nodeRefs = createHashMap;
private _nodeHasLive = createHashMap;
private _nodeSeen = createHashMap;

{
    private _site = _x;
    private _type = _site getOrDefault ["type", "UNKNOWN"];
    private _position = _site getOrDefault ["position", []];
    private _id = _site getOrDefault ["id", ""];
    if (_id == "") then {
        _id = format ["SITE_%1_%2_%3", _type, floor diag_tickTime, _forEachIndex];
        _site set ["id", _id];
    };
    if (isNil {_site get "schema"}) then {_site set ["schema", 2]};
    if (isNil {_site get "createdAt"}) then {_site set ["createdAt", time]};

    private _refs = +(_site getOrDefault ["objects", []]);
    private _primary = _site getOrDefault ["object", objNull];
    private _operator = _site getOrDefault ["operator", objNull];
    if (!isNull _primary) then {_refs pushBackUnique _primary};
    if (!isNull _operator) then {_refs pushBackUnique _operator};
    _refs = _refs select {!isNull _x};
    private _liveRefs = _refs select {alive _x};
    private _oldStatus = _site getOrDefault ["status", "ACTIVE"];
    private _newStatus = if (count _refs == 0) then {
        if (_site getOrDefault ["virtual", false]) then {"ACTIVE"} else {"UNKNOWN"}
    } else {
        if (count _liveRefs == 0) then {"DESTROYED"} else {if (count _liveRefs < count _refs) then {"DEGRADED"} else {"ACTIVE"}}
    };
    _site set ["status", _newStatus];
    _site set ["physicalState", if (count _liveRefs > 0) then {"ACTIVE"} else {if (_newStatus == "DESTROYED") then {"DESTROYED"} else {"VIRTUAL"}}];
    _site set ["lastUpdatedAt", time];
    if (_newStatus == "DESTROYED" && {_oldStatus != "DESTROYED"}) then {
        _site set ["destroyedAt", time];
        DRO2026_siteHistory pushBackUnique _id;
        ["SITE_DESTROYED", createHashMapFromArray [["siteId", _id], ["siteType", _type], ["position", +_position]], _id] call DRO2026_fnc_emitEvent;
    };

    private _transient = _type in ["LOGISTICS_RUN", "CONVOY", "SUPPLY_CONVOY"];
    private _nodeId = _site getOrDefault ["networkNodeId", ""];
    if (_nodeId == "" && {!_transient}) then {
        _nodeId = [_type, _position] call _siteNodeId;
        if (_nodeId != "") then {_site set ["networkNodeId", _nodeId]};
    };
    if (_nodeId != "") then {
        {_x setVariable ["DRO2026_networkNodeId", _nodeId, true]} forEach _refs;
    };
    if (!_transient && {_nodeId != ""} && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
        _nodeSeen set [_nodeId, true];
        private _acc = _nodeRefs getOrDefault [_nodeId, []];
        {_acc pushBackUnique _x} forEach _liveRefs;
        _nodeRefs set [_nodeId, _acc];
        if (count _liveRefs > 0) then {_nodeHasLive set [_nodeId, true]};
    };
} forEach DRO2026_sites;

{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes get _nodeId;
    if (_nodeSeen getOrDefault [_nodeId, false]) then {
        private _refs = _nodeRefs getOrDefault [_nodeId, []];
        private _oldStatus = _node getOrDefault ["status", "ACTIVE"];
        private _newStatus = if (_nodeHasLive getOrDefault [_nodeId, false]) then {if (count _refs > 0) then {"ACTIVE"} else {"DEGRADED"}} else {"DESTROYED"};
        _node set ["physicalRefs", _refs];
        _node set ["physicalState", if (_newStatus == "ACTIVE") then {"ACTIVE"} else {if (_newStatus == "DEGRADED") then {"ACTIVE"} else {"DESTROYED"}}];
        _node set ["status", _newStatus];
        _node set ["lastUpdatedAt", time];
        if (_newStatus == "DESTROYED" && {_oldStatus != "DESTROYED"}) then {
            _node set ["destroyedAt", time];
            ["NETWORK_NODE_DESTROYED", createHashMapFromArray [["nodeId", _nodeId], ["nodeType", _node getOrDefault ["type", "UNKNOWN"]]], _nodeId] call DRO2026_fnc_emitEvent;
        };
        DRO2026_networkNodes set [_nodeId, _node];
    };
} forEach keys DRO2026_networkNodes;