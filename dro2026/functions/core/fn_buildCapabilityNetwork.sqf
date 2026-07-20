if (!isServer) exitWith {DRO2026_networkNodes};
if (missionNamespace getVariable ["DRO2026_networkBuilt", false]) exitWith {DRO2026_networkNodes};
if !(missionNamespace getVariable ["DRO2026_theaterBuilt", false]) exitWith {DRO2026_networkNodes};

private _position = {
    params ["_key"];
    +(DRO2026_theaterLayout getOrDefault [_key, DRO2026_theaterNodes getOrDefault [_key, [0,0,0]]])
};
private _map = {createHashMapFromArray _this};

[
    "NODE_ENEMY_HQ", "HQ", enemySide, ["ENEMY_HQ"] call _position,
    [["command", 1], ["comms", 1]] call _map,
    [["FUEL", 40], ["INFANTRY_REPLACEMENTS", 36], ["MEDICAL", 18]] call _map,
    ["COMMAND", "REINFORCE", "ROUTE_CONTROL"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_LOGISTICS_01", "LOGISTICS_HUB", enemySide, ["ENEMY_LOGISTICS"] call _position,
    [["warehouse", 1], ["fuelDepot", 1], ["dispatcher", 1]] call _map,
    [["ARTILLERY_AMMO", 28], ["FPV_KITS", 14], ["LONG_RANGE_DRONES", 8], ["FUEL", 36], ["EW_BATTERIES", 12], ["AA_MISSILES", 12], ["RADAR_PARTS", 4]] call _map,
    ["SUPPLY_SOURCE", "DELIVERY_DISPATCH"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_ARTILLERY_01", "ARTILLERY_SITE", enemySide, ["ENEMY_ARTILLERY"] call _position,
    [["gun", 1], ["fireControl", 1], ["mobility", 1]] call _map,
    [["ARTILLERY_AMMO", 18], ["FUEL", 10]] call _map,
    ["ARTILLERY_FIRE", "SHOOT_AND_SCOOT"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_FPV_FORWARD_01", "FPV_TEAM", enemySide, ["ENEMY_DRONE_FORWARD"] call _position,
    [["operator", 1], ["antenna", 1], ["generator", 1]] call _map,
    [["FPV_KITS", 8], ["BATTERIES", 10], ["FUEL", 4]] call _map,
    ["FPV_ATTACK", "MICRO_ISR", "RELOCATE"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_DRONE_REAR_01", "STRATEGIC_DRONE_SITE", enemySide, ["ENEMY_DRONE_REAR"] call _position,
    [["operator", 1], ["launcher", 1], ["antenna", 1]] call _map,
    [["LONG_RANGE_DRONES", 7], ["FUEL", 12], ["BATTERIES", 8]] call _map,
    ["LONG_RANGE_ATTACK", "TACTICAL_ISR"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_EW_01", "EW_SITE", enemySide, ["ENEMY_EW"] call _position,
    [["jammer", 1], ["antenna", 1], ["generator", 1]] call _map,
    [["EW_BATTERIES", 10], ["FUEL", 10]] call _map,
    ["JAMMING", "ELINT", "EMISSION_CONTROL"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_AA_LONG_01", "AA_LONG", enemySide, ["ENEMY_AA_LONG"] call _position,
    [["radar", 1], ["launcher", 1], ["commandLink", 1]] call _map,
    [["AA_MISSILES", 8], ["RADAR_PARTS", 2], ["FUEL", 8]] call _map,
    ["LONG_RANGE_AA", "RADAR_TRACK"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_AA_SHORAD_01", "AA_SHORAD", enemySide, ["ENEMY_AA_SHORAD"] call _position,
    [["launcher", 1], ["localSensor", 1]] call _map,
    [["AA_MISSILES", 6], ["FUEL", 6]] call _map,
    ["SHORAD", "POINT_DEFENCE"]
] call DRO2026_fnc_createNetworkNode;


[
    "NODE_FRIENDLY_HQ", "HQ", playersSide, ["FRIENDLY_HQ"] call _position,
    [["command", 1], ["comms", 1]] call _map,
    [["FUEL", 24], ["MEDICAL", 12]] call _map,
    ["COMMAND", "ROUTE_CONTROL"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_FRIENDLY_LOGISTICS", "LOGISTICS_HUB", playersSide, ["FRIENDLY_LOGISTICS"] call _position,
    [["warehouse", 1], ["fuelDepot", 1], ["dispatcher", 1]] call _map,
    [["ARTILLERY_AMMO", 18], ["FPV_KITS", 12], ["LONG_RANGE_DRONES", 8], ["FUEL", 28], ["AA_MISSILES", 10], ["RADAR_PARTS", 3]] call _map,
    ["SUPPLY_SOURCE", "DELIVERY_DISPATCH"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_FRIENDLY_FPV", "FPV_TEAM", playersSide, ["FRIENDLY_DRONE_FORWARD"] call _position,
    [["operator", 1], ["antenna", 1], ["generator", 1]] call _map,
    [["FPV_KITS", 8], ["BATTERIES", 8], ["FUEL", 4]] call _map,
    ["FPV_ATTACK", "MICRO_ISR", "RELOCATE"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_FRIENDLY_DRONES", "STRATEGIC_DRONE_SITE", playersSide, ["FRIENDLY_DRONE_REAR"] call _position,
    [["operator", 1], ["launcher", 1], ["antenna", 1]] call _map,
    [["LONG_RANGE_DRONES", 6], ["FUEL", 10], ["BATTERIES", 6]] call _map,
    ["LONG_RANGE_ATTACK", "TACTICAL_ISR"]
] call DRO2026_fnc_createNetworkNode;
[
    "NODE_FRIENDLY_AA_LONG", "AA_LONG", playersSide, ["FRIENDLY_AA_LONG"] call _position,
    [["radar", 1], ["launcher", 1], ["commandLink", 1]] call _map,
    [["AA_MISSILES", 8], ["RADAR_PARTS", 2], ["FUEL", 8]] call _map,
    ["LONG_RANGE_AA", "RADAR_TRACK", "INTERCEPT"]
] call DRO2026_fnc_createNetworkNode;

private _edge = {
    params ["_id", "_from", "_to", "_cargo", "_capacity", "_travel"];
    private _fromNode = DRO2026_networkNodes get _from;
    private _toNode = DRO2026_networkNodes get _to;
    [_id, _from, _to, _cargo, _capacity, _travel, [+(_fromNode get "position"), +(_toNode get "position")]] call DRO2026_fnc_createNetworkEdge
};
["EDGE_HQ_LOGISTICS", "NODE_ENEMY_HQ", "NODE_LOGISTICS_01", ["FUEL", "INFANTRY_REPLACEMENTS", "MEDICAL"], 14, 540] call _edge;
["EDGE_LOGISTICS_ARTILLERY", "NODE_LOGISTICS_01", "NODE_ARTILLERY_01", ["ARTILLERY_AMMO", "FUEL"], 12, 620] call _edge;
["EDGE_LOGISTICS_FPV", "NODE_LOGISTICS_01", "NODE_FPV_FORWARD_01", ["FPV_KITS", "BATTERIES", "FUEL"], 8, 480] call _edge;
["EDGE_LOGISTICS_DRONES", "NODE_LOGISTICS_01", "NODE_DRONE_REAR_01", ["LONG_RANGE_DRONES", "BATTERIES", "FUEL"], 7, 720] call _edge;
["EDGE_LOGISTICS_EW", "NODE_LOGISTICS_01", "NODE_EW_01", ["EW_BATTERIES", "FUEL"], 6, 600] call _edge;
["EDGE_LOGISTICS_AA_LONG", "NODE_LOGISTICS_01", "NODE_AA_LONG_01", ["AA_MISSILES", "RADAR_PARTS", "FUEL"], 6, 760] call _edge;
["EDGE_LOGISTICS_SHORAD", "NODE_LOGISTICS_01", "NODE_AA_SHORAD_01", ["AA_MISSILES", "FUEL"], 5, 560] call _edge;


["EDGE_FRIENDLY_HQ_LOGISTICS", "NODE_FRIENDLY_HQ", "NODE_FRIENDLY_LOGISTICS", ["FUEL", "MEDICAL"], 10, 420] call _edge;
["EDGE_FRIENDLY_LOGISTICS_FPV", "NODE_FRIENDLY_LOGISTICS", "NODE_FRIENDLY_FPV", ["FPV_KITS", "BATTERIES", "FUEL"], 7, 420] call _edge;
["EDGE_FRIENDLY_LOGISTICS_DRONES", "NODE_FRIENDLY_LOGISTICS", "NODE_FRIENDLY_DRONES", ["LONG_RANGE_DRONES", "BATTERIES", "FUEL"], 6, 650] call _edge;
["EDGE_FRIENDLY_LOGISTICS_AA", "NODE_FRIENDLY_LOGISTICS", "NODE_FRIENDLY_AA_LONG", ["AA_MISSILES", "RADAR_PARTS", "FUEL"], 5, 650] call _edge;

missionNamespace setVariable ["DRO2026_networkBuilt", true];
[] call DRO2026_fnc_applyReserveMultiplier;
["NETWORK_BUILT", createHashMapFromArray [["nodes", count DRO2026_networkNodes], ["edges", count DRO2026_networkEdges]], "SYSTEM"] call DRO2026_fnc_emitEvent;
[format ["Capability network создан: узлов %1, рёбер %2", count DRO2026_networkNodes, count DRO2026_networkEdges]] call DRO2026_fnc_log;
DRO2026_networkNodes