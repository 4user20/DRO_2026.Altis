params ["_contact"];
if !(_contact isEqualType createHashMap) exitWith {};
private _targetPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
if (count _targetPos < 2) exitWith {};
private _available = DRO2026_managedGroups select {
    private _leader = leader _x;
    !isNull _x &&
    {!isNull _leader} &&
    {alive _leader} &&
    {side _x == enemySide} &&
    {({alive _x} count units _x) > 0} &&
    {!(_x getVariable ["DRO2026_static", false])} &&
    {(_x getVariable ["DRO2026_reactionUntil", 0]) < time} &&
    {_leader distance2D _targetPos < 5000}
};
private _needed = 3 min count _available;
if (_needed <= 0) exitWith {};
_available = [_available, [], {(leader _x) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
for "_i" from 0 to (_needed - 1) do {
    private _group = _available select _i;
    private _leader = leader _group;
    if (!isNull _leader && {alive _leader}) then {
        while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
        private _approach = _leader getDir _targetPos;
        private _offset = switch (_i) do {case 0: {-65}; case 1: {65}; default {0}};
        private _flank = _targetPos getPos [420 + random 360, _approach + 180 + _offset];
        private _wp1 = _group addWaypoint [_flank, 40];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "FULL";
        _wp1 setWaypointBehaviour "AWARE";
        private _wp2 = _group addWaypoint [_targetPos, 80];
        _wp2 setWaypointType "SAD";
        _wp2 setWaypointSpeed "FULL";
        _wp2 setWaypointBehaviour "COMBAT";
        _group setCombatMode "RED";
        _group setFormation (selectRandom ["WEDGE", "LINE", "ECH LEFT", "ECH RIGHT"]);
        _group setVariable ["DRO2026_reactionUntil", time + 420];
    };
};
