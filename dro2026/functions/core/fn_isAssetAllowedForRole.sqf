params [
    ["_class", "", [""]],
    ["_pool", "", [""]]
];
if (_class == "" || {_pool == ""}) exitWith {false};
if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized", false]) then {
    [] call DRO2026_fnc_initStrategicOperationData;
};

private _cfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1} || {getNumber (_cfg >> "isBackpack") > 0}) exitWith {false};

private _blocked = DRO2026_forbiddenPools getOrDefault [_class, []];
if ((toUpperANSI _pool) in _blocked) exitWith {false};

private _role = [_class] call DRO2026_fnc_getAssetPrimaryRole;
private _poolKey = toUpperANSI _pool;
switch _poolKey do {
    case "ARTILLERY_POOL": {
        _role in ["ARTILLERY_TUBE","ARTILLERY_TUBE_HEAVY","ARTILLERY_ROCKET","ARTILLERY_ROCKET_LIGHT","ARTILLERY_ROCKET_HEAVY","MORTAR"]
    };
    case "AIR_DEFENCE_POOL": {
        _role in ["SAM_LONG_RANGE","SAM_MEDIUM_RANGE","SAM_SHORT_RANGE","SHORAD","EARLY_WARNING_RADAR","FIRE_CONTROL_RADAR"]
    };
    case "INSERTION_POOL": {
        _role in ["TRANSPORT_PERSONNEL","APC","IFV","HELICOPTER_TRANSPORT"]
    };
    case "TRANSPORT_POOL": {
        _role in ["TRANSPORT_PERSONNEL","TRANSPORT_CARGO","APC","IFV","HELICOPTER_TRANSPORT"]
    };
    case "LOGISTICS_POOL": {
        _role in ["LOGISTICS_AMMO","LOGISTICS_FUEL","LOGISTICS_REPAIR","LOGISTICS_GENERAL","TRANSPORT_CARGO"]
    };
    case "STRATEGIC_STRIKE_POOL": {
        _role in ["BALLISTIC_MISSILE_LAUNCHER","CRUISE_MISSILE_CARRIER"]
    };
    default {
        !(_role in ["INVALID","BACKPACK","HELPER","UNKNOWN"])
    };
}
