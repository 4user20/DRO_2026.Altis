params [["_type", "FPV_SITE", [""]], ["_position", [], [[]]], ["_side", east, [east]], ["_direction", 0, [0]]];
if (!isServer || {count _position < 2}) exitWith {createHashMap};
private _objects = [];
private _components = createHashMapFromArray [["crew",[]],["guards",[]],["launchers",[]],["antennas",[]],["terminals",[]],["generators",[]],["stocks",[]],["transports",[]],["camouflage",[]],["staticProps",[]]];
private _spawn = {
    params ["_class","_distance","_bearing","_category",["_dirOffset",0]];
    if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {objNull};
    private _desired = _position getPos [_distance,_direction + _bearing];
    private _object = createVehicle [_class,_desired,[],0,"NONE"];
    if (isNull _object) exitWith {objNull};
    _object setDir (_direction + _dirOffset);
    _object setVehiclePosition [_desired,[],0,"NONE"];
    _object enableDynamicSimulation true;
    _object setVariable ["DRO2026_siteComponent",_category,true];
    _objects pushBack _object;
    private _list = _components getOrDefault [_category,[]]; _list pushBack _object; _components set [_category,_list];
    _object
};
private _typeKey = toUpperANSI _type;
switch true do {
    case ((_typeKey find "LOGISTICS") >= 0 || {(_typeKey find "WAREHOUSE") >= 0} || {(_typeKey find "DEPOT") >= 0}): {
        ["Land_Cargo20_military_green_F",18,25,"stocks",90] call _spawn;
        ["Land_Cargo20_military_green_F",20,335,"stocks",90] call _spawn;
        ["Land_Cargo10_military_green_F",29,5,"stocks",90] call _spawn;
        ["Land_Pallet_MilBoxes_F",10,300,"stocks"] call _spawn;
        ["Land_Pallets_stack_F",13,245,"stocks"] call _spawn;
        ["Land_dp_transformer_F",24,190,"generators"] call _spawn;
        ["Land_Pod_Heli_Transport_04_repair_F",30,150,"staticProps"] call _spawn;
        ["Land_DataTerminal_01_F",8,55,"terminals"] call _spawn;
        ["Land_SatelliteAntenna_01_F",22,75,"antennas"] call _spawn;
        ["CamoNet_OPFOR_big_F",0,0,"camouflage"] call _spawn;
    };
    case ((_typeKey find "BALLISTIC") >= 0 || {(_typeKey find "ISKANDER") >= 0}): {
        ["Land_DataTerminal_01_F",7,20,"terminals"] call _spawn;
        ["Land_SatelliteAntenna_01_F",18,60,"antennas"] call _spawn;
        ["Land_PortableGenerator_01_F",14,210,"generators"] call _spawn;
        ["Land_Cargo10_military_green_F",24,260,"stocks",90] call _spawn;
        ["Land_Pallet_MilBoxes_F",13,305,"stocks"] call _spawn;
        ["CamoNet_OPFOR_big_F",0,0,"camouflage"] call _spawn;
        ["Land_TentA_F",18,225,"staticProps"] call _spawn;
    };
    case ((_typeKey find "FARP") >= 0): {
        ["Land_HelipadSquare_F",0,0,"staticProps"] call _spawn;
        ["Land_Pod_Heli_Transport_04_fuel_F",28,150,"stocks"] call _spawn;
        ["Land_Pod_Heli_Transport_04_repair_F",30,210,"staticProps"] call _spawn;
        ["Land_Pallet_MilBoxes_F",20,270,"stocks"] call _spawn;
        ["Land_PortableGenerator_01_F",18,235,"generators"] call _spawn;
        ["Land_DataTerminal_01_F",13,40,"terminals"] call _spawn;
        ["Land_TentDome_F",24,315,"staticProps"] call _spawn;
        ["CamoNet_OPFOR_open_F",12,330,"camouflage"] call _spawn;
    };
    case ((_typeKey find "FPV") >= 0): {
        ["Land_SatelliteAntenna_01_F",9,35,"antennas"] call _spawn; ["Land_Laptop_unfolded_F",4,5,"terminals"] call _spawn;
        ["Land_PortableGenerator_01_F",11,210,"generators"] call _spawn; ["Land_Pallet_MilBoxes_F",8,285,"stocks"] call _spawn;
        ["Land_PlasticCase_01_large_F",5,320,"stocks"] call _spawn; ["CamoNet_OPFOR_open_F",0,0,"camouflage"] call _spawn;
        ["Land_TentDome_F",12,245,"staticProps"] call _spawn;
    };
    case ((_typeKey find "DRONE") >= 0 || {(_typeKey find "UAV") >= 0}): {
        ["Land_SatelliteAntenna_01_F",14,40,"antennas"] call _spawn; ["Land_DataTerminal_01_F",5,10,"terminals"] call _spawn;
        ["Land_PortableGenerator_01_F",12,200,"generators"] call _spawn; ["Land_Pallet_MilBoxes_F",11,285,"stocks"] call _spawn;
        ["Land_Cargo20_military_green_F",22,260,"stocks"] call _spawn; ["CamoNet_OPFOR_big_F",0,0,"camouflage"] call _spawn;
    };
    case ((_typeKey find "HQ") >= 0): {
        ["Land_DataTerminal_01_F",5,20,"terminals"] call _spawn; ["Land_SatelliteAntenna_01_F",14,70,"antennas"] call _spawn;
        ["Land_PortableGenerator_01_F",15,215,"generators"] call _spawn; ["Land_Pallet_MilBoxes_F",16,285,"stocks"] call _spawn;
        ["Land_BagBunker_Tower_F",24,40,"staticProps"] call _spawn; ["Land_TentA_F",17,225,"staticProps"] call _spawn;
    };
    case ((_typeKey find "AA") >= 0 || {(_typeKey find "AIR_DEFENCE") >= 0}): {
        ["Land_Radar_Small_F",18,55,"antennas"] call _spawn; ["Land_DataTerminal_01_F",7,15,"terminals"] call _spawn;
        ["Land_PortableGenerator_01_F",15,205,"generators"] call _spawn; ["Land_Pallet_MilBoxes_F",13,285,"stocks"] call _spawn;
        ["Land_BagFence_Long_F",20,110,"staticProps"] call _spawn;
    };
    case ((_typeKey find "ARTILLERY") >= 0): {
        ["Land_DataTerminal_01_F",8,25,"terminals"] call _spawn; ["Land_SatelliteAntenna_01_F",15,65,"antennas"] call _spawn;
        ["Land_PortableGenerator_01_F",14,210,"generators"] call _spawn; ["Land_Pallet_MilBoxes_F",12,285,"stocks"] call _spawn;
        ["Land_Cargo20_military_green_F",24,250,"stocks"] call _spawn;
    };
    default {["Land_Pallet_MilBoxes_F",8,270,"stocks"] call _spawn; ["Land_PortableGenerator_01_F",10,200,"generators"] call _spawn; ["Land_SatelliteAntenna_01_F",12,45,"antennas"] call _spawn};
};
createHashMapFromArray [["objects",_objects],["components",_components],["state","DEPLOYED"]]