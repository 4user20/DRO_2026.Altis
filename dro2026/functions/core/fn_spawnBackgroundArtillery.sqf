params ["_side"];
if (!isServer) exitWith {objNull};
private _position = ["ENEMY_ARTILLERY"] call DRO2026_fnc_getTheaterNode;
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _fallback = switch (_side) do {
    case west: {"B_MBT_01_arty_F"};
    case resistance: {"I_Truck_02_MRL_F"};
    default {"O_MBT_02_arty_F"};
};
private _class = [format ["ARTILLERY_%1", _suffix], _fallback, _side] call DRO2026_fnc_getSideRoleClass;
if (_class == "") exitWith {objNull};
private _artillery = createVehicle [_class, _position, [], 0, "NONE"];
if (isNull _artillery || {count getArtilleryAmmo [_artillery] == 0}) exitWith {
    if (!isNull _artillery) then {deleteVehicle _artillery};
    objNull
};
if !([_artillery, _side] call DRO2026_fnc_crewManagedVehicle) exitWith {objNull};
private _positions = [_position];
for "_index" from 1 to 2 do {
    private _alternate = [_position, 350, 900, 8, 0, 0.3, 0, [], [_position, _position]] call BIS_fnc_findSafePos;
    if !(_alternate isEqualTo [0,0,0]) then {_positions pushBack _alternate};
};
private _template = ["ARTILLERY_SITE",_position,_side,direction _artillery] call DRO2026_fnc_createSiteComponents;
private _objects = [_artillery] + (_template getOrDefault ["objects",[]]);
private _components = _template getOrDefault ["components",createHashMap];
_components set ["launchers",[_artillery]]; _components set ["crew",crew _artillery];
private _extra = createHashMapFromArray [["positions", _positions], ["side",_side], ["components",_components], ["background", true]];
private _record = ["ARTILLERY_SITE", _position, _artillery, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if ([_record, true] call DRO2026_fnc_validateSiteRecord) then {
    DRO2026_sites pushBack _record;
    [_artillery, _positions, "", ""] spawn DRO2026_fnc_artilleryLoop;
    _artillery
} else {
    private _group = if (isNull (driver _artillery)) then {
        if (isNull (gunner _artillery)) then {grpNull} else {group (gunner _artillery)}
    } else {
        group (driver _artillery)
    };
    deleteVehicleCrew _artillery;
    deleteVehicle _artillery;
    if (!isNull _group) then {deleteGroup _group};
    objNull
}
