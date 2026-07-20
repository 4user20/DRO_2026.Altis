params [
    ["_requestOrPosition", createHashMap, [createHashMap, []]],
    ["_requesterOrManual", objNull, [objNull, true]],
    ["_legacyQuantity", 1, [0]],
    ["_legacyRequester", objNull, [objNull]],
    ["_legacyClass", "", [""]]
];
private _requester = if (_requesterOrManual isEqualType objNull) then {_requesterOrManual} else {_legacyRequester};
private _request = if (_requestOrPosition isEqualType createHashMap) then {_requestOrPosition} else {
    createHashMapFromArray [
        ["channel", "FPV"], ["assetClass", _legacyClass], ["count", _legacyQuantity],
        ["targetMode", "MAP_POINT"], ["targetPositionASL", AGLToASL _requestOrPosition],
        ["sourceMode", "AUTO"], ["controlMode", if (_requesterOrManual isEqualType true && {_requesterOrManual}) then {"MANUAL"} else {"AUTO"}]
    ]
};
private _requestId = _request getOrDefault ["requestId", ""];
private _reject = {
    params ["_code", "_message"];
    if (!isNull _requester) then {[_message, _requester] call DRO2026_fnc_supportMessage};
    [false, _code, _message, _requestId, createHashMap] call DRO2026_fnc_makeResult
};
if (!isServer) exitWith {if (!hasInterface) then {["NO_INTERFACE", "Client interface unavailable"] call _reject} else {[_request] call DRO2026_fnc_submitSupportRequest}};
[] call DRO2026_fnc_initState;
if (isNull _requester || {!alive _requester} || {!isPlayer _requester}) exitWith {["REQUESTER_INVALID", "Requester is not a live player"] call _reject};
if (side (group _requester) != playersSide) exitWith {["REQUESTER_SIDE_DENIED", "FPV support is unavailable for this side"] call _reject};
private _manualControl = (_request getOrDefault ["controlMode", "AUTO"]) == "MANUAL";
if (_manualControl && {!([_requester] call DRO2026_fnc_hasUAVTerminal)}) exitWith {["UAV_TERMINAL_REQUIRED", "A compatible UAV Terminal must be assigned before a manual FPV reservation"] call _reject};
private _quantity = (_request getOrDefault ["count", 1]) max 1 min 10;
if (_manualControl) then {_quantity = 1};
private _requestedClass = _request getOrDefault ["assetClass", ""];
private _requestSide = side (group _requester);
private _role = switch _requestSide do {case west: {"FPV_WEST"}; case resistance: {"FPV_GUER"}; default {"FPV_EAST"}};
private _allowedClasses = DRO2026_assetRegistry getOrDefault [_role, []];
if (_requestedClass != "" && {!(_requestedClass in _allowedClasses)}) exitWith {["ASSET_NOT_ALLOWED", "Requested FPV class is not available for this side"] call _reject};
if ((time - DRO2026_lastFPVRequest) < DRO2026_FPV_COOLDOWN) exitWith {["CHANNEL_COOLDOWN", "FPV team is preparing the next launch"] call _reject};
private _targetMode = _request getOrDefault ["targetMode", "MAP_POINT"];
private _targetPositionASL = _request getOrDefault ["targetPositionASL", []];
private _contactId = _request getOrDefault ["contactId", ""];
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} &&
    {(time - (_x getOrDefault ["lastSeenAt", _x getOrDefault ["lastSeen", 0]])) < 210} &&
    {[_x] call DRO2026_fnc_isLiveContactSubject}
};
if (_targetMode == "CONTACT") then {_contacts = _contacts select {(_x getOrDefault ["id", ""]) == _contactId}} else {
    _contacts = _contacts select {count _targetPositionASL > 1 && {((_x getOrDefault ["positionASL", _x getOrDefault ["positionMean", [0,0,0]]]) distance2D _targetPositionASL) < 320}};
};
if (count _contacts == 0) exitWith {["CONTACT_REQUIRED", "No fresh live confirmed target is available"] call _reject};
_contacts = [_contacts, [], {-(_x getOrDefault ["confidence", 0])}, "ASCEND"] call BIS_fnc_sortBy;
private _contact = _contacts select 0;
private _targetASL = _contact getOrDefault ["positionASL", _contact getOrDefault ["positionMean", _targetPositionASL]];
private _sourceMode = _request getOrDefault ["sourceMode", "AUTO"];
private _sourceNodeId = _request getOrDefault ["sourceNodeId", ""];
private _sourceGroupNetId = _request getOrDefault ["sourceGroupNetId", ""];
private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE" &&
    {[_x getOrDefault ["id", ""]] call DRO2026_fnc_isSiteOperational} &&
    {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetASL <= 4800}
};
if (_sourceMode == "NODE") then {_sites = _sites select {(_x getOrDefault ["networkNodeId", ""]) == _sourceNodeId}};
if (_sourceMode == "NEAREST_GROUP" && {_sourceGroupNetId != ""}) then {_sites = _sites select {netId (_x getOrDefault ["group", grpNull]) == _sourceGroupNetId}};
if (count _sites == 0) exitWith {["NO_CAPABLE_SOURCE", "No ready FPV group can execute this request"] call _reject};
_sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetASL}, "ASCEND"] call BIS_fnc_sortBy;
private _site = _sites select 0;
private _siteId = _site getOrDefault ["id", ""];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode];
private _operator = _site getOrDefault ["operator", objNull];
private _stock = DRO2026_resources getOrDefault ["friendlyFPVStock", 0];
private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
private _launchCount = (_quantity min _stock) min _slots;
if (_launchCount <= 0) exitWith {["INSUFFICIENT_STOCK", "FPV stock exhausted or active UAV limit reached"] call _reject};
DRO2026_resources set ["friendlyFPVStock", _stock - _launchCount];
DRO2026_lastFPVRequest = time;
["DRONE_LAUNCH_RESERVED", createHashMapFromArray [
    ["role", "FPV"], ["count", _launchCount], ["manual", _manualControl], ["requestedClass", _requestedClass],
    ["contactId", _contact getOrDefault ["id", ""]], ["siteId", _siteId], ["requestId", _requestId]
], _siteId] call DRO2026_fnc_emitEvent;
private _missionIds = [];
for "_index" from 0 to (_launchCount - 1) do {
    private _missionId = format ["FPV_%1_%2_%3", floor (diag_tickTime * 1000), _index, floor random 100000];
    _missionIds pushBack _missionId;
};
[_origin, _contact, _operator, _manualControl, _launchCount, _requestSide, _requester, _requestedClass, _siteId, _missionIds] spawn {
    params ["_origin", "_contact", "_operator", "_manualControl", "_count", "_requestSide", "_requester", "_requestedClass", "_siteId", "_missionIds"];
    for "_index" from 0 to (_count - 1) do {
        private _abort = (missionNamespace getVariable ["DRO2026_missionEnding", false]) || {!isNull _operator && {!alive _operator}} || {!([_siteId] call DRO2026_fnc_isSiteOperational)} || {!([_contact] call DRO2026_fnc_isLiveContactSubject)};
        if (_abort) exitWith {
            private _unlaunched = _count - _index;
            DRO2026_resources set ["friendlyFPVStock", (DRO2026_resources getOrDefault ["friendlyFPVStock", 0]) + _unlaunched];
            [format ["FPV salvo aborted before %1 remaining launches", _unlaunched]] call DRO2026_fnc_log;
        };
        private _launchOrigin = _origin getPos [4 + random 10, random 360];
        [_launchOrigin, _contact, _requestSide, _operator, _manualControl, _requester, _requestedClass, "", _siteId, _missionIds select _index] spawn DRO2026_fnc_launchFPVStrike;
        sleep (1.8 + random 2.4);
    };
};
[true, "RESERVED", if (_manualControl) then {"запрос на ручной FPV принят; подключение будет предложено после materialization"} else {"FPV package reserved and launch sequence started"}, _requestId, createHashMapFromArray [["count", _launchCount], ["siteId", _siteId], ["missionIds", _missionIds]]] call DRO2026_fnc_makeResult
