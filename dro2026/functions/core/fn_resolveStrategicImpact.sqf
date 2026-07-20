params [
    ["_munition",createHashMap,[createHashMap]],
    ["_impactASL",[],[[]]],
    ["_outcome","IMPACT",[""]]
];
if (!isServer || {count _munition == 0}) exitWith {createHashMap};
private _munitionId = _munition getOrDefault ["id",""];
private _nodeId = _munition getOrDefault ["targetNodeId",""];
private _yield = (_munition getOrDefault ["warheadYield",1]) max 0.1;
private _result = createHashMapFromArray [["munitionId",_munitionId],["outcome",toUpperANSI _outcome],["targetNodeId",_nodeId],["impactASL",+_impactASL]];
if ((toUpperANSI _outcome) == "INTERCEPTED") exitWith {
    _result set ["damageApplied",false];
    ["STRATEGIC_MUNITION_INTERCEPTED",_result,_munitionId] call DRO2026_fnc_emitEvent;
    _result
};
if (count _impactASL < 2) exitWith {_result};
private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
private _radius = 45 + (75 * _yield);
private _refs = if (count _node > 0) then {+(_node getOrDefault ["physicalRefs",[]])} else {[]};
private _siteRefs = [];
{
    if ((_x getOrDefault ["networkNodeId",""]) == _nodeId) then {
        {_siteRefs pushBackUnique _x} forEach (_x getOrDefault ["objects",[]]);
        private _primary = _x getOrDefault ["object",objNull];
        if (!isNull _primary) then {_siteRefs pushBackUnique _primary};
    };
} forEach DRO2026_sites;
{_refs pushBackUnique _x} forEach _siteRefs;
private _damaged = 0;
private _destroyed = 0;
{
    private _object = _x;
    if (!isNull _object && {alive _object}) then {
        private _distance = _object distance2D (ASLToAGL _impactASL);
        if (_distance <= _radius && {local _object}) then {
            private _falloff = 1 - ((_distance / _radius) min 1);
            private _damage = ((0.28 + (0.72 * _falloff)) * _yield) min 1;
            _object setDamage (((damage _object) + _damage) min 1);
            _damaged = _damaged + 1;
            if (!alive _object) then {_destroyed = _destroyed + 1};
        };
    };
} forEach _refs;
if (count _node > 0) then {
    private _stocks = _node getOrDefault ["stocks",createHashMap];
    private _stockLoss = (0.18 + (0.22 * (_yield min 2))) min 0.75;
    {
        private _old = _stocks getOrDefault [_x,0];
        _stocks set [_x,(_old * (1 - _stockLoss)) max 0];
    } forEach keys _stocks;
    _node set ["stocks",_stocks];
    private _oldStatus = toUpperANSI (_node getOrDefault ["status","ACTIVE"]);
    private _newStatus = _oldStatus;
    if (_destroyed > 0 || {_yield >= 1.5 && {_damaged > 1}}) then {_newStatus = "DEGRADED"};
    if (count _refs > 0 && {({_x isEqualType objNull && {!isNull _x} && {alive _x}} count _refs) == 0}) then {_newStatus = "DESTROYED"};
    _node set ["status",_newStatus];
    _node set ["lastImpactAt",time];
    _node set ["lastUpdatedAt",time];
    DRO2026_networkNodes set [_nodeId,_node];
    _result set ["nodeStatusBefore",_oldStatus];
    _result set ["nodeStatusAfter",_newStatus];
    _result set ["stockLossFraction",_stockLoss];
};
_result set ["damageApplied",true];
_result set ["damagedObjects",_damaged];
_result set ["destroyedObjects",_destroyed];
_result set ["effectRadius",_radius];
["STRATEGIC_IMPACT_RESOLVED",_result,_munitionId] call DRO2026_fnc_emitEvent;
[] call DRO2026_fnc_syncNetworkState;
_result