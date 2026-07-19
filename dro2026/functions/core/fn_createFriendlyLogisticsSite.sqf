if (!isServer) exitWith {createHashMap};
if ((DRO2026_sites findIf {(_x getOrDefault ["type", ""]) == "FRIENDLY_LOGISTICS"}) >= 0) exitWith {createHashMap};

private _position = ["FRIENDLY_LOGISTICS"] call DRO2026_fnc_getTheaterNode;
private _pool = DRO2026_assetRegistry getOrDefault ["PLAYER_LOGISTICS", []];
_pool = _pool select {
    isClass (configFile >> "CfgVehicles" >> _x) &&
    {(_x isKindOf "Car") || {_x isKindOf "Truck_F"}} &&
    {!(_x isKindOf "Tank")}
};
private _fallback = switch (playersSide) do {
    case west: {"B_Truck_01_transport_F"};
    case resistance: {"I_Truck_02_transport_F"};
    default {"O_Truck_03_transport_F"};
};
if (count _pool == 0 && {isClass (configFile >> "CfgVehicles" >> _fallback)}) then {_pool = [_fallback]};
if (count _pool == 0) exitWith {createHashMap};

private _classes = [];
_classes pushBack (_pool select 0);
private _fuelIndex = _pool findIf {
    private _name = toLowerANSI _x;
    (_name find "fuel") >= 0 || {(_name find "atz") >= 0} || {(_name find "refuel") >= 0} || {(_name find "ac55") >= 0}
};
if (_fuelIndex >= 0) then {_classes pushBackUnique (_pool select _fuelIndex)};
private _objects = [];
{
    private _vehiclePos = _position getPos [10 + (_forEachIndex * 16), 45 + (_forEachIndex * 115)];
    private _vehicle = createVehicle [_x, _vehiclePos, [], 0, "NONE"];
    if (!isNull _vehicle) then {
        _vehicle setDir (random 360);
        _vehicle enableDynamicSimulation true;
        DRO2026_managedVehicles pushBackUnique _vehicle;
        _objects pushBack _vehicle;
    };
} forEach _classes;
if (count _objects == 0) exitWith {createHashMap};

private _cargo = createVehicle ["Land_Pallet_MilBoxes_F", _position getPos [8, 220], [], 0, "CAN_COLLIDE"];
private _tent = createVehicle ["Land_TentA_F", _position getPos [14, 300], [], 0, "CAN_COLLIDE"];
if (!isNull _cargo) then {_objects pushBack _cargo};
if (!isNull _tent) then {_objects pushBack _tent};
private _guardClasses = if (!isNil "pInfClasses" && {count pInfClasses > 0}) then {pInfClasses} else {
    switch (playersSide) do {case west: {["B_Soldier_F"]}; case resistance: {["I_Soldier_F"]}; default {["O_Soldier_F"]}}
};
private _group = createGroup [playersSide, true];
for "_index" from 0 to 1 do {
    private _class = selectRandom _guardClasses;
    private _unit = _group createUnit [_class, _position getPos [8 + random 10, random 360], [], 2, "FORM"];
    if (!isNull _unit) then {_unit setSkill 0.45};
};
if (count units _group > 0) then {
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", true];
    _group setBehaviourStrong "SAFE";
    [_group, _position, 55] call BIS_fnc_taskDefend;
};
private _extra = createHashMapFromArray [["group", _group], ["background", true], ["cargoType", "MIXED_SUPPLY"]];
private _record = ["FRIENDLY_LOGISTICS", _position, _objects select 0, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if ([_record, true] call DRO2026_fnc_validateSiteRecord) then {
    DRO2026_sites pushBack _record;
    ["FRIENDLY_SITE_CREATED", createHashMapFromArray [["siteId", _record get "id"], ["type", "FRIENDLY_LOGISTICS"]], _record get "id"] call DRO2026_fnc_emitEvent;
};
_record
