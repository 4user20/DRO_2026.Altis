params [
    ["_registryRole","",[""]],
    ["_side",east,[east]],
    ["_cargoType","GENERAL",[""]],
    ["_fallback","",[""]],
    ["_purpose","CARGO",[""]],
    ["_stream","CONVOY_CLASS",[""]]
];
private _blocked = missionNamespace getVariable ["DRO2026_runtimeBlockedVehicleClasses",[]];
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
private _allowedCargoRoles = ["TRANSPORT_CARGO","TRANSPORT_PERSONNEL","LOGISTICS_GENERAL","LOGISTICS_AMMO","LOGISTICS_FUEL","LOGISTICS_REPAIR","APC","IFV"];
private _allowedEscortRoles = ["RECON","APC","IFV","TRANSPORT_PERSONNEL","SHORAD"];
private _purposeUpper = toUpperANSI _purpose;
private _cargoUpper = toUpperANSI _cargoType;
private _isValid = {
    params ["_class"];
    if (_class == "" || {_class in _blocked}) exitWith {false};
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1} || {getNumber (_cfg >> "isBackpack") > 0} || {getText (_cfg >> "model") == ""}) exitWith {false};
    if (_sideNumber >= 0 && {getNumber (_cfg >> "side") != _sideNumber}) exitWith {false};
    private _role = [_class] call DRO2026_fnc_getAssetPrimaryRole;
    if (_purposeUpper == "ESCORT") then {_role in _allowedEscortRoles} else {_role in _allowedCargoRoles}
};
private _pool = if (_registryRole == "") then {[]} else {+(DRO2026_assetRegistry getOrDefault [_registryRole,[]])};
_pool = _pool select {[_x] call _isValid};
private _vanilla = [
    "O_Truck_03_transport_F","O_Truck_03_ammo_F","O_Truck_03_fuel_F","O_Truck_03_repair_F","O_MRAP_02_hmg_F",
    "B_Truck_01_transport_F","B_Truck_01_ammo_F","B_Truck_01_fuel_F","B_Truck_01_Repair_F","B_MRAP_01_hmg_F",
    "I_Truck_02_transport_F","I_Truck_02_ammo_F","I_Truck_02_fuel_F","I_Truck_02_box_F","I_MRAP_03_hmg_F"
];
private _specialized = [];
private _specializedModded = [];
private _modded = [];
{
    private _class = _x;
    private _lower = toLowerANSI _class;
    private _role = [_class] call DRO2026_fnc_getAssetPrimaryRole;
    private _matchesCargo = switch _cargoUpper do {
        case "FUEL": {_role == "LOGISTICS_FUEL" || {(_lower find "fuel") >= 0} || {(_lower find "atz") >= 0} || {(_lower find "ac55") >= 0} || {(_lower find "refuel") >= 0}};
        case "ARTILLERY_AMMO";
        case "AA_MISSILES";
        case "FPV_KITS";
        case "LONG_RANGE_DRONES": {_role == "LOGISTICS_AMMO" || {(_lower find "ammo") >= 0} || {(_lower find "munition") >= 0} || {(_lower find "kamaz") >= 0} || {(_lower find "ural") >= 0} || {(_lower find "typhoon") >= 0}};
        case "RADAR_PARTS";
        case "EW_BATTERIES";
        case "BATTERIES";
        case "MEDICAL";
        case "INFANTRY_REPLACEMENTS": {_role in ["LOGISTICS_GENERAL","TRANSPORT_CARGO","TRANSPORT_PERSONNEL"]};
        default {false};
    };
    if (_matchesCargo) then {
        _specialized pushBack _class;
        if !(_class in _vanilla) then {_specializedModded pushBack _class};
    };
    if !(_class in _vanilla) then {_modded pushBack _class};
} forEach _pool;
private _candidates = if (count _specializedModded > 0) then {_specializedModded} else {
    if (count _specialized > 0) then {_specialized} else {
        if (count _modded > 0) then {_modded} else {_pool}
    }
};
private _selected = "";
if (count _candidates > 0) then {
    private _index = floor ([count _candidates,_stream,0] call DRO2026_fnc_seededRandom);
    _selected = _candidates select (_index min ((count _candidates) - 1));
};
if (_selected == "" && {[_fallback] call _isValid}) then {_selected = _fallback};
["ROLE","CONVOY_CLASS_SELECTED",createHashMapFromArray [
    ["registryRole",_registryRole],["purpose",_purposeUpper],["cargoType",_cargoUpper],
    ["selected",_selected],["selectedRole",if (_selected == "") then {""} else {[_selected] call DRO2026_fnc_getAssetPrimaryRole}],
    ["poolCount",count _pool],["specializedCount",count _specialized],
    ["specializedModdedCount",count _specializedModded],["moddedCount",count _modded],
    ["vanillaFallback",_selected in _vanilla],["fallbackAccepted",_selected == _fallback && {_selected != ""}]
],_stream] call DRO2026_fnc_logStructured;
_selected
