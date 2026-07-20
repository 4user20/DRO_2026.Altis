params [["_range", 1800], ["_maxShares", 24]];
if (!isServer) exitWith {0};
private _groups = +DRO2026_managedGroups;
{
    if ((side _x) == playersSide) then {_groups pushBackUnique _x};
} forEach allGroups;
_groups = _groups select {
    !isNull _x && {count units _x > 0} && {(side _x) in [enemySide, playersSide]} &&
    {alive leader _x} && {simulationEnabled leader _x} && {!(_x getVariable ["DRO2026_radioSilent", false])}
};
private _humans = allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}};
if (count _groups > 16) then {
    _groups = [_groups, [], {
        private _leader = leader _x;
        private _nearest = 1e10;
        {_nearest = _nearest min (_leader distance2D _x)} forEach _humans;
        _nearest
    }, "ASCEND"] call BIS_fnc_sortBy;
    _groups resize 16;
};
private _hasRadio = {
    params ["_group"];
    (_group getVariable ["DRO2026_isCommander", false]) ||
    {((units _group) findIf {alive _x && {"ItemRadio" in assignedItems _x}}) >= 0}
};
private _shares = 0;
{
    private _sourceGroup = _x;
    if ([_sourceGroup] call _hasRadio) then {
        private _sourceLeader = leader _sourceGroup;
        private _knownTargets = _sourceLeader targets [true, _range];
        {
            private _receiver = _x;
            if (_shares < _maxShares && {_receiver != _sourceGroup} && {side _receiver == side _sourceGroup} && {[_receiver] call _hasRadio} && {(leader _receiver) distance2D _sourceLeader <= _range}) then {
                private _receiverLeader = leader _receiver;
                {
                    private _target = _x;
                    private _knowledge = _sourceLeader knowsAbout _target;
                    if (!isNull _target && {alive _target} && {_knowledge > 1.25} && {_receiverLeader knowsAbout _target < (_knowledge * 0.70)}) then {
                        private _sharedKnowledge = (_knowledge * 0.68) min 2.8;
                        _receiverLeader reveal [_target, _sharedKnowledge];
                        private _owner = if (side _receiver == enemySide) then {"ENEMY"} else {"PLAYER"};
                        [_owner, _target, getPosATL _target, linearConversion [1.25, 4, _knowledge, 0.32, 0.72, true], "SHARED_CONTACT", "INFOSHARE", linearConversion [1.25, 4, _knowledge, 340, 110, true]] call DRO2026_fnc_addContact;
                        _shares = _shares + 1;
                    };
                } forEach _knownTargets;
            };
        } forEach _groups;
    };
} forEach _groups;
_shares
