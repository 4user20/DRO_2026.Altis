if (!isServer) exitWith {createHashMap};
if (missionNamespace getVariable ["DRO2026_droneRegistryInitialized", false]) exitWith {DRO2026_droneRegistry};

DRO2026_droneRegistry = createHashMap;
DRO2026_droneClassMetadata = createHashMap;

// Optional KVN inheritance roots are recorded when the mod exposes them.
{
    if (isClass (configFile >> "CfgVehicles" >> _x)) then {
        DRO2026_droneClassMetadata set [_x, createHashMapFromArray [
            ["class", _x], ["category", "FIBER_BASE"], ["side", "ANY"],
            ["carrier", "VEHICLE"], ["assembleTo", ""], ["fiberOptic", true],
            ["thermal", false], ["range", "DEFAULT"]
        ]];
    };
} forEach ["frtz_drone_kvn_base_F", "frtz_KVN_Base"];

private _carrierKind = {
    params ["_class"];
    private _vehicleCfg = configFile >> "CfgVehicles" >> _class;
    if (isClass _vehicleCfg) then {
        if (getNumber (_vehicleCfg >> "isBackpack") == 1) exitWith {"BACKPACK"};
        if (_class isKindOf "Air") exitWith {"VEHICLE"};
    };
    if (isClass (configFile >> "CfgWeapons" >> _class)) exitWith {"ITEM"};
    if (isClass (configFile >> "CfgMagazines" >> _class)) exitWith {"MAGAZINE"};
    ""
};

private _registerClass = {
    params ["_class", "_category", "_sideKey", ["_fiber", false], ["_ti", false], ["_range", "DEFAULT"]];
    private _kind = [_class] call _carrierKind;
    if (_kind == "") exitWith {false};
    private _assembled = "";
    if (_kind == "BACKPACK") then {
        private _assembleTo = configFile >> "CfgVehicles" >> _class >> "assembleInfo" >> "assembleTo";
        if (isText _assembleTo) then {_assembled = getText _assembleTo};
    };
    private _descriptor = createHashMapFromArray [
        ["class", _class], ["category", _category], ["side", _sideKey],
        ["carrier", _kind], ["assembleTo", _assembled], ["fiberOptic", _fiber],
        ["thermal", _ti], ["range", _range]
    ];
    private _key = format ["%1_%2", _category, _sideKey];
    private _entries = DRO2026_droneRegistry getOrDefault [_key, []];
    _entries pushBack _descriptor;
    DRO2026_droneRegistry set [_key, _entries];
    DRO2026_droneClassMetadata set [_class, _descriptor];
    if (_assembled != "") then {DRO2026_droneClassMetadata set [_assembled, _descriptor]};
    true
};

private _sideSpecs = [["B", "WEST"], ["O", "EAST"], ["I", "GUER"]];
{
    _x params ["_letter", "_sideKey"];
    {
        _x params ["_payload", "_category", "_ti"];
        {
            private _suffix = _x;
            private _range = switch (_suffix) do {case "_20KM": {"LONG"}; case "_25KM": {"EXTREME"}; default {"DEFAULT"}};
            private _vehicle = format ["frtz_%1_KVN_%2%3", _letter, _payload, _suffix];
            private _bag = _vehicle + "_Bag";
            [_bag, _category, _sideKey, true, _ti, _range] call _registerClass;
            [_vehicle, _category, _sideKey, true, _ti, _range] call _registerClass;
        } forEach ["_25KM", "_20KM", ""];
    } forEach [["AP_TI", "FPV_AP_TI", true], ["AT_TI", "FPV_AT_TI", true], ["AP", "FPV_AP", false], ["AT", "FPV_AT", false]];
} forEach _sideSpecs;

{
    _x params ["_payload", "_category", "_ti"];
    {
        private _suffix = _x;
        private _range = switch (_suffix) do {case "_20KM": {"LONG"}; case "_25KM": {"EXTREME"}; default {"DEFAULT"}};
        [format ["frtz_Item_KVN_%1%2", _payload, _suffix], _category, "ANY", true, _ti, _range] call _registerClass;
    } forEach ["_25KM", "_20KM", ""];
} forEach [["AP_TI", "FPV_AP_TI", true], ["AT_TI", "FPV_AT_TI", true], ["AP", "FPV_AP", false], ["AT", "FPV_AT", false]];

