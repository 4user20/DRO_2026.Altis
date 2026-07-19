params [["_nodeId", "NODE_FPV_FORWARD_01"]];
if (!isServer) exitWith {false};
private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
if (count _node == 0 || {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"]}) exitWith {false};
private _stocks = _node getOrDefault ["stocks", createHashMap];
if ((_stocks getOrDefault ["FUEL", 0]) < 1) exitWith {false};
private _sites = DRO2026_sites select {
    (_x getOrDefault ["networkNodeId", ""]) == _nodeId || {
        _nodeId == "NODE_FPV_FORWARD_01" && {(_x getOrDefault ["type", ""]) in ["FPV_TEAM", "UAV_TEAM"]}
    }
};
if (count _sites == 0) exitWith {false};
private _site = _sites select 0;
if ((_site getOrDefault ["status", "ACTIVE"]) == "RELOCATING") exitWith {false};
private _team = _site getOrDefault ["team", createHashMap];
private _operator = _site getOrDefault ["operator", _team getOrDefault ["operator", objNull]];
private _group = _team getOrDefault ["group", if (isNull _operator) then {grpNull} else {group _operator}];
if (isNull _operator || {!alive _operator} || {isNull _group}) exitWith {false};

private _current = _site getOrDefault ["position", getPosATL _operator];
private _nearestPlayer = objNull;
private _nearestDistance = 1e10;
private _humanPlayers = allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}};
{
    if (_x distance2D _current < _nearestDistance) then {
        _nearestPlayer = _x;
        _nearestDistance = _x distance2D _current;
    };
} forEach _humanPlayers;
private _escapeBearing = if (isNull _nearestPlayer) then {random 360} else {(_nearestPlayer getDir _current) + (-35 + random 70)};
private _destination = [_current, 650, 1500, _escapeBearing, 55, false, 450] call DRO2026_fnc_findStrategicPosition;
if (_destination isEqualTo [0,0,0]) exitWith {false};

_site set ["status", "RELOCATING"];
_site set ["physicalState", "ACTIVE"];
_node set ["status", "RELOCATING"];
_node set ["emissionState", "RELOCATING"];
_node set ["lastUpdatedAt", time];
DRO2026_networkNodes set [_nodeId, _node];
[_nodeId, "FUEL", -1, "FPV_TEAM_RELOCATION"] call DRO2026_fnc_changeNetworkNodeStock;
["SITE_RELOCATION_STARTED", createHashMapFromArray [["nodeId", _nodeId], ["from", +_current], ["to", +_destination]], _nodeId] call DRO2026_fnc_emitEvent;

private _antenna = _team getOrDefault ["antenna", objNull];
private _tent = _team getOrDefault ["tent", objNull];
if (!isNull _antenna) then {deleteVehicle _antenna};
if (!isNull _tent) then {deleteVehicle _tent};
while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
_group setBehaviourStrong "AWARE";
_group setCombatMode "YELLOW";
_group setSpeedMode "FULL";
private _waypoint = _group addWaypoint [_destination, 20];
_waypoint setWaypointType "MOVE";
_waypoint setWaypointSpeed "FULL";
_waypoint setWaypointCompletionRadius 25;

[_nodeId, _site, _team, _operator, _group, _destination] spawn {
    params ["_nodeId", "_site", "_team", "_operator", "_group", "_destination"];
    private _deadline = time + 240;
    waitUntil {
        sleep 3;
        !alive _operator || {_operator distance2D _destination < 35} || {time > _deadline} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
    if (!alive _operator || {missionNamespace getVariable ["DRO2026_missionEnding", false]}) exitWith {
        _site set ["status", "DISABLED"];
        _node set ["status", "DISABLED"];
        _node set ["emissionState", "OFF"];
        DRO2026_networkNodes set [_nodeId, _node];
    };
    private _actual = getPosATL _operator;
    private _antenna = createVehicle ["Land_SatelliteAntenna_01_F", _actual getPos [7, 80], [], 0, "CAN_COLLIDE"];
    private _tent = createVehicle ["Land_TentDome_F", _actual getPos [8, 240], [], 0, "CAN_COLLIDE"];
    _team set ["antenna", _antenna];
    _team set ["tent", _tent];
    _team set ["position", +_actual];
    _site set ["team", _team];
    _site set ["position", +_actual];
    _site set ["object", _operator];
    _site set ["objects", [_operator, _antenna, _tent]];
    _site set ["status", "ACTIVE"];
    _site set ["physicalState", "ACTIVE"];
    _site set ["lastUpdatedAt", time];
    {_x setVariable ["DRO2026_networkNodeId", _nodeId, true]} forEach [_operator, _antenna, _tent];
    _node set ["position", +_actual];
    _node set ["physicalRefs", [_operator, _antenna, _tent]];
    _node set ["status", "ACTIVE"];
    _node set ["physicalState", "ACTIVE"];
    _node set ["emissionState", "PASSIVE"];
    _node set ["lastUpdatedAt", time];
    DRO2026_networkNodes set [_nodeId, _node];
    ["SITE_RELOCATED", createHashMapFromArray [["nodeId", _nodeId], ["position", +_actual]], _nodeId] call DRO2026_fnc_emitEvent;
};
true