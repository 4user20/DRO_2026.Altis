params [["_site", createHashMap, [createHashMap]]];
if (count _site == 0) exitWith {_site};
if !(_site getOrDefault ["componentManaged",false]) exitWith {_site};
private _components = _site getOrDefault ["components", createHashMap];
private _countCategory = {
    params ["_name"];
    private _items = (_components getOrDefault [_name,[]]) select {!isNull _x};
    [count _items,{alive _x} count _items]
};
private _crewCounts = ["crew"] call _countCategory;
private _launcherCounts = ["launchers"] call _countCategory;
private _antennaCounts = ["antennas"] call _countCategory;
private _terminalCounts = ["terminals"] call _countCategory;
private _generatorCounts = ["generators"] call _countCategory;
private _transportCounts = ["transports"] call _countCategory;
private _stockCounts = ["stocks"] call _countCategory;
private _guardCounts = ["guards"] call _countCategory;
private _health = {
    params ["_counts"];
    _counts params ["_total","_alive"];
    if (_total <= 0) exitWith {1};
    _alive / _total
};
private _crewHealth = [_crewCounts] call _health;
private _launcherHealth = [_launcherCounts] call _health;
private _antennaHealth = [_antennaCounts] call _health;
private _terminalHealth = [_terminalCounts] call _health;
private _generatorHealth = [_generatorCounts] call _health;
private _transportHealth = [_transportCounts] call _health;
private _stockHealth = [_stockCounts] call _health;
private _guardHealth = [_guardCounts] call _health;
private _allObjects = (_site getOrDefault ["objects",[]]) select {!isNull _x};
private _aliveObjects = {alive _x} count _allObjects;
private _state = if (count _allObjects > 0 && {_aliveObjects == 0}) then {"DESTROYED"} else {
    if (_aliveObjects < count _allObjects) then {"DEGRADED"} else {"ACTIVE"}
};
private _capabilities = createHashMapFromArray [
    ["launch",(_launcherCounts select 0) == 0 || {(_launcherCounts select 1) > 0 && {(_crewCounts select 0) == 0 || {(_crewCounts select 1) > 0}}}],
    ["control",(_terminalCounts select 0) == 0 || {(_terminalCounts select 1) > 0 && {(_antennaCounts select 0) == 0 || {(_antennaCounts select 1) > 0}}}],
    ["relay",(_antennaCounts select 0) == 0 || {(_antennaCounts select 1) > 0}],
    ["detect",((_antennaCounts select 0) == 0 || {(_antennaCounts select 1) > 0}) && {(_generatorCounts select 0) == 0 || {(_generatorCounts select 1) > 0}}],
    ["intercept",(_launcherCounts select 0) > 0 && {(_launcherCounts select 1) > 0}],
    ["resupply",(_stockCounts select 0) == 0 || {(_stockCounts select 1) > 0}],
    ["relocate",(_transportCounts select 0) > 0 && {(_transportCounts select 1) > 0}]
];
_site set ["state",_state];
_site set ["status",_state];
_site set ["capabilities",_capabilities];
_site set ["stockHealth",_stockHealth];
_site set ["componentHealth",createHashMapFromArray [
    ["crew",_crewHealth],["launchers",_launcherHealth],["antennas",_antennaHealth],
    ["terminals",_terminalHealth],["generators",_generatorHealth],["transports",_transportHealth],
    ["stocks",_stockHealth],["guards",_guardHealth],["overall",if (count _allObjects > 0) then {_aliveObjects / count _allObjects} else {1}]
]];
_site set ["lastComponentEvaluation",time];
_site