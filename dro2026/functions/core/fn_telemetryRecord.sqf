/*
    Low-overhead structured RPT telemetry.

    Levels:
      1 BASIC   - authoritative mission events and lifecycle changes
      2 VERBOSE - bounded deltas for DRO-managed entities/groups/sites/nodes
      3 TRACE   - finer position buckets and shorter snapshot intervals

    Identical payloads are suppressed until _minInterval expires. A changed
    payload is emitted immediately, so state transitions are never hidden by
    the rate limiter.
*/
params [
    ["_subsystem", "SYSTEM", [""]],
    ["_event", "EVENT", [""]],
    ["_data", createHashMap, [createHashMap]],
    ["_level", 1, [0]],
    ["_dedupeKey", "", [""]],
    ["_minInterval", -1, [0]]
];

private _modeValue = missionNamespace getVariable ["DRO2026_TELEMETRY_MODE", "BASIC"];
private _modeRank = if (_modeValue isEqualType 0) then {
    ((round _modeValue) max 0) min 3
} else {
    switch (if (_modeValue isEqualType "") then {toUpperANSI _modeValue} else {"BASIC"}) do {
        case "OFF": {0};
        case "BASIC": {1};
        case "VERBOSE": {2};
        case "TRACE": {3};
        default {1};
    }
};
_level = ((round _level) max 1) min 3;
if (_modeRank < _level) exitWith {false};

_subsystem = toUpperANSI _subsystem;
_event = toUpperANSI _event;
private _categories = missionNamespace getVariable ["DRO2026_TELEMETRY_CATEGORIES", []];
if (_categories isEqualType [] && {count _categories > 0}) then {
    private _allowed = _categories apply {if (_x isEqualType "") then {toUpperANSI _x} else {toUpperANSI (str _x)}};
    if !(_subsystem in _allowed) exitWith {false};
};

if (_minInterval < 0) then {
    _minInterval = switch _level do {case 1: {0}; case 2: {15}; default {5}};
};
private _keyTail = if (_dedupeKey == "") then {"GLOBAL"} else {_dedupeKey};
private _key = format ["%1:%2:%3", _subsystem, _event, _keyTail];
private _now = diag_tickTime;
private _signature = hashValue (str _data);
private _cache = missionNamespace getVariable ["DRO2026_telemetryDedupe", createHashMap];
private _entry = _cache getOrDefault [_key, createHashMapFromArray [
    ["lastAt", -9999], ["signature", -1], ["seen", 0], ["suppressed", 0]
]];
private _seen = (_entry getOrDefault ["seen", 0]) + 1;
private _same = (_entry getOrDefault ["signature", -1]) == _signature;
private _elapsed = _now - (_entry getOrDefault ["lastAt", -9999]);
private _emit = !_same || {_minInterval <= 0} || {_elapsed >= _minInterval};
_entry set ["seen", _seen];

private _stats = missionNamespace getVariable ["DRO2026_telemetryStats", createHashMapFromArray [
    ["emitted", 0], ["suppressed", 0]
]];
if (!_emit) exitWith {
    _entry set ["suppressed", (_entry getOrDefault ["suppressed", 0]) + 1];
    _entry set ["signature", _signature];
    _cache set [_key, _entry];
    missionNamespace setVariable ["DRO2026_telemetryDedupe", _cache];
    _stats set ["suppressed", (_stats getOrDefault ["suppressed", 0]) + 1];
    missionNamespace setVariable ["DRO2026_telemetryStats", _stats];
    false
};

private _suppressed = _entry getOrDefault ["suppressed", 0];
_entry set ["lastAt", _now];
_entry set ["signature", _signature];
_entry set ["suppressed", 0];
_cache set [_key, _entry];
missionNamespace setVariable ["DRO2026_telemetryDedupe", _cache];

private _sequence = (missionNamespace getVariable ["DRO2026_telemetrySequence", 0]) + 1;
missionNamespace setVariable ["DRO2026_telemetrySequence", _sequence];
_stats set ["emitted", (_stats getOrDefault ["emitted", 0]) + 1];
missionNamespace setVariable ["DRO2026_telemetryStats", _stats];

private _role = if (isDedicated) then {"DEDICATED"} else {if (isServer && {hasInterface}) then {"HOST"} else {if (isServer) then {"SERVER"} else {"CLIENT"}}};
private _fps = floor (diag_fps * 10) / 10;
diag_log format [
    "[D26T][%1][%2][L%3] seq=%4 t=%5 dt=%6 frame=%7 fps=%8 role=%9 seen=%10 suppressed=%11 data=%12",
    _subsystem, _event, _level, _sequence, floor (time * 10) / 10,
    floor (_now * 1000) / 1000, diag_frameNo, _fps, _role, _seen, _suppressed, _data
];
true
