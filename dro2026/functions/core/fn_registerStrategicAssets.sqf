if !(missionNamespace getVariable ["DRO2026_strategicDataInitialized",false]) then {
    [] call DRO2026_fnc_initStrategicOperationData;
};
private _registrations = [
    ["ARTILLERY_EAST","RUS_MSV_2s3m1"],
    ["ARTILLERY_EAST","pook_2S7_OPFOR"],
    ["ARTILLERY_EAST","VTN_KAMAZ5350_2B26_EMR"],
    ["ARTILLERY_EAST","RUS_MSV_2b26"],
    ["ARTILLERY_EAST","pook_9K57M_OPFOR"],
    ["ARTILLERY_EAST","RUS_VDV_2b14"],
    ["LONG_RANGE_AA_EAST","S300_F_UCG"],
    ["RADAR_EAST","S300_RS_F_UCG"],
    ["RADAR_EAST","pook_Nebo_UE_radar"],
    ["RADAR_EAST","pook_Nebo_SV_BROWN"],
    ["BALLISTIC_MISSILE_EAST","pook_9K720_OPFOR"],
    ["LAUNCHER_BM35_EAST","KBA_BM35_Launcher"]
];
private _added = 0;
private _excluded = [];
private _runtimeBlocked = missionNamespace getVariable ["DRO2026_runtimeBlockedVehicleClasses",[]];
private _registerConcrete = {
    params ["_role","_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!(_class in _runtimeBlocked) && {isClass _cfg} && {getNumber (_cfg >> "scope") >= 1} && {getNumber (_cfg >> "isBackpack") == 0} && {getText (_cfg >> "model") != ""}) then {
        private _pool = DRO2026_assetRegistry getOrDefault [_role,[]];
        _pool pushBackUnique _class;
        DRO2026_assetRegistry set [_role,_pool];
        _added = _added + 1;
        true
    } else {
        _excluded pushBackUnique _class;
        false
    };
};
{_x params ["_role","_class"]; [_role,_class] call _registerConcrete} forEach _registrations;

// POOK exposes editor/helper root classes alongside concrete descendants. Root
// classes are metadata only and must never be passed to createVehicle. Discover
// script-spawnable descendants once from CfgVehicles and register only concrete,
// side-correct objects with a recognised operational role.
private _rootSpecifications = [
    ["SAM_MEDIUM_EAST","pook_9K317M2_Root",["SAM_MEDIUM_RANGE"]],
    ["SHORAD_EAST","pook_96K6_root",["SHORAD","SAM_SHORT_RANGE"]],
    ["SHORAD_EAST","pook_9K332_Root",["SHORAD","SAM_SHORT_RANGE"]]
];
private _blockedTokens = ["spawner","module","logic","dummy","placeholder","_root","site_","samsite","sam_site","azncontrol","unit_scanner"];
private _spawnableConfigs = "getNumber (_x >> 'scope') > 0" configClasses (configFile >> "CfgVehicles");
private _discoveredByRoot = createHashMap;
{
    _x params ["_role","_rootClass","_expectedRoles"];
    private _rootCfg = configFile >> "CfgVehicles" >> _rootClass;
    private _discovered = [];
    if (isClass _rootCfg) then {
        {
            private _class = configName _x;
            private _lower = toLowerANSI _class;
            private _dangerous = (_blockedTokens findIf {(_lower find _x) >= 0}) >= 0;
            private _roleName = [_class] call DRO2026_fnc_getAssetPrimaryRole;
            if (
                _class != _rootClass &&
                {_class isKindOf [_rootClass,configFile >> "CfgVehicles"]} &&
                {!_dangerous} &&
                {getNumber (_x >> "isBackpack") == 0} &&
                {getText (_x >> "model") != ""} &&
                {getNumber (_x >> "side") == 0} &&
                {_roleName in _expectedRoles}
            ) then {
                if ([_role,_class] call _registerConcrete) then {_discovered pushBackUnique _class};
            };
        } forEach _spawnableConfigs;
    } else {
        _excluded pushBackUnique _rootClass;
    };
    _discoveredByRoot set [_rootClass,_discovered];
} forEach _rootSpecifications;

missionNamespace setVariable ["DRO2026_strategicCompatibilityExclusions",_excluded];
["ROLE","STRATEGIC_ASSETS_REGISTERED",createHashMapFromArray [
    ["added",_added],["excluded",_excluded],["discoveredConcrete",_discoveredByRoot]
],"ASSET_REGISTRY"] call DRO2026_fnc_logStructured;
true
