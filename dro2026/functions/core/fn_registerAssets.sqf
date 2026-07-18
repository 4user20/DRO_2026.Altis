private _registerVehicle = {
    params ["_role", "_class", ["_mustFly", false]];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg || {getNumber (_cfg >> "scope") < 1}) exitWith {};
    if (_mustFly && {!(_class isKindOf "Air")}) exitWith {
        [format ["Класс %1 исключён из %2: это не Air/UAV", _class, _role]] call DRO2026_fnc_log;
    };
    private _name = toLowerANSI _class;
    if ((_name find "pook_") == 0 || {(_name find "spawner") >= 0} || {(_name find "_root") >= 0}) exitWith {};
    private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
    _pool pushBackUnique _class;
    DRO2026_assetRegistry set [_role, _pool];
};
private _registerAmmo = {
    params ["_role", "_class"];
    if (isClass (configFile >> "CfgAmmo" >> _class)) then {
        private _pool = DRO2026_ammoRegistry getOrDefault [_role, []];
        _pool pushBackUnique _class;
        DRO2026_ammoRegistry set [_role, _pool];
    };
};

// FPV airframes. Their native impact logic is preferred; no Titan warhead injection.
{["FPV_WEST", _x, true] call _registerVehicle} forEach ["B_UAFPV_IED_AP", "B_UAFPV_OG7V_AP", "B_UAFPV_PG7VL_AT", "B_UAFPV_RKG_AP"];
{["FPV_EAST", _x, true] call _registerVehicle} forEach ["O_UAFPV_IED_AP", "O_UAFPV_OG7V_AP", "O_UAFPV_PG7VL_AT", "O_UAFPV_RKG_AP"];
{["FPV_GUER", _x, true] call _registerVehicle} forEach ["I_UAFPV_IED_AP", "I_UAFPV_OG7V_AP", "I_UAFPV_PG7VL_AT", "I_UAFPV_RKG_AP"];
{["FPV_AT_AMMO", _x] call _registerAmmo} forEach ["FPV_RPG42_AT", "M_Vorona_HEAT"];

// Long-range airframes. fp1_base_F is intentionally NOT registered: RPT/runtime evidence shows it is not a flyable vehicle.
{["LONG_RANGE_WEST", _x, true] call _registerVehicle} forEach ["FRTZ_FP2_UAV", "KBA_BM35_UAV", "Lk_shahed136_BLU", "Lk_geran2_BLU"];
{["LONG_RANGE_EAST", _x, true] call _registerVehicle} forEach ["Lk_shahed136", "Lk_geran2", "KBA_BM35_UAV", "FRTZ_FP2_UAV"];
{["LONG_RANGE_GUER", _x, true] call _registerVehicle} forEach ["Lk_shahed136_IND", "Lk_geran2_IND", "KBA_BM35_UAV", "FRTZ_FP2_UAV"];

// Launchers are separate from flyable assets. Their weapon/magazine/ammo chain is resolved at runtime.
{["LAUNCHER_FP1_WEST", _x] call _registerVehicle} forEach ["fp1_tripod_launcher_BLU"];
{["LAUNCHER_FP2_WEST", _x] call _registerVehicle} forEach ["FRTZ_FP2_Launcher"];
{["LAUNCHER_BM35_WEST", _x] call _registerVehicle} forEach ["KBA_BM35_Launcher"];
{["LAUNCHER_BULAVA_WEST", _x] call _registerVehicle} forEach ["bulava_tripod_launcher_b"];
{["LAUNCHER_FP5_WEST", _x] call _registerVehicle} forEach ["B_FP5_Launcher_F"];
{["LAUNCHER_FP2_EAST", _x] call _registerVehicle} forEach ["FRTZ_FP2_Launcher"];
{["LAUNCHER_BM35_EAST", _x] call _registerVehicle} forEach ["KBA_BM35_Launcher"];
{["LAUNCHER_BULAVA_EAST", _x] call _registerVehicle} forEach ["bulava_tripod_launcher_b"];

// Known ammunition fallbacks. Launcher-derived ammo has priority.
{["STRIKE_AMMO_FP1", _x] call _registerAmmo} forEach ["fp1_dummy_bomb", "fp1_dummy"];
{["STRIKE_AMMO_FP2", _x] call _registerAmmo} forEach ["FRTZ_FP2_Launch_Ammo"];
{["STRIKE_AMMO_BM35", _x] call _registerAmmo} forEach ["KBA_BM35_Warhead_Ammo", "KBA_BM35_Launch_Ammo"];
{["STRIKE_AMMO_SHAHED", _x] call _registerAmmo} forEach ["lk_shahed_dummy_bomb", "lk_shahed_dummy"];
{["STRIKE_AMMO_FP5", _x] call _registerAmmo} forEach ["Flamingo_CruiseMissile"];

// ISR by tier
{["PLAYER_ISR_UAV", _x, true] call _registerVehicle} forEach ["B_UAV_01_F", "B_UAV_02_dynamicLoadout_F", "rksla3_uav_rq7shadow_01_blufor", "HE_MQ4A_Blufor"];
{["ENEMY_ISR_UAV", _x, true] call _registerVehicle} forEach ["O_UAV_01_F", "O_UAV_02_dynamicLoadout_F", "RUS_VKS_forpostru"];
{["ISR_MICRO_WEST", _x, true] call _registerVehicle} forEach ["B_UAV_01_F"];
{["ISR_TACTICAL_WEST", _x, true] call _registerVehicle} forEach ["rksla3_uav_rq7shadow_01_blufor", "B_UAV_02_dynamicLoadout_F"];
{["ISR_HALE_WEST", _x, true] call _registerVehicle} forEach ["HE_MQ4A_Blufor"];
{["ISR_MICRO_EAST", _x, true] call _registerVehicle} forEach ["O_UAV_01_F"];
{["ISR_TACTICAL_EAST", _x, true] call _registerVehicle} forEach ["RUS_VKS_forpostru", "O_UAV_02_dynamicLoadout_F"];

