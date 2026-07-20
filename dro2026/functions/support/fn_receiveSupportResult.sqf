params [["_result", createHashMap, [createHashMap]]];
if (!hasInterface) exitWith {};
missionNamespace setVariable ["DRO2026_lastSupportResult", _result];
private _message = _result getOrDefault ["message", ""];
if (_message != "") then {systemChat format ["Штаб: %1", _message]};
