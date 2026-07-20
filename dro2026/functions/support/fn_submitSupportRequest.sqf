params [["_request", createHashMap, [createHashMap]]];
if (!hasInterface) exitWith {[false, "NO_INTERFACE", "Client interface is unavailable", "", createHashMap] call DRO2026_fnc_makeResult};
private _normalized = [_request] call DRO2026_fnc_normalizeSupportRequest;
if !(_normalized getOrDefault ["ok", false]) exitWith {_normalized};
private _data = _normalized getOrDefault ["data", createHashMap];
_data set ["requesterUid", getPlayerUID player];
_data set ["requesterNetId", netId player];
_data set ["createdAt", time];
[_data] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
[true, "SUBMITTED", "Support request submitted", _data getOrDefault ["requestId", ""], createHashMap] call DRO2026_fnc_makeResult