private _sideGeneric = {
    params ["_letter", "_sideKey"];
    private _recon = switch (_sideKey) do {
        case "WEST": {["B_UAV_01_backpack_F", "B_UAV_06_backpack_F", "B_UAV_02_lxWS", "Mavic_3T_BLU", "mavik_3T_BLU"]};
        case "GUER": {["I_UAV_01_backpack_F", "I_UAV_06_backpack_F", "I_UAV_02_lxWS", "Mavic_3T_IND", "mavik_3T_IND"]};
        default {["O_UAV_01_backpack_F", "O_UAV_06_backpack_F", "O_UAV_02_lxWS", "Mavic_3T_OPF", "mavik_3T_OPF"]};
    };
    private _ap = [
        format ["%1_UAFPV_RKG_AP_Bag", _letter], format ["%1_UAFPV_OG7V_AP_Bag", _letter],
        format ["%1_UAFPV_IED_AP_Bag", _letter], format ["%1_UAFPV_RKG_Bag", _letter],
        format ["%1_UAFPV_AP_Bag", _letter], format ["%1_Crocus_AP_TI_Bag", _letter],
        format ["%1_Crocus_AP_Bag", _letter], format ["%1_KVN_AP_TI_Bag", _letter],
        format ["%1_KVN_AP_Bag", _letter]
    ];
    private _at = [
        format ["%1_UAFPV_PG7VL_AT_Bag", _letter], format ["%1_UAFPV_AT_Bag", _letter],
        format ["%1_Crocus_AT_TI_Bag", _letter], format ["%1_Crocus_AT_Bag", _letter],
        format ["%1_KVN_AT_TI_Bag", _letter], format ["%1_KVN_AT_Bag", _letter]
    ];
    private _bomber = switch (_sideKey) do {
        case "WEST": {["B_G_UAV_02_IED_lxWS", "B_Tura_UAV_02_IED_lxWS", "DRA_UAV_01G_B", "Mavic_3_BLU", "mavik_3_BLU"]};
        case "GUER": {["I_G_UAV_02_IED_lxWS", "I_Tura_UAV_02_IED_lxWS", "DRA_UAV_01G_I", "Mavic_3_IND", "mavik_3_IND"]};
        default {["O_G_UAV_02_IED_lxWS", "O_Tura_UAV_02_IED_lxWS", "DRA_UAV_01G_O", "Mavic_3_OPF", "mavik_3_OPF"]};
    };
    {[_x, "RECON", _sideKey, false, false, "DEFAULT"] call _registerClass} forEach _recon;
    {[_x, "FPV_AP", _sideKey, false, false, "DEFAULT"] call _registerClass} forEach _ap;
    {[_x, "FPV_AT", _sideKey, false, false, "DEFAULT"] call _registerClass} forEach _at;
    {[_x, "BOMBER", _sideKey, false, false, "DEFAULT"] call _registerClass} forEach _bomber;
};
["B", "WEST"] call _sideGeneric;
["O", "EAST"] call _sideGeneric;
["I", "GUER"] call _sideGeneric;

{
    _x params ["_class", "_category"];
    [_class, _category, "ANY", false, (_class find "_TI") >= 0, "DEFAULT"] call _registerClass;
} forEach [
    ["sps_black_hornet_01_Static_F", "RECON"], ["ItemMavic3T", "RECON"], ["Item_Mavic3T", "RECON"],
    ["1Rnd_RC40_shell_RF", "RECON"], ["1Rnd_RC40_HE_shell_RF", "FPV_AP"],
    ["Item_Crocus_AP", "FPV_AP"], ["Item_Crocus_AP_TI", "FPV_AP_TI"],
    ["Item_Crocus_AT", "FPV_AT"], ["Item_Crocus_AT_TI", "FPV_AT_TI"],
    ["Item_KVN_AP", "FPV_AP"], ["Item_KVN_AP_TI", "FPV_AP_TI"],
    ["Item_KVN_AT", "FPV_AT"], ["Item_KVN_AT_TI", "FPV_AT_TI"],
    ["B_SwitchBlade_300", "FPV_AP"], ["SwitchBlade_300_Tube_Desert", "FPV_AP"], ["SwitchBlade_300_Tube_Woodland", "FPV_AP"],
    ["B_SwitchBlade_600", "FPV_AT"], ["SwitchBlade_600_Tube_Desert", "FPV_AT"], ["SwitchBlade_600_Tube_Woodland", "FPV_AT"],
    ["ItemMavic3", "BOMBER"], ["Item_Mavic", "BOMBER"], ["C_IDAP_UAV_06_antimine_F", "BOMBER"]
];

// Drongo's Artillery typo is resolved at runtime, never assumed.
if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_B")) then {["DRA_UAV_01_B", "FPV_AT", "WEST"] call _registerClass};
if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_I")) then {["DRA_UAV_01_I", "FPV_AT", "GUER"] call _registerClass};
if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_O")) then {
    ["DRA_UAV_01_O", "FPV_AT", "EAST"] call _registerClass;
} else {
    if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_0")) then {["DRA_UAV_01_0", "FPV_AT", "EAST"] call _registerClass};
};
if (isClass (configFile >> "CfgVehicles" >> "DDT_AR2_FPV_AP_backpack_O")) then {
    ["DDT_AR2_FPV_AP_backpack_O", "FPV_AP", "EAST"] call _registerClass;
};

missionNamespace setVariable ["DRO2026_droneRegistryInitialized", true];
DRO2026_availableDroneClasses = keys DRO2026_droneClassMetadata;
private _available = count DRO2026_availableDroneClasses;
[format ["Drone Warfare class registry initialized: %1 available class mappings", _available]] call DRO2026_fnc_log;
if (DRO2026_DEBUG) then {[format ["Available Drone Warfare classes: %1", DRO2026_availableDroneClasses]] call DRO2026_fnc_log};
DRO2026_droneRegistry
