params [["_since", -1], ["_types", []], ["_limit", 100]];
if !(_types isEqualType []) then {_types = []};
_limit = ((_limit max 1) min 300);
private _events = DRO2026_eventLog select {
    (_x getOrDefault ["createdAt", -1]) > _since && {
        count _types == 0 || {(_x getOrDefault ["type", ""]) in _types}
    }
};
_events = [_events, [], {_x getOrDefault ["createdAt", 0]}, "DESCEND"] call BIS_fnc_sortBy;
if (count _events > _limit) then {_events resize _limit};
_events