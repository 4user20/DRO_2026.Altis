params [
    ["_subsystem", "SYSTEM", [""]],
    ["_event", "EVENT", [""]],
    ["_data", createHashMap, [createHashMap]],
    ["_dedupeKey", "", [""]]
];
private _key = if (_dedupeKey == "") then {format ["%1:%2", _subsystem, _event]} else {format ["%1:%2:%3", _subsystem, _event, _dedupeKey]};
private _counters = missionNamespace getVariable ["DRO2026_logDedupeCounters", createHashMap];
private _record = _counters getOrDefault [_key, createHashMapFromArray [["count",0],["lastAt",-999]]];
private _count = (_record getOrDefault ["count",0]) + 1;
private _lastAt = _record getOrDefault ["lastAt",-999];
_record set ["count", _count];
private _emit = _count == 1 || {(diag_tickTime - _lastAt) >= 60};
if (_emit) then {
    _record set ["lastAt", diag_tickTime];
    diag_log format ["[D26][%1][%2] count=%3 data=%4", toUpperANSI _subsystem, toUpperANSI _event, _count, _data];
};
_counters set [_key, _record];
missionNamespace setVariable ["DRO2026_logDedupeCounters", _counters];
_emit
