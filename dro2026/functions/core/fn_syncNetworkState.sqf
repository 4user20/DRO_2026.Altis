if (!isServer) exitWith {};
if !(missionNamespace getVariable ["DRO2026_networkBuilt", false]) exitWith {};

private _siteNodeId = {
    params ["_type", "_position"];
    switch _type do {
        case "ENEMY_HQ": {"NODE_ENEMY_HQ"};
        case "FRIENDLY_HQ": {"NODE_FRIENDLY_HQ"};
        case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
        case "FRIENDLY_LOGISTICS": {"NODE_FRIENDLY_LOGISTICS"};
        case "ARTILLERY_SITE": {"NODE_ARTILLERY_01"};
        case "FPV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "STRATEGIC_DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "FRIENDLY_FPV_SITE": {"NODE_FRIENDLY_FPV"};
        case "FRIENDLY_DRONE_SITE": {"NODE_FRIENDLY_DRONES"};
        case "EW_SITE": {"NODE_EW_01"};
        case "BALLISTIC_MISSILE_SITE": {"NODE_BALLISTIC_01"};
        case "FARP": {"NODE_FARP_01"};
        case "FRIENDLY_FARP": {"NODE_FRIENDLY_FARP"};
        case "AIR_DEFENCE_SITE": {
            private _long = DRO2026_networkNodes getOrDefault ["NODE_AA_LONG_01", createHashMap];
            private _short = DRO2026_networkNodes getOrDefault ["NODE_AA_SHORAD_01", createHashMap];
            if ((_position distance2D (_long getOrDefault ["position", _position])) <= (_position distance2D (_short getOrDefault ["position", _position]))) then {"NODE_AA_LONG_01"} else {"NODE_AA_SHORAD_01"}
        };
        case "ENEMY_LAYERED_AA": {"NODE_AA_LONG_01"};
        case "FRIENDLY_LAYERED_AA": {"NODE_FRIENDLY_AA_LONG"};
        case "REAR_LINK": {"NODE_ENEMY_HQ"};
        default {""};
    }
};
private _terminalSiteStatuses = ["DESTROYED", "CANCELLED", "COMPLETED"];
private _nodeRefs = createHashMap;
private _nodeSeen = createHashMap;
private _nodeHasActive = createHashMap;
private _nodeHasDegraded = createHashMap;
private _nodeHasDisabled = createHashMap;
private _nodeHasDestroyed = createHashMap;

