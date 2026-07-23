params [["_class", "", [""]]];
if (_class == "") exitWith {"INVALID"};
if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized", false]) then {
    [] call DRO2026_fnc_initStrategicOperationData;
};

private _explicit = DRO2026_primaryRoleRegistry getOrDefault [_class, ""];
if (_explicit != "") exitWith {_explicit};

private _cfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg) exitWith {"INVALID"};
if (getNumber (_cfg >> "isBackpack") > 0) exitWith {"BACKPACK"};
if (getNumber (_cfg >> "scope") < 1) exitWith {"HELPER"};

private _name = toLowerANSI _class;
private _display = toLowerANSI getText (_cfg >> "displayName");
private _hay = format ["%1 %2", _name, _display];

if ((_hay find "9k720") >= 0 || {(_hay find "iskander") >= 0}) exitWith {"BALLISTIC_MISSILE_LAUNCHER"};
if ((_hay find "s300") >= 0 && {(_hay find "radar") < 0} && {(_hay find "_rs") < 0}) exitWith {"SAM_LONG_RANGE"};
if ((_hay find "s300") >= 0 && {(_hay find "radar") >= 0 || {(_hay find "_rs") >= 0}}) exitWith {"FIRE_CONTROL_RADAR"};
if ((_hay find "nebo") >= 0) exitWith {"EARLY_WARNING_RADAR"};
if ((_hay find "9k317") >= 0 || {(_hay find "buk") >= 0}) exitWith {"SAM_MEDIUM_RANGE"};
if ((_hay find "96k6") >= 0 || {(_hay find "pantsir") >= 0} || {(_hay find "9k332") >= 0} || {(_hay find "tor-m") >= 0}) exitWith {"SHORAD"};
if (
    (_hay find "zu23") >= 0 || {(_hay find "zsu") >= 0} || {(_hay find "shilka") >= 0} ||
    {(_hay find "tungus") >= 0} || {(_hay find "2s6") >= 0} ||
    {(_name find "_aa_f") >= 0} || {(_name find "_aa_ghex_f") >= 0}
) exitWith {"SHORAD"};
if ((_hay find "bm35") >= 0 && {(_hay find "launcher") >= 0}) exitWith {"UAV_LAUNCHER"};

if (_class isKindOf "Man") exitWith {"PERSONNEL"};
if (_class isKindOf "Helicopter") exitWith {
    if (getNumber (_cfg >> "transportSoldier") > 3) then {"HELICOPTER_TRANSPORT"} else {"HELICOPTER_ATTACK"}
};
if (_class isKindOf "Plane") exitWith {
    if (getNumber (_cfg >> "isUav") > 0) then {"RECON"} else {"AIRCRAFT_STRIKE"}
};
if (getNumber (_cfg >> "isUav") > 0) exitWith {
    if ((_hay find "fpv") >= 0 || {(_hay find "kvn") >= 0}) then {"FPV_LAUNCHER"} else {"RECON"}
};

if (getNumber (_cfg >> "artilleryScanner") > 0 || {(_hay find "mortar") >= 0}) exitWith {
    if ((_hay find "mortar") >= 0) then {"MORTAR"} else {
        if ((_hay find "mlrs") >= 0 || {(_hay find "mrl") >= 0} || {(_hay find "grad") >= 0}) then {"ARTILLERY_ROCKET"} else {"ARTILLERY_TUBE"}
    }
};

if (getNumber (_cfg >> "transportAmmo") > 0) exitWith {"LOGISTICS_AMMO"};
if (getNumber (_cfg >> "transportFuel") > 0) exitWith {"LOGISTICS_FUEL"};
if (getNumber (_cfg >> "transportRepair") > 0) exitWith {"LOGISTICS_REPAIR"};

if (_class isKindOf "Tank") exitWith {
    if (getNumber (_cfg >> "transportSoldier") > 4) then {"IFV"} else {"MBT"}
};
if (_class isKindOf "Wheeled_APC_F" || {_class isKindOf "Tracked_APC_F"}) exitWith {"APC"};
if (_class isKindOf "Car") exitWith {
    if (getNumber (_cfg >> "transportSoldier") > 1) then {"TRANSPORT_PERSONNEL"} else {"RECON"}
};
if (_class isKindOf "StaticWeapon") exitWith {"STATIC_DEFENCE"};
"UNKNOWN"
