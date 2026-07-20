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
    ["SAM_MEDIUM_EAST","pook_9K317M2_Root"],
    ["SHORAD_EAST","pook_96K6_root"],
    ["SHORAD_EAST","pook_9K332_Root"],
    ["BALLISTIC_MISSILE_EAST","pook_9K720_OPFOR"],
    ["LAUNCHER_BM35_EAST","KBA_BM35_Launcher"]
];
private _added = 0;
private _excluded = [];
{
    _x params ["_role","_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {getNumber (_cfg >> "isBackpack") == 0}) then {
        private _pool = DRO2026_assetRegistry getOrDefault [_role,[]];
        _pool pushBackUnique _class;
        DRO2026_assetRegistry set [_role,_pool];
        _added = _added + 1;
    } else {
        _excluded pushBackUnique _class;
    };
} forEach _registrations;
missionNamespace setVariable ["DRO2026_strategicCompatibilityExclusions",_excluded];
["ROLE","STRATEGIC_ASSETS_REGISTERED",createHashMapFromArray [
    ["added",_added],["excluded",_excluded]
],"ASSET_REGISTRY"] call DRO2026_fnc_logStructured;
true
