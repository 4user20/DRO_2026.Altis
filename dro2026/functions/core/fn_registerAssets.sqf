private _registerVehicle = {
    params ["_role", "_class"];
    if (isClass (configFile >> "CfgVehicles" >> _class)) then {
        private _pool = DRO2026_assetRegistry getOrDefault [_role, []];
        _pool pushBackUnique _class;
        DRO2026_assetRegistry set [_role, _pool];
    };
};
private _registerAmmo = {
    params ["_role", "_class"];
    if (isClass (configFile >> "CfgAmmo" >> _class)) then {
        private _pool = DRO2026_ammoRegistry getOrDefault [_role, []];
        _pool pushBackUnique _class;
        DRO2026_ammoRegistry set [_role, _pool];
    };
};

// FPV
{["FPV_WEST", _x] call _registerVehicle} forEach ["B_UAFPV_IED_AP", "B_UAFPV_OG7V_AP", "B_UAFPV_PG7VL_AT", "B_UAFPV_RKG_AP"];
{["FPV_EAST", _x] call _registerVehicle} forEach ["O_UAFPV_IED_AP", "O_UAFPV_OG7V_AP", "O_UAFPV_PG7VL_AT", "O_UAFPV_RKG_AP"];
{["FPV_GUER", _x] call _registerVehicle} forEach ["I_UAFPV_IED_AP", "I_UAFPV_OG7V_AP", "I_UAFPV_PG7VL_AT", "I_UAFPV_RKG_AP"];

// Long-range strike drones and launch ecosystem
{["LONG_RANGE_WEST", _x] call _registerVehicle} forEach ["fp1_base_F", "FRTZ_FP2_UAV", "KBA_BM35_UAV", "Lk_shahed136_BLU", "Lk_geran2_BLU"];
{["LONG_RANGE_EAST", _x] call _registerVehicle} forEach ["Lk_shahed136", "Lk_geran2", "KBA_BM35_UAV", "FRTZ_FP2_UAV", "fp1_base_F"];
{["LONG_RANGE_GUER", _x] call _registerVehicle} forEach ["Lk_shahed136_IND", "Lk_geran2_IND", "KBA_BM35_UAV", "FRTZ_FP2_UAV"];
{["LONG_RANGE_LAUNCHER_WEST", _x] call _registerVehicle} forEach ["fp1_tripod_launcher_BLU", "FRTZ_FP2_Launcher", "B_FP5_Launcher_F", "bulava_tripod_launcher_b"];
{["LONG_RANGE_LAUNCHER_EAST", _x] call _registerVehicle} forEach ["FRTZ_FP2_Launcher", "bulava_tripod_launcher_b"];
["CRUISE_WEST", "Flamingo_CruiseMissile"] call _registerAmmo;

// ISR by tier
{["PLAYER_ISR_UAV", _x] call _registerVehicle} forEach ["B_UAV_01_F", "B_UAV_02_dynamicLoadout_F", "rksla3_uav_rq7shadow_01_blufor", "HE_MQ4A_Blufor"];
{["ENEMY_ISR_UAV", _x] call _registerVehicle} forEach ["O_UAV_01_F", "O_UAV_02_dynamicLoadout_F", "RUS_VKS_forpostru"];
{["ISR_MICRO_WEST", _x] call _registerVehicle} forEach ["B_UAV_01_F"];
{["ISR_TACTICAL_WEST", _x] call _registerVehicle} forEach ["rksla3_uav_rq7shadow_01_blufor", "B_UAV_02_dynamicLoadout_F"];
{["ISR_HALE_WEST", _x] call _registerVehicle} forEach ["HE_MQ4A_Blufor"];
{["ISR_MICRO_EAST", _x] call _registerVehicle} forEach ["O_UAV_01_F"];
{["ISR_TACTICAL_EAST", _x] call _registerVehicle} forEach ["RUS_VKS_forpostru", "O_UAV_02_dynamicLoadout_F"];

// Air defence, layered
{["SHORAD_EAST", _x] call _registerVehicle} forEach ["O_T_APC_Tracked_02_AA_ghex_F", "O_APC_Tracked_02_AA_F", "RUS_vdv_kamaz5350zu232"];
{["SHORAD_WEST", _x] call _registerVehicle} forEach ["B_APC_Tracked_01_AA_F"];
{["LONG_RANGE_AA_EAST", _x] call _registerVehicle} forEach ["S300_F_UCG"];
{["LONG_RANGE_AA_WEST", _x] call _registerVehicle} forEach ["B_SAM_System_03_F"];
{["RADAR_EAST", _x] call _registerVehicle} forEach ["S300_RS_F_UCG", "RUS_vks_p37", "RUS_vks_prv13", "Land_Radar_F"];
{["RADAR_WEST", _x] call _registerVehicle} forEach ["B_SAM_System_03_radar_F", "B_Radar_System_01_F", "Land_Radar_F"];

// Artillery
{["ARTILLERY_EAST", _x] call _registerVehicle} forEach ["O_MBT_02_arty_F", "O_Mortar_01_F", "I_Truck_02_MRL_F"];
{["ARTILLERY_WEST", _x] call _registerVehicle} forEach ["B_MBT_01_arty_F", "B_Mortar_01_F", "DRA_MLRS_H_B"];

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
{["AIR_EAST", _x] call _registerVehicle} forEach ["RUS_VKS_su57", "RUS_VKS_mi8t", "RUS_VKS_an2", "RUS_VKS_l39"];

// Civilian traffic
{["CIV_TRAFFIC", _x] call _registerVehicle} forEach ["av_Lada_civ", "av_Octavia", "av_Octavia_blek", "av_UAZ451_3", "av_lada_2110d", "av_niva_01", "av_zil_130f", "AV_2_Golf_Civ"];
