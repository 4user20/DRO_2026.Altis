params [["_site", createHashMap, [createHashMap]]];
if (count _site == 0) exitWith {_site};
if !(_site getOrDefault ["componentManaged",false]) exitWith {_site};
private _components = _site getOrDefault ["components", createHashMap];
private _aliveCount = {params ["_name"]; {alive _x} count (_components getOrDefault [_name, []])};
private _crew = ["crew"] call _aliveCount; private _launchers = ["launchers"] call _aliveCount;
private _antennas = ["antennas"] call _aliveCount; private _terminals = ["terminals"] call _aliveCount;
private _generators = ["generators"] call _aliveCount; private _transports = ["transports"] call _aliveCount;
private _stocks = ["stocks"] call _aliveCount;
private _state = "ACTIVE";
if ((_crew + _launchers + _antennas + _terminals + _generators + _stocks) == 0) then {_state = "DESTROYED"} else {
    if (_antennas == 0 || {_terminals == 0} || {_generators == 0} || {_crew == 0}) then {_state = "DEGRADED"};
};
private _capabilities = createHashMapFromArray [["launch",_launchers > 0 && {_crew > 0}],["control",_terminals > 0 && {_antennas > 0}],["relay",_antennas > 0],["detect",_antennas > 0 && {_generators > 0}],["intercept",_launchers > 0],["resupply",_stocks > 0],["relocate",_transports > 0]];
_site set ["state", _state]; _site set ["status", _state]; _site set ["capabilities", _capabilities]; _site set ["lastComponentEvaluation", time];
_site
