params ["_type", ["_payload", createHashMap], ["_sourceId", "SYSTEM"]];
if (!isServer) exitWith {createHashMap};
if !(_type isEqualType "") exitWith {createHashMap};
if (_type == "") exitWith {createHashMap};

private _emptyMap = createHashMap;
if !(_payload isEqualType _emptyMap) then {_payload = createHashMapFromArray [["value", _payload]]};
DRO2026_eventSequence = DRO2026_eventSequence + 1;
private _event = createHashMapFromArray [
    ["schema", 1],
    ["id", format ["EV_%1_%2", floor diag_tickTime, DRO2026_eventSequence]],
    ["type", _type],
    ["sourceId", _sourceId],
    ["payload", _payload],
    ["createdAt", time]
];
DRO2026_eventLog pushBack _event;
private _totalCounts = missionNamespace getVariable ["DRO2026_telemetryEventCounts", createHashMap];
_totalCounts set [_type, (_totalCounts getOrDefault [_type, 0]) + 1];
missionNamespace setVariable ["DRO2026_telemetryEventCounts", _totalCounts];
private _intervalCounts = missionNamespace getVariable ["DRO2026_telemetryEventIntervalCounts", createHashMap];
_intervalCounts set [_type, (_intervalCounts getOrDefault [_type, 0]) + 1];
missionNamespace setVariable ["DRO2026_telemetryEventIntervalCounts", _intervalCounts];
private _noisy = _type in ["CONTACT_UPDATED", "BDA_UPDATED", "EMISSION_DETECTED"];
["EVENT", _type, createHashMapFromArray [
    ["eventId", _event get "id"], ["sourceId", _sourceId], ["payload", _payload]
], if (_noisy) then {2} else {1}, _sourceId, if (_noisy) then {10} else {0}] call DRO2026_fnc_telemetryRecord;
private _limit = missionNamespace getVariable ["DRO2026_MAX_EVENT_LOG", 600];
if (count DRO2026_eventLog > _limit) then {
    DRO2026_eventLog deleteRange [0, (count DRO2026_eventLog) - _limit];
};
_event