// Air defence. Explicit classes only; never Pook site/spawner/root classes.
{["SHORAD_EAST", _x] call _registerVehicle} forEach ["O_T_APC_Tracked_02_AA_ghex_F", "O_APC_Tracked_02_AA_F", "RUS_vdv_kamaz5350zu232"];
{["SHORAD_WEST", _x] call _registerVehicle} forEach ["B_APC_Tracked_01_AA_F"];
{["LONG_RANGE_AA_EAST", _x] call _registerVehicle} forEach ["S300_F_UCG"];
{["LONG_RANGE_AA_WEST", _x] call _registerVehicle} forEach ["B_SAM_System_03_F"];
{["RADAR_EAST", _x] call _registerVehicle} forEach ["S300_RS_F_UCG", "RUS_vks_p37", "RUS_vks_prv13", "Land_Radar_F"];
{["RADAR_WEST", _x] call _registerVehicle} forEach ["B_SAM_System_03_radar_F", "B_Radar_System_01_F", "Land_Radar_F"];

// Artillery
{["ARTILLERY_EAST", _x] call _registerVehicle} forEach ["O_MBT_02_arty_F", "O_Mortar_01_F", "I_Truck_02_MRL_F"];
{["ARTILLERY_WEST", _x] call _registerVehicle} forEach ["B_MBT_01_arty_F", "B_Mortar_01_F", "DRA_MLRS_H_B"];
{["PLAYER_ARTILLERY_MORTAR", _x] call _registerVehicle} forEach ["B_Mortar_01_F"];
{["PLAYER_ARTILLERY_SPG", _x] call _registerVehicle} forEach ["B_MBT_01_arty_F"];
{["PLAYER_ARTILLERY_MLRS", _x] call _registerVehicle} forEach ["DRA_MLRS_H_B", "B_MBT_01_mlrs_F"];

// EW
{["EW_EAST", _x] call _registerVehicle} forEach ["O_Truck_03_device_F", "O_Truck_03_covered_F"];
{["EW_WEST", _x] call _registerVehicle} forEach ["B_Truck_01_box_F", "B_Truck_01_covered_F"];

// Logistics and convoy-specific vehicles
{["LOGISTICS_EAST", _x] call _registerVehicle} forEach ["O_Truck_03_ammo_F", "O_Truck_03_fuel_F", "O_Truck_03_repair_F", "O_Truck_03_transport_F", "I_Truck_02_ammo_F", "I_Truck_02_fuel_F", "RUS_MP_kamaz53501", "RUS_MP_atz75557", "RUS_MP_ac554320", "AV_KamAZ_Refuel_schnell"];
{["LOGISTICS_WEST", _x] call _registerVehicle} forEach ["B_Truck_01_ammo_F", "B_Truck_01_fuel_F", "B_Truck_01_Repair_F", "B_Truck_01_transport_F", "UAZ_03_transport_F", "UAZ_08_transport_F"];
{["CONVOY_CARGO_EAST", _x] call _registerVehicle} forEach ["RUS_MP_kamaz53501", "RUS_MP_atz75557", "RUS_MP_ac554320", "O_Truck_03_transport_F", "O_Truck_03_ammo_F"];
{["CONVOY_CARGO_WEST", _x] call _registerVehicle} forEach ["B_Truck_01_transport_F", "B_Truck_01_ammo_F", "UAZ_03_transport_F"];
{["CONVOY_ESCORT_EAST", _x] call _registerVehicle} forEach ["RUS_vdv_kamaz5350zu232", "O_MRAP_02_hmg_F"];
{["CONVOY_ESCORT_WEST", _x] call _registerVehicle} forEach ["B_MRAP_01_hmg_F", "B_MRAP_01_gmg_F"];

// Command, officers, aircraft
{["COMMAND", _x] call _registerVehicle} forEach ["Land_Cargo_HQ_V1_F", "Land_Cargo_HQ_V2_F", "Land_Cargo_HQ_V3_F", "Land_Bunker_01_HQ_F"];
{["OFFICER_WEST", _x] call _registerVehicle} forEach ["B_Soldier_F", "B_UAV_AI", "B_crew_F", "B_soldier_UAV_F"];
{["OFFICER_EAST", _x] call _registerVehicle} forEach ["O_T_Crew_F", "O_crew_F", "RUS_vks_pilot", "rhs_vdv_des_efreitor"];
{["AIR_EAST", _x, true] call _registerVehicle} forEach ["RUS_VKS_su57", "RUS_VKS_mi8t", "RUS_VKS_an2", "RUS_VKS_l39"];

// Civilian traffic
{["CIV_TRAFFIC", _x] call _registerVehicle} forEach ["av_Lada_civ", "av_Octavia", "av_Octavia_blek", "av_UAZ451_3", "av_lada_2110d", "av_niva_01", "av_zil_130f", "AV_2_Golf_Civ", "C_Offroad_01_F"];
