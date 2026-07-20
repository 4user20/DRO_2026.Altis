params [["_request", createHashMap, [createHashMap]]];
private _requestId = _request getOrDefault ["requestId", ""];
private _reject = {params ["_code", "_message"]; [false, _code, _message, _requestId, createHashMap] call DRO2026_fnc_makeResult};
if (_requestId == "") then {_requestId = format ["REQ_%1_%2", floor (diag_tickTime * 1000), floor random 1000000]};
private _channel = toUpperANSI (_request getOrDefault ["channel", ""]);
private _allowedChannels = ["ISR","FPV","STRIKE_UAV","LONG_RANGE_STRIKE","INTERCEPTOR","ARTILLERY","CAS","LOGISTICS"];
if !(_channel in _allowedChannels) exitWith {["CHANNEL_INVALID", "Unsupported support channel"] call _reject};
private _count = _request getOrDefault ["count", 1];
if !(_count isEqualType 0) exitWith {["COUNT_TYPE_INVALID", "count must be numeric"] call _reject};
_count = round _count;
if (_count < 1 || {_count > 10}) exitWith {["COUNT_OUT_OF_RANGE", "count must be in range 1..10"] call _reject};
private _targetMode = toUpperANSI (_request getOrDefault ["targetMode", "MAP_POINT"]);
if !(_targetMode in ["MAP_POINT","LOOK_POINT","CONTACT","OBJECT"]) exitWith {["TARGET_MODE_INVALID", "Unsupported target mode"] call _reject};
private _position = _request getOrDefault ["targetPositionASL", []];
private _validPosition = _position isEqualType [] && {count _position in [2,3]} && {(_position findIf {!(_x isEqualType 0)}) < 0};
if (_targetMode in ["MAP_POINT","LOOK_POINT"] && {!_validPosition}) exitWith {["TARGET_POSITION_INVALID", "targetPositionASL must contain 2 or 3 numbers"] call _reject};
if (_validPosition && {count _position == 2}) then {_position pushBack (getTerrainHeightASL _position)};
private _sourceMode = toUpperANSI (_request getOrDefault ["sourceMode", "AUTO"]);
if !(_sourceMode in ["AUTO","NODE","NEAREST_GROUP"]) exitWith {["SOURCE_MODE_INVALID", "Unsupported source mode"] call _reject};
private _controlMode = toUpperANSI (_request getOrDefault ["controlMode", "AUTO"]);
if !(_controlMode in ["AUTO","MANUAL"]) exitWith {["CONTROL_MODE_INVALID", "Unsupported control mode"] call _reject};
private _normalized = createHashMapFromArray [
    ["schema", 1], ["requestId", _requestId], ["channel", _channel],
    ["requesterNetId", _request getOrDefault ["requesterNetId", ""]],
    ["requesterUid", _request getOrDefault ["requesterUid", ""]],
    ["assetId", _request getOrDefault ["assetId", ""]],
    ["assetClass", _request getOrDefault ["assetClass", ""]],
    ["count", _count], ["targetMode", _targetMode], ["targetPositionASL", _position],
    ["targetObjectNetId", _request getOrDefault ["targetObjectNetId", ""]],
    ["contactId", _request getOrDefault ["contactId", ""]],
    ["sourceMode", _sourceMode], ["sourceNodeId", _request getOrDefault ["sourceNodeId", ""]],
    ["sourceGroupNetId", _request getOrDefault ["sourceGroupNetId", ""]],
    ["controlMode", _controlMode], ["createdAt", _request getOrDefault ["createdAt", time]]
];
[true, "OK", "Request normalized", _requestId, _normalized] call DRO2026_fnc_makeResult
