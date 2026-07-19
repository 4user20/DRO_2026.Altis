params ["_nodeId", "_cargoType", "_delta", ["_reason", ""]];
if (!isServer) exitWith {0};
private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
if (count _node == 0 || {!(_cargoType isEqualType "")}) exitWith {0};
private _stocks = _node getOrDefault ["stocks", createHashMap];
private _before = _stocks getOrDefault [_cargoType, 0];
private _after = (_before + _delta) max 0;
_stocks set [_cargoType, _after];
_node set ["stocks", _stocks];
_node set ["lastUpdatedAt", time];
DRO2026_networkNodes set [_nodeId, _node];
[
    "NODE_STOCK_CHANGED",
    createHashMapFromArray [
        ["nodeId", _nodeId], ["cargoType", _cargoType], ["before", _before],
        ["after", _after], ["delta", _after - _before], ["reason", _reason]
    ],
    _nodeId
] call DRO2026_fnc_emitEvent;
_after