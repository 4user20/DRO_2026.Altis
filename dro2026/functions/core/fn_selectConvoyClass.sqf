params [
    ["_registryRole","",[""]],
    ["_side",east,[east]],
    ["_cargoType","GENERAL",[""]],
    ["_fallback","",[""]],
    ["_purpose","CARGO",[""]],
    ["_stream","CONVOY_CLASS",[""]]
];
if (_registryRole == "") exitWith {_fallback};
private _pool = +(DRO2026_assetRegistry getOrDefault [_registryRole,[]]);
private _blocked = missionNamespace getVariable ["DRO2026_runtimeBlockedVehicleClasses",[]];
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
private _allowedCargoRoles = ["TRANSPORT_CARGO","TRANSPORT_PERSONNEL","LOGISTICS_GENERAL","LOGISTICS_AMMO","LOGISTICS_FUEL","LOGISTICS_REPAIR","APC","IFV"];
private _allowedEscortRoles = ["RECON","APC","IFV","TRANSPORT_PERSONNEL"];
private _purposeUpper = toUpperANSI _purpose;
_pool = _pool select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    private _role = [_x] call DRO2026_fnc_getAssetPrimaryRole;
    isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {!(_x in _blocked)} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}} &&
    {if (_purposeUpper == "ESCORT") then {_role in _allowedEscortRoles} else {_role in _allowedCargoRoles}}
};
private _vanilla = [
    "O_Truck_03_transport_F","O_Truck_03_ammo_F","O_Truck_03_fuel_F","O_Truck_03_repair_F","O_MRAP_02_hmg_F",
    "B_Truck_01_transport_F","B_Truck_01_ammo_F","B_Truck_01_fuel_F","B_Truck_01_Repair_F","B_MRAP_01_hmg_F",
    "I_Truck_02_transport_F","I_Truck_02_ammo_F","I_Truck_02_fuel_F","I_Truck_02_box_F","I_MRAP_03_hmg_F"
];
private _specialized = [];
private _specializedModded = [];
private _modded = [];
private _generic = [];
{
    private _lower = toLowerANSI _x;
    private _matchesCargo = switch (toUpperANSI _cargoType) do {
        case "FUEL": {(_lower find "fuel") >= 0 || {(_lower find "atz") >= 0} || {(_lower find "ac55") >= 0} || {(_lower find "refuel") >= 0}};
        case "ARTILLERY_AMMO";
        case "AA_MISSILES";
        case "FPV_KITS";
        case "LONG_RANGE_DRONES": {(_lower find "ammo") >= 0 || {(_lower find "munition") >= 0} || {(_lower find "kamaz") >= 0} || {(_lower find "ural") >= 0} || {(_lower find "typhoon") >= 0}};
        default {false};
    };
    if (_matchesCargo) then {
        _specialized pushBack _x;
        if !(_x in _vanilla) then {_specializedModded pushBack _x};
    };
    if !(_x in _vanilla) then {_modded pushBack _x};
    _generic pushBack _x;
} forEach _pool;
private _candidates = if (count _specializedModded > 0) then {_specializedModded} else {if (count _specialized > 0) then {_specialized} else {if (count _modded > 0) then {_modded} else {_generic}}};
private _selected = _fallback;
if (count _candidates > 0) then {
    private _index = floor ([count _candidates,_stream,0] call DRO2026_fnc_seededRandom);
    _selected = _candidates select (_index min ((count _candidates) - 1));
};
if (_selected == "" || {!isClass (configFile >> "CfgVehicles" >> _selected)} || {_selected in _blocked}) then {
    _selected = if (_fallback != "" && {isClass (configFile >> "CfgVehicles" >> _fallback)} && {!(_fallback in _blocked)}) then {_fallback} else {""};
};
["ROLE","CONVOY_CLASS_SELECTED",createHashMapFromArray [
    ["registryRole",_registryRole],["purpose",_purposeUpper],["cargoType",_cargoType],
    ["selected",_selected],["poolCount",count _pool],["specializedCount",count _specialized],
    ["specializedModdedCount",count _specializedModded],["moddedCount",count _modded],["vanillaFallback",_selected in _vanilla]
],_stream] call DRO2026_fnc_logStructured;
_selected
