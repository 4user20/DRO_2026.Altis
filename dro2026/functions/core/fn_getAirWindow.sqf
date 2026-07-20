params ["_position", ["_requestSide", playersSide]];
private _state = "PERMISSIVE";
private _risk = 0;
private _reasons = [];
private _knownThreats = 0;
private _unknownThreats = 0;

{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
    if (count _node > 0 && {!((_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED"])}) then {
        private _nodePos = _node getOrDefault ["position", _position];
        private _distance = _nodePos distance2D _position;
        private _radius = if (_nodeId == "NODE_AA_LONG_01") then {12500} else {4800};
        if (_distance <= _radius) then {
            private _stocks = _node getOrDefault ["stocks", createHashMap];
            private _missiles = _stocks getOrDefault ["AA_MISSILES", 0];
            private _channels = _node getOrDefault ["trackingChannels", if (_nodeId == "NODE_AA_LONG_01") then {3} else {2}];
            private _emission = _node getOrDefault ["emissionState", "SILENT"];
            private _known = (_node getOrDefault ["knownByPlayer", "UNKNOWN"]) in ["CONFIRMED", "TRACKED"];
            private _distanceFactor = linearConversion [0, _radius, _distance, 1, 0.15, true];
            private _threat = _distanceFactor * (linearConversion [0, 8, _missiles, 0.1, 1, true]) * (linearConversion [0, 3, _channels, 0.25, 1, true]);
            if (_emission in ["SEARCH", "TRACK", "ENGAGE", "PANIC"]) then {_threat = _threat + 0.18};
            _risk = _risk + _threat;
            if (_known) then {_knownThreats = _knownThreats + 1} else {_unknownThreats = _unknownThreats + 1};
            _reasons pushBack format ["%1: ракеты %2, каналы %3, режим %4", _nodeId, round _missiles, _channels, _emission];
        };
    };
} forEach ["NODE_AA_LONG_01", "NODE_AA_SHORAD_01"];

private _jamming = [_position, _requestSide] call DRO2026_fnc_getJammingAtPosition;
if (_jamming > 0.12) then {
    _risk = _risk + (_jamming * 0.55);
    _reasons pushBack format ["РЭБ: %1%%", round (_jamming * 100)];
};
private _weatherRisk = ((rain * 0.25) + (fog * 0.45)) min 0.55;
if (_weatherRisk > 0.12) then {_risk = _risk + _weatherRisk; _reasons pushBack "Погодные ограничения"};

private _friendliesClose = allUnits findIf {
    alive _x && {!(_x isKindOf "VirtualMan_F")} && {side (group _x) == _requestSide} && {_x distance2D _position < 350}
};
private _civiliansClose = allUnits findIf {
    alive _x && {!(_x isKindOf "VirtualMan_F")} && {side (group _x) == civilian} && {_x distance2D _position < 420}
};
if (_friendliesClose >= 0) then {_risk = _risk + 0.45; _reasons pushBack "Свои силы в зоне поражения"};
if (_civiliansClose >= 0) then {_risk = _risk + 0.55; _reasons pushBack "Гражданские в зоне поражения"};

if (_risk >= 1.05 || {_unknownThreats > 0 && {_risk >= 0.70}} || {_civiliansClose >= 0}) then {
    _state = "CLOSED";
} else {
    if (_risk >= 0.42 || {_knownThreats > 0} || {_jamming > 0.32}) then {_state = "CONTESTED"};
};
createHashMapFromArray [
    ["schema", 1], ["state", _state], ["risk", _risk min 2], ["reasons", _reasons],
    ["knownThreats", _knownThreats], ["unknownThreats", _unknownThreats], ["jamming", _jamming],
    ["friendliesClose", _friendliesClose >= 0], ["civiliansClose", _civiliansClose >= 0], ["evaluatedAt", time]
]
