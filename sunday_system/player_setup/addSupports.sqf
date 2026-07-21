params ["_basePos"];
if (!isServer) exitWith {};
diag_log "DRO: Initialising support categories (RC6 catalog mode)";

// Legacy code randomly selected and physically spawned one artillery/CAS/UAV class
// during mission generation. That prevented the player from choosing a concrete
// system and, in the latest RPT, selected a known unstable heavy launcher before
// the fire-spam freeze. RC6 keeps the startup choice at category level and
// materialises a class only after an explicit server-authoritative request.
private _enabled = ["UAV", "ARTY", "CAS", "SUPPLY"];
// Custom settings may add future categories, but never remove the core testing
// channels. Availability of each concrete asset is decided by the published
// config-backed catalog, not by a random startup roll or selected faction.
if (!isNil "customSupports" && {customSupports isEqualType []}) then {
    {_enabled pushBackUnique (toUpperANSI _x)} forEach customSupports;
};
_enabled = _enabled arrayIntersect _enabled;
missionNamespace setVariable ["DRO2026_supportCategories", _enabled, true];

[] call DRO2026_fnc_refreshFactionAssets;
[] call DRO2026_fnc_publishSupportCatalog;

// The unified panel action and communication item are installed exactly once by
// clientInit after playersReady/catalogReady. Do not remoteExec the menu item here:
// that previously produced duplicate JIP entries and persisted stale catalog state.

// Supply drop remains a legacy category for now, but no artillery, CAS or UAV is
// spawned here. This keeps startup light and avoids hidden random class choices.
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

diag_log format ["DRO: support categories enabled = %1; concrete selection delegated to RC6 catalog", _enabled];
