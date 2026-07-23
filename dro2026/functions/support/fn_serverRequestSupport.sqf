if (!isServer) exitWith {};
params [["_request", createHashMap, [createHashMap]]];
[] call DRO2026_fnc_initState;
private _normalizedResult = [_request] call DRO2026_fnc_normalizeSupportRequest;
private _requestId = _normalizedResult getOrDefault ["requestId", _request getOrDefault ["requestId", ""]];
private _sendResult = {
    params ["_result", ["_requester", objNull]];
    if (!isNull _requester) then {[_result] remoteExecCall ["DRO2026_fnc_receiveSupportResult", owner _requester, false]};
    _result
};
if !(_normalizedResult getOrDefault ["ok", false]) exitWith {
    ["SUPPORT", "NORMALIZATION_REJECTED", createHashMapFromArray [
        ["requestId", _requestId], ["code", _normalizedResult getOrDefault ["code", ""]],
        ["message", _normalizedResult getOrDefault ["message", ""]]
    ], 1, _requestId, 0] call DRO2026_fnc_telemetryRecord;
    [_normalizedResult, objNull] call _sendResult
};
private _normalized = _normalizedResult getOrDefault ["data", createHashMap];
private _identity = [_normalized] call DRO2026_fnc_resolveRemoteRequester;
_identity params ["_identityOk", "_identityCode", "_actualUid", "_requester", "_remoteOwner"];
if (!_identityOk) exitWith {
    private _result = [false, _identityCode, "Requester ownership validation failed", _requestId, createHashMapFromArray [["remoteOwner", _remoteOwner]]] call DRO2026_fnc_makeResult;
    ["SUPPORT", "IDENTITY_REJECTED", createHashMapFromArray [
        ["requestId", _requestId], ["code", _identityCode], ["remoteOwner", _remoteOwner]
    ], 1, _requestId, 0] call DRO2026_fnc_telemetryRecord;
    [_result, objNull] call _sendResult
};
_normalized set ["requesterUid", _actualUid];
_normalized set ["requesterNetId", netId _requester];
private _processed = missionNamespace getVariable ["DRO2026_processedSupportRequests", createHashMap];
private _existing = _processed getOrDefault [_requestId, createHashMap];
if (count _existing > 0) exitWith {
    ["SUPPORT", "DUPLICATE_REQUEST", createHashMapFromArray [
        ["requestId", _requestId], ["requesterUid", _actualUid],
        ["existingCode", _existing getOrDefault ["code", ""]]
    ], 1, _requestId, 0] call DRO2026_fnc_telemetryRecord;
    [_existing, _requester] call _sendResult
};
private _rateKey = format ["DRO2026_supportRequest_%1", _actualUid];
private _lastRequest = missionNamespace getVariable [_rateKey, -10];
if ((diag_tickTime - _lastRequest) < 0.35) exitWith {
    private _result = [false, "RATE_LIMITED", "Request is already being processed", _requestId, createHashMap] call DRO2026_fnc_makeResult;
    ["SUPPORT", "RATE_LIMITED", createHashMapFromArray [
        ["requestId", _requestId], ["requesterUid", _actualUid],
        ["sincePrevious", diag_tickTime - _lastRequest]
    ], 1, _actualUid, 0] call DRO2026_fnc_telemetryRecord;
    [_result, _requester] call _sendResult
};
missionNamespace setVariable [_rateKey, diag_tickTime];
private _channel = _normalized getOrDefault ["channel", ""];
["SUPPORT", "REQUEST_RECEIVED", createHashMapFromArray [
    ["requestId", _requestId], ["channel", _channel],
    ["assetId", _normalized getOrDefault ["assetId", ""]],
    ["assetClass", _normalized getOrDefault ["assetClass", ""]],
    ["count", _normalized getOrDefault ["count", 1]],
    ["targetMode", _normalized getOrDefault ["targetMode", ""]],
    ["targetPositionASL", _normalized getOrDefault ["targetPositionASL", []]],
    ["targetObjectNetId", _normalized getOrDefault ["targetObjectNetId", ""]],
    ["contactId", _normalized getOrDefault ["contactId", ""]],
    ["sourceMode", _normalized getOrDefault ["sourceMode", ""]],
    ["sourceNodeId", _normalized getOrDefault ["sourceNodeId", ""]],
    ["sourceGroupNetId", _normalized getOrDefault ["sourceGroupNetId", ""]],
    ["controlMode", _normalized getOrDefault ["controlMode", ""]],
    ["requesterUid", _actualUid], ["requesterNetId", netId _requester],
    ["remoteOwner", _remoteOwner]
], 1, _requestId, 0] call DRO2026_fnc_telemetryRecord;
private _result = switch _channel do {
    case "FPV": {[_normalized, _requester] call DRO2026_fnc_requestFPV};
    case "ISR": {
        private _assetClass = _normalized getOrDefault ["assetClass", ""];
        private _type = if (_assetClass == "") then {_normalized getOrDefault ["assetId", "AUTO"]} else {format ["CLASS:%1", _assetClass]};
        [_normalized getOrDefault ["targetPositionASL", []], _type, _requester] call DRO2026_fnc_requestISR;
        [true, "ACCEPTED", "ISR request accepted for processing", _requestId, createHashMap] call DRO2026_fnc_makeResult
    };
    case "LONG_RANGE_STRIKE": {
        private _assetClass = _normalized getOrDefault ["assetClass", ""];
        private _type = if (_assetClass == "") then {_normalized getOrDefault ["assetId", "AUTO"]} else {format ["CLASS:%1", _assetClass]};
        private _decoy = toUpperANSI (_normalized getOrDefault ["assetId", ""]) == "DECOY";
        [_normalized getOrDefault ["targetPositionASL", []], _type, _decoy, _normalized getOrDefault ["count", 1], _requester, _requestId] call DRO2026_fnc_requestLongRangeSupport
    };
    case "ARTILLERY": {
        [_normalized getOrDefault ["targetPositionASL", []], _normalized getOrDefault ["assetClass", ""], _normalized getOrDefault ["count", 1], _requester] call DRO2026_fnc_requestArtillery;
        [true, "ACCEPTED", "Artillery request accepted", _requestId, createHashMap] call DRO2026_fnc_makeResult
    };
    case "CAS": {
        [_normalized getOrDefault ["targetPositionASL", []], _normalized getOrDefault ["assetClass", ""], _normalized getOrDefault ["count", 1], _requester] call DRO2026_fnc_requestAirSupport;
        [true, "ACCEPTED", "CAS request accepted", _requestId, createHashMap] call DRO2026_fnc_makeResult
    };
    case "INTERCEPTOR": {[_normalized, _requester] call DRO2026_fnc_requestInterceptor};
    default {[false, "CHANNEL_NOT_IMPLEMENTED", format ["Channel %1 is not implemented", _channel], _requestId, createHashMap] call DRO2026_fnc_makeResult};
};
if !(_result isEqualType createHashMap) then {_result = [false, "INVALID_HANDLER_RESULT", "Support handler returned an invalid result", _requestId, createHashMap] call DRO2026_fnc_makeResult};
_processed set [_requestId, _result];
if (count _processed > 256) then {
    private _keys = keys _processed;
    for "_index" from 0 to ((count _keys) - 193) do {_processed deleteAt (_keys select _index)};
};
missionNamespace setVariable ["DRO2026_processedSupportRequests", _processed];
["SUPPORT", if (_result getOrDefault ["ok", false]) then {"REQUEST_ACCEPTED"} else {"REQUEST_REJECTED"}, createHashMapFromArray [["requestId", _requestId], ["channel", _channel], ["code", _result getOrDefault ["code", ""]], ["requesterUid", _actualUid]], _requestId] call DRO2026_fnc_logStructured;
[_result, _requester] call _sendResult
