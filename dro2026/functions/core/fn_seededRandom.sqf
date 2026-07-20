params [
    ["_max",1,[0]],
    ["_stream","DEFAULT",[""]],
    ["_min",0,[0]]
];
if (_max <= _min) exitWith {_min};
private _seed = missionNamespace getVariable ["DRO2026_operationSeed",1];
if !(_seed isEqualType 0) then {_seed = 1};
private _streams = missionNamespace getVariable ["DRO2026_seedStreams",createHashMap];
private _state = _streams getOrDefault [_stream,-1];
if (_state < 0) then {
    private _streamHash = 0;
    {
        _streamHash = ((_streamHash * 33) + _x) mod 2147483647;
    } forEach (toArray _stream);
    _state = (_seed + _streamHash + 1) mod 2147483647;
    if (_state <= 0) then {_state = 1};
};
_state = (1103515245 * _state + 12345) mod 2147483647;
if (_state <= 0) then {_state = 1};
_streams set [_stream,_state];
missionNamespace setVariable ["DRO2026_seedStreams",_streams];
private _ratio = _state / 2147483647;
_min + ((_max - _min) * _ratio)
