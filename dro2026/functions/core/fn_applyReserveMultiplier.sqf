params [["_force", false, [true]]];
if (!isServer) exitWith {false};
if ((missionNamespace getVariable ["DRO2026_reserveMultiplierApplied",false]) && {!_force}) exitWith {true};
private _multiplier = (missionNamespace getVariable ["DRO2026_ReserveMultiplier",3]) max 1;
{
    private _key = _x;
    DRO2026_resources set [_key, round ((DRO2026_resources getOrDefault [_key,0]) * _multiplier)];
} forEach keys DRO2026_resources;
{
    private _nodeId = _x;
    private _node = DRO2026_networkNodes get _nodeId;
    private _stocks = _node getOrDefault ["stocks",createHashMap];
    private _capacity = _node getOrDefault ["stockCapacity",createHashMap];
    {_stocks set [_x,round ((_stocks getOrDefault [_x,0]) * _multiplier)]} forEach keys _stocks;
    {_capacity set [_x,round ((_capacity getOrDefault [_x,0]) * _multiplier)]} forEach keys _capacity;
    _node set ["stocks",_stocks]; _node set ["stockCapacity",_capacity];
    DRO2026_networkNodes set [_nodeId,_node];
} forEach keys DRO2026_networkNodes;
missionNamespace setVariable ["DRO2026_reserveMultiplierApplied",true,true];
["INIT","RESERVE_MULTIPLIER_APPLIED",createHashMapFromArray [["multiplier",_multiplier]],"RESERVES"] call DRO2026_fnc_logStructured;
true
