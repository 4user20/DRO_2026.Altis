params [
    ["_max",1,[0]],
    ["_stream","DEFAULT",[""]],
    ["_min",0,[0]]
];
if (_max <= _min) exitWith {_min};

private _modulus = 65521;
private _seed = missionNamespace getVariable ["DRO2026_operationSeed",1];
if !(_seed isEqualType 0) then {_seed = 1};
_seed = (abs floor _seed) mod _modulus;
if (_seed <= 0) then {_seed = 1};

private _streams = missionNamespace getVariable ["DRO2026_seedStreams",createHashMap];
private _state = _streams getOrDefault [_stream,-1];
if (_state < 0) then {
    private _streamHash = 0;
    {
        _streamHash = ((_streamHash * 33) + _x) mod _modulus;
    } forEach (toArray _stream);
    _state = (_seed + _streamHash + 1) mod _modulus;
    if (_state <= 0) then {_state = 1};
};

// 251 * 65520 + 13849 stays below 2^24, avoiding precision loss in SQF Number arithmetic.
_state = (251 * _state + 13849) mod _modulus;
if (_state <= 0) then {_state = 1};
_streams set [_stream,_state];
missionNamespace setVariable ["DRO2026_seedStreams",_streams];
private _ratio = _state / _modulus;
_min + ((_max - _min) * _ratio)
