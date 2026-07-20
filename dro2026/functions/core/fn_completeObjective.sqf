params ["_taskName", ["_voice", "TASK_COMPLETE"], ["_resourceChanges", []]];
if (!isServer) exitWith {};
if ((missionNamespace getVariable [format ["%1Completed", _taskName], 0]) == 1) exitWith {};
missionNamespace setVariable [format ["%1Completed", _taskName], 1, true];
[_taskName, "SUCCEEDED", true] spawn BIS_fnc_taskSetState;

{
    _x params ["_key", "_delta"];
    private _current = DRO2026_resources getOrDefault [_key, 0];
    DRO2026_resources set [_key, (((_current + _delta) max 0) min 100)];
} forEach _resourceChanges;

private _meta = DRO2026_objectiveMeta getOrDefault [_taskName, createHashMap];
private _type = _meta getOrDefault ["type", "UNKNOWN"];
private _nodeId = _meta getOrDefault ["nodeId", ""];
if (_nodeId == "") then {
    _nodeId = switch _type do {
        case "LOGISTICS_HUB": {"NODE_LOGISTICS_01"};
        case "LOGISTICS_RUN": {"NODE_LOGISTICS_01"};
        case "CONVOY_INTERDICTION": {"NODE_LOGISTICS_01"};
        case "ARTILLERY_HUNT": {"NODE_ARTILLERY_01"};
        case "EW_HUNT": {"NODE_EW_01"};
        case "DRONE_SITE": {"NODE_DRONE_REAR_01"};
        case "UAV_TEAM": {"NODE_FPV_FORWARD_01"};
        case "AIR_DEFENCE": {"NODE_AA_LONG_01"};
        case "CUT_REAR": {"NODE_ENEMY_HQ"};
        default {""};
    };
};

private _destructiveTypes = [
    "LOGISTICS_HUB", "LOGISTICS_RUN", "CONVOY_INTERDICTION", "ARTILLERY_HUNT",
    "EW_HUNT", "DRONE_SITE", "UAV_TEAM", "AIR_DEFENCE", "CUT_REAR"
];
private _destructive = _type in _destructiveTypes;
private _siteId = _meta getOrDefault ["siteId", ""];
private _deliveryId = _meta getOrDefault ["deliveryId", ""];
private _criticalValue = _meta getOrDefault ["critical", []];
private _critical = if (_criticalValue isEqualType []) then {+_criticalValue} else {[]};
{
    private _candidate = _meta getOrDefault [_x, objNull];
    if (_candidate isEqualType objNull && {!isNull _candidate}) then {_critical pushBackUnique _candidate};
} forEach ["object", "vehicle"];
_critical = _critical select {_x isEqualType objNull && {!isNull _x}};

private _matchedSites = 0;
{
    private _site = _x;
    private _refs = +(_site getOrDefault ["objects", []]);
    private _primary = _site getOrDefault ["object", objNull];
    private _operator = _site getOrDefault ["operator", objNull];
    if (!isNull _primary) then {_refs pushBackUnique _primary};
    if (!isNull _operator) then {_refs pushBackUnique _operator};
    _refs = _refs select {_x isEqualType objNull && {!isNull _x}};

    private _matchesIdentity = (_siteId != "" && {(_site getOrDefault ["id", ""]) == _siteId}) ||
        {(_deliveryId != "") && {(_site getOrDefault ["deliveryId", ""]) == _deliveryId}};
    private _matchesCritical = count _critical > 0 && {(_critical findIf {_x in _refs}) >= 0};
    private _hasExactSelector = _siteId != "" || {_deliveryId != ""} || {count _critical > 0};
    private _matchesNode = !_hasExactSelector && {_destructive} && {_nodeId != ""} && {(_site getOrDefault ["networkNodeId", ""]) == _nodeId};
    if (_matchesIdentity || {_matchesCritical} || {_matchesNode}) then {
        private _liveRefs = _refs select {alive _x};
        private _siteStatus = if (count _liveRefs == 0) then {"DESTROYED"} else {if (_destructive) then {"DISABLED"} else {"COMPLETED"}};
        private _sitePhysicalState = switch _siteStatus do {
            case "DESTROYED": {"DESTROYED"};
            case "COMPLETED": {"COMPLETED"};
            default {"DISABLED"};
        };
        _site set ["status", _siteStatus];
        _site set ["physicalState", _sitePhysicalState];
        _site set ["terminalReason", "OBJECTIVE_COMPLETED"];
        _site set ["lastUpdatedAt", time];
        switch _siteStatus do {
            case "DESTROYED": {_site set ["destroyedAt", time]};
            case "COMPLETED": {_site set ["completedAt", time]};
            default {_site set ["disabledAt", time]};
        };
        _matchedSites = _matchedSites + 1;
    };
} forEach DRO2026_sites;

[] call DRO2026_fnc_syncNetworkState;

if (_destructive && {_nodeId != ""} && {_matchedSites == 0} && {!isNil {DRO2026_networkNodes get _nodeId}}) then {
    private _node = DRO2026_networkNodes get _nodeId;
    private _liveRefs = (_node getOrDefault ["physicalRefs", []]) select {!isNull _x && {alive _x}};
    private _nodeStatus = if (count _liveRefs == 0) then {"DESTROYED"} else {"DISABLED"};
    private _timestampKey = if (_nodeStatus == "DESTROYED") then {"destroyedAt"} else {"disabledAt"};
    _node set ["status", _nodeStatus];
    _node set ["physicalState", _nodeStatus];
    _node set [_timestampKey, time];
    _node set ["lastUpdatedAt", time];
    DRO2026_networkNodes set [_nodeId, _node];
};

_meta set ["effectStatus", "APPLIED"];
_meta set ["completedAt", time];
_meta set ["matchedSites", _matchedSites];
DRO2026_objectiveMeta set [_taskName, _meta];

private _effect = createHashMapFromArray [
    ["task", _taskName], ["type", _type], ["nodeId", _nodeId],
    ["completedAt", time], ["resourceChanges", _resourceChanges], ["matchedSites", _matchedSites]
];
private _effects = DRO2026_operationState getOrDefault ["completedEffects", []];
_effects pushBack _effect;
DRO2026_operationState set ["completedEffects", _effects];
["OBJECTIVE_COMPLETED", _effect, if (_nodeId == "") then {"OPERATION"} else {_nodeId}] call DRO2026_fnc_emitEvent;
[] call DRO2026_fnc_syncNetworkState;
[] call DRO2026_fnc_evaluateOperationPhase;
[_voice] call DRO2026_fnc_hqVoice;
if (DRO2026_AUTO_SAVE && {!isMultiplayer}) then {saveGame};