{
    private _site = [_x] call DRO2026_fnc_evaluateSiteComponents;
    private _type = _site getOrDefault ["type", "UNKNOWN"];
    private _position = _site getOrDefault ["position", []];
    private _id = _site getOrDefault ["id", ""];
    if (_id == "") then {_id = format ["SITE_%1_%2_%3", _type, floor diag_tickTime, _forEachIndex]; _site set ["id", _id]};
    if (isNil {_site get "schema"}) then {_site set ["schema", 4]};
    if (isNil {_site get "createdAt"}) then {_site set ["createdAt", time]};

    private _refs = +(_site getOrDefault ["objects", []]);
    private _primary = _site getOrDefault ["object", objNull];
    private _operator = _site getOrDefault ["operator", objNull];
    if (!isNull _primary) then {_refs pushBackUnique _primary};
    if (!isNull _operator) then {_refs pushBackUnique _operator};
    _refs = _refs select {!isNull _x};
    private _liveRefs = _refs select {alive _x};
    private _oldStatus = toUpperANSI (_site getOrDefault ["status", "ACTIVE"]);
    private _newStatus = _oldStatus;
    if !(_oldStatus in _terminalSiteStatuses) then {
        _newStatus = if (count _refs == 0) then {
            if (_site getOrDefault ["virtual", false]) then {"ACTIVE"} else {"UNKNOWN"}
        } else {
            if (count _liveRefs == 0) then {"DESTROYED"} else {if (count _liveRefs < count _refs) then {"DEGRADED"} else {"ACTIVE"}}
        };
    };

    private _transient = _type in ["LOGISTICS_RUN", "CONVOY", "SUPPLY_CONVOY"];
    private _nodeId = _site getOrDefault ["networkNodeId", ""];
    if (_nodeId == "" && {!_transient}) then {
        _nodeId = [_type, _position] call _siteNodeId;
        if (_nodeId != "") then {_site set ["networkNodeId", _nodeId]};
    };
    if (_nodeId != "") then {{_x setVariable ["DRO2026_networkNodeId", _nodeId, true]} forEach _refs};

    private _capabilities = _site getOrDefault ["capabilities",createHashMap];
    if (_site getOrDefault ["componentManaged",false] && {!(_newStatus in ["DESTROYED","CANCELLED","COMPLETED"])}) then {
        private _criticalAvailable = switch true do {
            case (_type in ["ENEMY_HQ","FRIENDLY_HQ"]): {_capabilities getOrDefault ["control",false]};
            case (_type in ["LOGISTICS_HUB","FRIENDLY_LOGISTICS"]): {_capabilities getOrDefault ["resupply",false] && {_capabilities getOrDefault ["control",true]}};
            case (_type in ["BALLISTIC_MISSILE_SITE","ARTILLERY_SITE","FPV_TEAM","UAV_TEAM","DRONE_SITE","STRATEGIC_DRONE_SITE","FRIENDLY_FPV_SITE","FRIENDLY_DRONE_SITE","POINT_DEFENCE"]): {_capabilities getOrDefault ["launch",false] && {_capabilities getOrDefault ["control",true]}};
            case (_type in ["AIR_DEFENCE_SITE","ENEMY_LAYERED_AA","FRIENDLY_LAYERED_AA"]): {_capabilities getOrDefault ["intercept",false] && {_capabilities getOrDefault ["detect",false]}};
            case (_type in ["FARP","FRIENDLY_FARP"]): {_capabilities getOrDefault ["resupply",false] && {_capabilities getOrDefault ["control",true]}};
            case (_type == "EW_SITE"): {_capabilities getOrDefault ["detect",false] && {_capabilities getOrDefault ["control",true]}};
            default {true};
        };
        if (!_criticalAvailable) then {_newStatus = "DISABLED"};
    };

    _site set ["status", _newStatus];
    _site set ["state", _newStatus];
    private _physicalState = switch _newStatus do {
        case "DESTROYED": {"DESTROYED"};
        case "DISABLED": {"DISABLED"};
        case "CANCELLED": {"DISABLED"};
        case "COMPLETED": {"COMPLETED"};
        default {if (count _liveRefs > 0) then {"ACTIVE"} else {"VIRTUAL"}};
    };
    _site set ["physicalState", _physicalState];
    _site set ["lastUpdatedAt", time];
    if (_newStatus == "DESTROYED" && {_oldStatus != "DESTROYED"}) then {
        _site set ["destroyedAt", time];
        DRO2026_siteHistory pushBackUnique _id;
        ["SITE_DESTROYED", createHashMapFromArray [["siteId", _id], ["siteType", _type], ["position", +_position]], _id] call DRO2026_fnc_emitEvent;
    };

    if (!_transient && {_nodeId != ""} && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
        private _node = DRO2026_networkNodes get _nodeId;
        private _componentHealth = _site getOrDefault ["componentHealth",createHashMap];
        private _nodeComponents = _node getOrDefault ["components",createHashMap];
        _nodeComponents set ["warehouse",_componentHealth getOrDefault ["stocks",1]];
        _nodeComponents set ["launcher",_componentHealth getOrDefault ["launchers",1]];
        _nodeComponents set ["radar",((_componentHealth getOrDefault ["antennas",1]) min (_componentHealth getOrDefault ["generators",1]))];
        _nodeComponents set ["commandLink",((_componentHealth getOrDefault ["terminals",1]) min (_componentHealth getOrDefault ["antennas",1]))];
        _nodeComponents set ["mobility",_componentHealth getOrDefault ["transports",1]];
        _node set ["components",_nodeComponents];

        private _stockHealth = _site getOrDefault ["stockHealth",1];
        private _lastStockHealth = _site getOrDefault ["lastAppliedStockHealth",1];
        if (_stockHealth < (_lastStockHealth - 0.001)) then {
            private _lossFraction = 1 - (_stockHealth / (_lastStockHealth max 0.001));
            private _stocks = _node getOrDefault ["stocks",createHashMap];
            {
                private _old = _stocks getOrDefault [_x,0];
                _stocks set [_x,(_old * (1 - _lossFraction)) max 0];
            } forEach keys _stocks;
            _node set ["stocks",_stocks];
            _site set ["lastAppliedStockHealth",_stockHealth];
            ["PHYSICAL_STOCKS_DESTROYED",createHashMapFromArray [
                ["siteId",_id],["nodeId",_nodeId],["lossFraction",_lossFraction],["stockHealth",_stockHealth]
            ],_nodeId] call DRO2026_fnc_emitEvent;
        };
        DRO2026_networkNodes set [_nodeId,_node];

        _nodeSeen set [_nodeId, true];
        switch _newStatus do {
            case "ACTIVE": {_nodeHasActive set [_nodeId, true]; private _acc = _nodeRefs getOrDefault [_nodeId, []]; {_acc pushBackUnique _x} forEach _liveRefs; _nodeRefs set [_nodeId, _acc]};
            case "DEGRADED": {_nodeHasDegraded set [_nodeId, true]; private _acc = _nodeRefs getOrDefault [_nodeId, []]; {_acc pushBackUnique _x} forEach _liveRefs; _nodeRefs set [_nodeId, _acc]};
            case "DESTROYED": {_nodeHasDestroyed set [_nodeId, true]};
            default {_nodeHasDisabled set [_nodeId, true]};
        };
    };
} forEach DRO2026_sites;

