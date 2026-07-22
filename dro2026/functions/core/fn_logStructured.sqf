params [
    ["_subsystem", "SYSTEM", [""]],
    ["_event", "EVENT", [""]],
    ["_data", createHashMap, [createHashMap]],
    ["_dedupeKey", "", [""]]
];
// Preserve the old one-line structured API, but emit changed payloads immediately
// and suppress only identical repeats for up to 60 seconds.
[_subsystem, _event, _data, 1, _dedupeKey, 60] call DRO2026_fnc_telemetryRecord
