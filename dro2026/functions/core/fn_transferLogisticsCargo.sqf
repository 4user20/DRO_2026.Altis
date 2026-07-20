params [["_cargoType","MIXED",[""]],["_amount",0,[0]],["_sourceVehicle",objNull,[objNull]],["_destinationNodeId","",[""]]];
if (!isServer || {_amount <= 0} || {_destinationNodeId == ""}) exitWith {createHashMapFromArray [["ok",false],["code","INVALID_TRANSFER"]]};
private _node = DRO2026_networkNodes getOrDefault [_destinationNodeId,createHashMap];
if (count _node == 0) exitWith {createHashMapFromArray [["ok",false],["code","DESTINATION_NOT_FOUND"]]};
private _destinationObjects = (_node getOrDefault ["physicalRefs",[]]) select {!isNull _x && {alive _x}};
private _type = toUpperANSI _cargoType; private _updated = 0;
if (!isNull _sourceVehicle) then {
    switch true do {
        case (_type in ["ARTILLERY_AMMO","AA_MISSILES","FPV_KITS","LONG_RANGE_DRONES"]): {if (getAmmoCargo _sourceVehicle >= 0) then {_sourceVehicle setAmmoCargo 0}};
        case (_type == "FUEL"): {if (getFuelCargo _sourceVehicle >= 0) then {_sourceVehicle setFuelCargo 0}};
        case (_type in ["REPAIR","RADAR_PARTS"]): {if (getRepairCargo _sourceVehicle >= 0) then {_sourceVehicle setRepairCargo 0}};
    };
};
{
    private _vehicle = _x;
    switch true do {
        case (_type in ["ARTILLERY_AMMO","AA_MISSILES"]): {if (local _vehicle && {(_vehicle turretLocal [-1]) || {(allTurrets _vehicle findIf {_vehicle turretLocal _x}) >= 0}}) then {_vehicle setVehicleAmmoDef 1; _updated = _updated + 1}};
        case (_type == "FUEL"): {if (local _vehicle) then {_vehicle setFuel 1; _updated = _updated + 1}};
        case (_type in ["REPAIR","RADAR_PARTS"]): {if (local _vehicle && {damage _vehicle > 0}) then {_vehicle setDamage ((damage _vehicle - 0.35) max 0); _updated = _updated + 1}};
    };
} forEach _destinationObjects;
createHashMapFromArray [["ok",true],["code","TRANSFERRED"],["updatedObjects",_updated],["destinationNodeId",_destinationNodeId],["cargoType",_type],["amount",_amount]]
