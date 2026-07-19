params ["_type", ["_payload", createHashMap], ["_sourceId", "SYSTEM"]];
if (!isServer) exitWith {createHashMap};
if !(_type isEqualType "") exitWith {createHashMap};
if (_type == "") exitWith {createHashMap};

private _emptyMap = createHashMap;
if !(_payload isEqualType _emptyMap) then {
    _payload = createHashMapFromArray [["value", _payload]];
};
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
if (count DRO2026_eventLog > 600) then {
    DRO2026_eventLog deleteRange [0, (count DRO2026_eventLog) - 600];
};
_event