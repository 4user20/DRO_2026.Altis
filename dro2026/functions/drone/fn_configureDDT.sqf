params [["_force", false]];
if (!isServer) exitWith {false};
if !(call DRO2026_fnc_hasDDT) exitWith {false};
if !(missionNamespace getVariable ["ddtReady", false]) exitWith {false};
if ((missionNamespace getVariable ["DRO2026_ddtConfigured", false]) && {!_force}) exitWith {true};
if !(missionNamespace getVariable ["DRO2026_droneRegistryInitialized", false]) then {[] call DRO2026_fnc_initializeDroneRegistry};

private _override = missionNamespace getVariable ["DRO2026_DDT_OVERRIDE_SETTINGS", false];
private _setDefault = {
    params ["_name", "_value"];
    if (_override || {isNil {missionNamespace getVariable _name}}) then {
        missionNamespace setVariable [_name, _value, true];
    };
};

private _deploySides = [enemySide];
if ((missionNamespace getVariable ["DRO2026_DDT_INCLUDE_RESISTANCE", false]) && {resistance != enemySide}) then {
    _deploySides pushBackUnique resistance;
};
DRO2026_ddtDeploySides = _deploySides;
// DDT postInit starts deploy loops on every machine and those scripts have no isServer guard.
// Keep the native scanners inert globally; the DRO server dispatcher calls DDT deploy/AI functions.
missionNamespace setVariable ["ddtDeploySides", [], true];
missionNamespace setVariable ["ddtDeployBehaviour", ["SAFE", "AWARE", "COMBAT"], true];
["ddtCycleRecon", 45] call _setDefault;
["ddtCycleAttack", 60] call _setDefault;
["ddtAttackRangeFPV", 2500] call _setDefault;
["ddtAttackRangeBomber", 1800] call _setDefault;
["ddtCooldownValue", 180] call _setDefault;
["ddtReconAlt", [120, 240]] call _setDefault;
["ddtReconRadius", [1500, 3500]] call _setDefault;
["ddtLoiterChance", 40] call _setDefault;
["ddtExclusionRadiusRecon", 1800] call _setDefault;
["ddtExclusionRadiusFPV", 2500] call _setDefault;
["ddtExclusionRadiusBomber", 1500] call _setDefault;

private _enableUnassigned = missionNamespace getVariable ["DRO2026_DDT_ENABLE_UNASSIGNED", false];
private _customFallback = missionNamespace getVariable ["DRO2026_CUSTOM_FPV_FALLBACK", true];
if (_enableUnassigned && {!_customFallback}) then {
    missionNamespace setVariable ["ddtCycleUnassigned", 60, true];
} else {
    missionNamespace setVariable ["ddtCycleUnassigned", -1, true];
    if (_enableUnassigned && {_customFallback}) then {
        ["DDT unassigned takeover kept disabled: custom FPV fallback is active"] call DRO2026_fnc_log;
    };
};

// DDT's native jammer directly disconnects, kills crew and drains fuel without a class exemption.
// DRO owns EW while this adapter is active so KVN fiber-optic immunity can be enforced consistently.
if (missionNamespace getVariable ["DRO2026_DDT_DISABLE_NATIVE_JAMMERS", true]) then {
    missionNamespace setVariable ["ddtJammers", [], true];
};

private _appendRegistry = {
    params ["_ddtName", "_categories"];
    private _target = missionNamespace getVariable [_ddtName, []];
    {
        private _category = _x;
        {
            private _entries = DRO2026_droneRegistry getOrDefault [format ["%1_%2", _category, _x], []];
            {
                private _class = _x getOrDefault ["class", ""];
                private _carrier = _x getOrDefault ["carrier", ""];
                private _assembled = _x getOrDefault ["assembleTo", ""];
                private _knownMappedItem = _class in [
                    "ItemMavic3T", "Item_Mavic3T", "ItemMavic3", "Item_Mavic",
                    "Item_KVN_AP", "Item_KVN_AP_TI", "Item_KVN_AT", "Item_KVN_AT_TI",
                    "Item_Crocus_AP", "Item_Crocus_AP_TI", "Item_Crocus_AT", "Item_Crocus_AT_TI",
                    "sps_black_hornet_01_Static_F", "1Rnd_RC40_shell_RF", "1Rnd_RC40_HE_shell_RF"
                ];
                if (_class != "" && {_carrier in ["BACKPACK", "VEHICLE"] || {_knownMappedItem}}) then {_target pushBackUnique _class};
                if (_assembled != "") then {_target pushBackUnique _assembled};
            } forEach _entries;
        } forEach ["WEST", "EAST", "GUER", "ANY"];
    } forEach _categories;
    missionNamespace setVariable [_ddtName, _target];
};
["ddtClassesRecon", ["RECON"]] call _appendRegistry;
["ddtClassesFPV", ["FPV_AP", "FPV_AP_TI"]] call _appendRegistry;
["ddtClassesFPVAT", ["FPV_AT", "FPV_AT_TI"]] call _appendRegistry;
["ddtClassesBomber", ["BOMBER"]] call _appendRegistry;

// Resolve the DRA OPFOR typo without assuming either spelling exists.
if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_O")) then {
    ddtClassesFPVAT pushBackUnique "DRA_UAV_01_O";
} else {
    if (isClass (configFile >> "CfgVehicles" >> "DRA_UAV_01_0")) then {ddtClassesFPVAT pushBackUnique "DRA_UAV_01_0"};
};

missionNamespace setVariable ["DRO2026_ddtConfigured", true];
missionNamespace setVariable ["DRO2026_droneAdapterReady", true];
[format ["DDT adapter configured for sides %1; unassigned=%2; nativeJammersDisabled=%3", _deploySides, missionNamespace getVariable ["ddtCycleUnassigned", -1], missionNamespace getVariable ["DRO2026_DDT_DISABLE_NATIVE_JAMMERS", true]]] call DRO2026_fnc_log;
true