{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes get _nodeId;
    if (_nodeSeen getOrDefault [_nodeId, false]) then {
        private _refs = _nodeRefs getOrDefault [_nodeId, []];
        private _oldStatus = toUpperANSI (_node getOrDefault ["status", "ACTIVE"]);
        private _newStatus = if (_nodeHasActive getOrDefault [_nodeId, false]) then {
            "ACTIVE"
        } else {
            if (_nodeHasDegraded getOrDefault [_nodeId, false]) then {"DEGRADED"} else {
                if (_nodeHasDisabled getOrDefault [_nodeId, false]) then {"DISABLED"} else {"DESTROYED"}
            }
        };
        _node set ["physicalRefs", _refs];
        _node set ["physicalState", switch _newStatus do {case "ACTIVE": {"ACTIVE"}; case "DEGRADED": {"ACTIVE"}; case "DESTROYED": {"DESTROYED"}; default {"DISABLED"}}];
        _node set ["status", _newStatus];
        _node set ["lastUpdatedAt", time];
        if (_newStatus == "DESTROYED" && {_oldStatus != "DESTROYED"}) then {
            _node set ["destroyedAt", time];
            ["NETWORK_NODE_DESTROYED", createHashMapFromArray [["nodeId", _nodeId], ["nodeType", _node getOrDefault ["type", "UNKNOWN"]]], _nodeId] call DRO2026_fnc_emitEvent;
        };
        if (_newStatus == "DISABLED" && {!(_oldStatus in ["DISABLED", "DESTROYED"])}) then {
            _node set ["disabledAt", time];
            ["NETWORK_NODE_DISABLED", createHashMapFromArray [["nodeId", _nodeId], ["nodeType", _node getOrDefault ["type", "UNKNOWN"]]], _nodeId] call DRO2026_fnc_emitEvent;
        };
        DRO2026_networkNodes set [_nodeId, _node];
    };
} forEach keys DRO2026_networkNodes;