params ["_basePos"];
if (!isServer) exitWith {};
diag_log "DRO: Initialising support categories (RC7 installed-assets catalog mode)";

// Baseline support channels are deterministic. randomSupports/customSupports may add
// channels, but can no longer hide UAV/CAS and leave the player with a mortar-only panel.
private _enabled = ["UAV", "ARTY", "CAS"];
if (randomSupports == 1 && {!isNil "customSupports"} && {customSupports isEqualType []}) then {
    {_enabled pushBackUnique (toUpperANSI _x)} forEach customSupports;
};
if (!isNil "pHeliClasses" && {count pHeliClasses > 0}) then {_enabled pushBackUnique "SUPPLY"};
missionNamespace setVariable ["DRO2026_supportCategories", _enabled, true];

[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_publishSupportCatalog;

if ("SUPPLY" in _enabled) then {
    private _availableDropClasses = [];
    {
        private _types = getArray (configFile >> "CfgVehicles" >> _x >> "availableForSupportTypes");
        if ("Drop" in _types) then {_availableDropClasses pushBackUnique _x};
    } forEach pHeliClasses;
    if (count _availableDropClasses > 0) then {
        {
            [_x, "DRO_Support_Request_Drop"] remoteExecCall ["BIS_fnc_addCommMenuItem", _x, true];
        } forEach units (grpNetId call BIS_fnc_groupFromNetId);
    };
};

diag_log format ["DRO: support categories enabled = %1; all installed registered assets are exposed", _enabled];
