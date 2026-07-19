if (!isServer) exitWith {createHashMap};
[] call DRO2026_fnc_syncNetworkState;
[] call DRO2026_fnc_evaluateOperationPhase;

private _nodeSummary = [];
private _active = 0;
private _degraded = 0;
private _destroyed = 0;
{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes get _nodeId;
    private _status = _node getOrDefault ["status", "UNKNOWN"];
    switch _status do {
        case "DESTROYED": {_destroyed = _destroyed + 1};
        case "DISABLED": {_destroyed = _destroyed + 1};
        case "DEGRADED": {_degraded = _degraded + 1};
        case "RELOCATING": {_degraded = _degraded + 1};
        default {_active = _active + 1};
    };
    _nodeSummary pushBack createHashMapFromArray [
        ["id", _nodeId], ["type", _node getOrDefault ["type", "UNKNOWN"]], ["status", _status],
        ["knownByPlayer", _node getOrDefault ["knownByPlayer", "UNKNOWN"]], ["stocks", _node getOrDefault ["stocks", createHashMap]],
        ["emissionState", _node getOrDefault ["emissionState", "PASSIVE"]]
    ];
} forEach keys DRO2026_networkNodes;

private _eventCounts = createHashMap;
{
    private _type = _x getOrDefault ["type", "UNKNOWN"];
    _eventCounts set [_type, (_eventCounts getOrDefault [_type, 0]) + 1];
} forEach DRO2026_eventLog;
private _playerContacts = DRO2026_contacts select {(_x getOrDefault ["owner", ""]) == "PLAYER"};
private _confirmedBDA = count (_playerContacts select {(_x getOrDefault ["bdaState", ""]) == "CONFIRMED_DESTROYED"});
private _probableBDA = count (_playerContacts select {(_x getOrDefault ["bdaState", ""]) == "PROBABLY_DESTROYED"});
private _highQualityIntel = count (_playerContacts select {
    (_x getOrDefault ["confidence", 0]) >= 0.72 && {(_x getOrDefault ["uncertaintyRadius", 9999]) <= 250}
});
private _interdicted = _eventCounts getOrDefault ["DELIVERY_INTERDICTED", 0];
private _delivered = _eventCounts getOrDefault ["DELIVERY_COMPLETED", 0];
private _friendlyFireMissions = count (DRO2026_eventLog select {
    (_x getOrDefault ["type", ""]) == "FIRE_MISSION_EXECUTED" && {
        ((_x getOrDefault ["payload", createHashMap]) getOrDefault ["side", "ENEMY"]) == "PLAYER"
    }
});
private _airRequests = _eventCounts getOrDefault ["SUPPORT_REQUESTED", 0];
private _droneLaunches = _eventCounts getOrDefault ["DRONE_LAUNCHED", 0];
private _supportRecommendations = _eventCounts getOrDefault ["SUPPORT_RECOMMENDED", 0];
private _friendlyAutoStrikes = _eventCounts getOrDefault ["FRIENDLY_AUTO_STRIKE", 0];
private _civilianHarm = _eventCounts getOrDefault ["CIVILIAN_HARM", 0];
private _civilianReports = _eventCounts getOrDefault ["CIVILIAN_REPORT", 0];
private _civilianTrust = DRO2026_operationState getOrDefault ["civilianTrust", 55];
private _civilianFear = DRO2026_operationState getOrDefault ["civilianFear", 18];
private _localHostility = DRO2026_operationState getOrDefault ["localHostility", 10];
private _networkHealth = DRO2026_operationState getOrDefault ["networkHealth", 1];
private _score = round (
    ((1 - _networkHealth) * 55) +
    ((_destroyed / ((count DRO2026_networkNodes) max 1)) * 20) +
    ((_confirmedBDA min 8) * 2.5) +
    ((_interdicted min 6) * 2) +
    (linearConversion [0, 100, _civilianTrust, -8, 5, true]) -
    ((_civilianHarm min 8) * 8) -
    (linearConversion [0, 100, _localHostility, 0, 8, true]) -
    ((DRO2026_alertLevel max 0) * 8)
);
DRO2026_operationState set ["operationScore", _score];

createHashMapFromArray [
    ["schema", 1], ["version", DRO2026_VERSION],
    ["phase", DRO2026_operationState getOrDefault ["phase", "RECON"]],
    ["doctrine", DRO2026_operationState getOrDefault ["doctrine", "UNKNOWN"]],
    ["alertState", DRO2026_operationState getOrDefault ["alertState", "GREEN"]],
    ["networkHealth", _networkHealth], ["score", _score],
    ["activeNodes", _active], ["degradedNodes", _degraded], ["destroyedNodes", _destroyed],
    ["nodes", _nodeSummary], ["eventCounts", _eventCounts],
    ["confirmedBDA", _confirmedBDA], ["probableBDA", _probableBDA], ["highQualityIntel", _highQualityIntel],
    ["deliveriesInterdicted", _interdicted], ["deliveriesCompleted", _delivered],
    ["friendlyFireMissions", _friendlyFireMissions], ["airRequests", _airRequests], ["droneLaunchEvents", _droneLaunches],
    ["supportAutomation", DRO2026_supportPreset getOrDefault ["automation", "RECOMMEND_ONLY"]],
    ["supportRecommendations", _supportRecommendations], ["friendlyAutoStrikes", _friendlyAutoStrikes],
    ["civilianHarm", _civilianHarm], ["civilianReports", _civilianReports],
    ["civilianTrust", _civilianTrust], ["civilianFear", _civilianFear], ["localHostility", _localHostility],
    ["elapsed", time - (DRO2026_operationState getOrDefault ["startedAt", time])],
    ["generatedAt", time]
]