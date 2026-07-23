params [
    ["_message", "MANUAL_MARK", [""]],
    ["_object", objNull, [objNull]],
    ["_metadata", createHashMap, [createHashMap]]
];
private _subject = _object;
if (isNull _subject && {hasInterface}) then {_subject = player};
private _data = createHashMapFromArray [
    ["message", _message],
    ["object", if (isNull _subject) then {""} else {netId _subject}],
    ["class", if (isNull _subject) then {""} else {typeOf _subject}],
    ["positionASL", if (isNull _subject) then {[]} else {getPosASL _subject}],
    ["telemetryMode", missionNamespace getVariable ["DRO2026_TELEMETRY_MODE", "BASIC"]]
];
{_data set [_x, _metadata get _x]} forEach keys _metadata;
["USER", "MARK", _data, 1, format ["%1:%2", _message, floor diag_tickTime], 0] call DRO2026_fnc_telemetryRecord
