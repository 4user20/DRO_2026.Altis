params [
    ["_group", grpNull, [grpNull]],
    ["_vehicle", objNull, [objNull]],
    ["_launchPositionASL", [], [[]]],
    ["_targetPositionASL", [], [[]]],
    ["_missionType", "STRIKE", [""]],
    ["_loiterRadius", 900, [0]],
    ["_loiterAltitude", 350, [0]]
];
if (!isServer || {isNull _group} || {isNull _vehicle}) exitWith {[]};
if (count _launchPositionASL < 2 || {count _targetPositionASL < 2}) exitWith {[]};
while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
private _launchATL = ASLToAGL _launchPositionASL;
private _targetATL = ASLToAGL _targetPositionASL;
private _distance = _launchATL distance2D _targetATL;
private _bearing = _launchATL getDir _targetATL;
private _route = [];
private _climb = _launchATL getPos [((_distance * 0.12) max 600) min 1600, _bearing + (-8 + random 16)];
_climb set [2, _loiterAltitude max 240];
_route pushBack [_climb, "MOVE", "CARELESS", "BLUE", "FULL", 180];
private _segments = if (_distance > 10000) then {3} else {if (_distance > 5500) then {2} else {1}};
for "_index" from 1 to _segments do {
    private _fraction = _index / (_segments + 1);
    private _segmentDistance = _distance * _fraction;
    private _offset = (sin (_fraction * 180)) * (180 + random 260) * (if (_index mod 2 == 0) then {-1} else {1});
    private _point = _launchATL getPos [_segmentDistance, _bearing];
    _point = _point getPos [abs _offset, _bearing + (if (_offset < 0) then {-90} else {90})];
    _point set [2, _loiterAltitude max 260];
    _route pushBack [_point, "MOVE", "AWARE", "YELLOW", "FULL", 260];
};
private _ingress = _targetATL getPos [((_distance * 0.12) max 900) min 2200, (_bearing + 180) mod 360];
_ingress set [2, (_loiterAltitude * 0.75) max 180];
_route pushBack [_ingress, "MOVE", "COMBAT", "RED", "FULL", 180];
private _mode = toUpperANSI _missionType;
if (_mode in ["RECON", "SEARCH", "LOITER"]) then {
    _route pushBack [_targetATL, "LOITER", "AWARE", "YELLOW", "NORMAL", _loiterRadius max 300];
} else {
    _route pushBack [_targetATL, "DESTROY", "COMBAT", "RED", "FULL", 120];
};
private _waypoints = [];
{
    _x params ["_position", "_type", "_behaviour", "_combat", "_speed", "_radius"];
    private _waypoint = _group addWaypoint [_position, -1];
    _waypoint setWaypointType _type;
    _waypoint setWaypointBehaviour _behaviour;
    _waypoint setWaypointCombatMode _combat;
    _waypoint setWaypointSpeed _speed;
    _waypoint setWaypointCompletionRadius _radius;
    if (_type == "LOITER") then {
        _waypoint setWaypointLoiterType "CIRCLE_L";
        _waypoint setWaypointLoiterRadius (_loiterRadius max 300);
        _waypoint setWaypointLoiterAltitude (_loiterAltitude max 120);
    };
    _waypoints pushBack _waypoint;
} forEach _route;
if (count _waypoints > 0) then {_group setCurrentWaypoint (_waypoints select 0)};
_vehicle flyInHeight (_loiterAltitude max 120);
_waypoints
