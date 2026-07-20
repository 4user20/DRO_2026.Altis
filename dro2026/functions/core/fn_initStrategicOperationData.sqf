if (missionNamespace getVariable ["DRO2026_strategicDataInitialized", false]) exitWith {true};

private _rolePairs = [
    ["RUS_MSV_2s3m1", "ARTILLERY_TUBE"],
    ["pook_2S7_OPFOR", "ARTILLERY_TUBE_HEAVY"],
    ["VTN_KAMAZ5350_2B26_EMR", "ARTILLERY_ROCKET_LIGHT"],
    ["RUS_MSV_2b26", "ARTILLERY_ROCKET_LIGHT"],
    ["pook_9K57M_OPFOR", "ARTILLERY_ROCKET_HEAVY"],
    ["RUS_VDV_2b14", "MORTAR"],
    ["S300_F_UCG", "SAM_LONG_RANGE"],
    ["S300_RS_F_UCG", "FIRE_CONTROL_RADAR"],
    ["pook_Nebo_UE_radar", "EARLY_WARNING_RADAR"],
    ["pook_Nebo_SV_BROWN", "EARLY_WARNING_RADAR"],
    ["pook_9K317M2_Root", "SAM_MEDIUM_RANGE"],
    ["pook_96K6_root", "SHORAD"],
    ["pook_9K332_Root", "SHORAD"],
    ["RUS_vdv_kamaz5350zu232", "SHORAD"],
    ["RUS_VDV_gaz66zu232", "SHORAD"],
    ["pook_9K720_OPFOR", "BALLISTIC_MISSILE_LAUNCHER"],
    ["KBA_BM35_Launcher", "UAV_LAUNCHER"],
    ["RUS_MP_r142n", "SIGNALS"],
    ["RUS_VDV_r142n", "SIGNALS"],
    ["RUS_VDV_atz75557", "LOGISTICS_FUEL"],
    ["RUS_MP_atz75557", "LOGISTICS_FUEL"],
    ["RUS_MP_ac554320", "LOGISTICS_REPAIR"],
    ["RUS_VDV_kamaz4310", "LOGISTICS_GENERAL"],
    ["RUS_VDV_kamaz53501", "LOGISTICS_GENERAL"],
    ["RUS_vdv_kamaz5350379", "LOGISTICS_GENERAL"],
    ["RUS_VDV_as4350", "LOGISTICS_GENERAL"],
    ["RUS_VDV_btrd", "APC"],
    ["RUS_MSV_asn233115", "TRANSPORT_PERSONNEL"],
    ["RUS_MSV_brdm2a", "RECON"],
    ["RUS_VKS_ka52", "HELICOPTER_ATTACK"],
    ["RUS_VKS_mi24p", "HELICOPTER_ATTACK"],
    ["RUS_VKS_mi8amtsh", "HELICOPTER_TRANSPORT"],
    ["RUS_VKS_mig29smt", "AIRCRAFT_STRIKE"],
    ["RUS_VKS_su25sm", "AIRCRAFT_STRIKE"],
    ["RUS_VKS_tu95ms6", "CRUISE_MISSILE_CARRIER"],
    ["RUS_GRU_squadcommander", "SPECIAL_FORCES"],
    ["RUS_GRU_seniorrecon", "SPECIAL_FORCES"],
    ["RUS_GRU_reconmachinegunner", "SPECIAL_FORCES"],
    ["RUS_GRU_reconsniper", "SPECIAL_FORCES"],
    ["RUS_GRU_reconsapper", "SPECIAL_FORCES"],
    ["RUS_GRU_reconsanitar", "SPECIAL_FORCES"],
    ["RUS_spn_squadcommander", "SPECIAL_FORCES"],
    ["RUS_spn_seniorrecon", "SPECIAL_FORCES"],
    ["RUS_spn_reconmachinegunner", "SPECIAL_FORCES"],
    ["RUS_spn_reconsniper", "SPECIAL_FORCES"],
    ["RUS_spn_reconsapper", "SPECIAL_FORCES"],
    ["RUS_spn_reconsanitar", "SPECIAL_FORCES"],
    ["Box_IED_Exp_F", "STATIC_DEFENCE"]
];
DRO2026_primaryRoleRegistry = createHashMapFromArray _rolePairs;

private _forbidden = createHashMap;
{
    _forbidden set [_x, ["ARTILLERY_POOL", "TRANSPORT_POOL", "INSERTION_POOL", "LOGISTICS_POOL"]];
} forEach [
    "S300_F_UCG", "S300_RS_F_UCG", "pook_Nebo_UE_radar", "pook_Nebo_SV_BROWN",
    "pook_9K317M2_Root", "pook_96K6_root", "pook_9K332_Root", "pook_9K720_OPFOR",
    "RUS_vdv_kamaz5350zu232", "RUS_VDV_gaz66zu232"
];
{
    private _existing = _forbidden getOrDefault [_x, []];
    _existing pushBackUnique "TRANSPORT_POOL";
    _existing pushBackUnique "INSERTION_POOL";
    _forbidden set [_x, _existing];
} forEach [
    "RUS_MSV_2s3m1", "pook_2S7_OPFOR", "VTN_KAMAZ5350_2B26_EMR",
    "RUS_MSV_2b26", "pook_9K57M_OPFOR", "RUS_VDV_2b14", "KBA_BM35_Launcher"
];
DRO2026_forbiddenPools = _forbidden;

DRO2026_strategicCandidateSites = [
    ["S300_GATOLIA", "S300_BATTERY", [26236.6,20947.1,0], "RED_DEEP_REAR", 100, 800, true, "mission.sqm"],
    ["S300_IOANNINA", "S300_BATTERY", [22659.2,20349.8,0], "RED_REAR", 92, 800, true, "mission.sqm"],
    ["S300_AKTINARKI", "S300_BATTERY", [20643.9,10948.7,0], "RED_OPERATIONAL_DEPTH", 88, 800, true, "mission.sqm"],
    ["S300_LIVADI", "S300_BATTERY", [19634.4,7654.4,0], "RED_REAR", 96, 800, true, "mission.sqm"],
    ["NEBO_FERES", "EARLY_WARNING_RADAR", [21550.0,7373.8,0], "RED_DEEP_REAR", 96, 800, true, "mission.sqm"],
    ["NEBO_LIVADI", "EARLY_WARNING_RADAR", [18518.7,6790.8,0], "RED_DEEP_REAR", 94, 800, true, "mission.sqm"],
    ["ISKANDER_CHALKEIA_W", "BALLISTIC_MISSILE_SITE", [19879.4,10856.3,0], "RED_REAR", 100, 1200, true, "mission.sqm"],
    ["ISKANDER_CHALKEIA_E", "BALLISTIC_MISSILE_SITE", [20630.8,11791.3,0], "RED_REAR", 96, 1200, true, "mission.sqm"],
    ["ISKANDER_EKALI", "BALLISTIC_MISSILE_SITE", [17143.9,10514.2,0], "RED_OPERATIONAL_DEPTH", 90, 1200, true, "mission.sqm"],
    ["ISKANDER_QUARRY", "BALLISTIC_MISSILE_SITE", [18114.7,11610.3,0], "RED_REAR", 94, 1200, true, "mission.sqm"],
    ["BM35_SELAKANO", "BM35_LAUNCH_SITE", [20910.7,7249.6,0], "RED_DEEP_REAR", 100, 600, true, "mission.sqm"],
    ["ARTY_RODOPOLI", "ARTILLERY_SITE", [18441.0,17337.0,0], "RED_OPERATIONAL_DEPTH", 92, 700, true, "mission.sqm"],
    ["ARTY_TELOS", "ARTILLERY_SITE", [16550.0,18206.0,0], "RED_FRONT", 84, 700, true, "mission.sqm"],
    ["ARTY_FACTORY", "ARTILLERY_SITE", [15368.5,18647.0,0], "RED_OPERATIONAL_DEPTH", 86, 700, true, "mission.sqm"],
    ["ARTY_AGIATRIADA", "ARTILLERY_SITE", [15796.1,20329.1,0], "RED_OPERATIONAL_DEPTH", 84, 700, true, "mission.sqm"],
    ["ARTY_KALITHEA_MLRS", "ARTILLERY_SITE", [18461.7,17594.0,0], "RED_OPERATIONAL_DEPTH", 96, 700, true, "mission.sqm"],
    ["ARTY_KALITHEA_HEAVY", "ARTILLERY_SITE", [17979.0,17917.0,0], "RED_OPERATIONAL_DEPTH", 98, 700, true, "mission.sqm"],
    ["SHORAD_SELAKANO", "SHORAD_SITE", [21172.5,6995.7,0], "RED_REAR", 88, 800, true, "mission.sqm"],
    ["SHORAD_LIVADI", "SHORAD_SITE", [18906.1,7855.2,0], "RED_REAR", 84, 800, true, "mission.sqm"],
    ["SHORAD_DIDYMOS", "SHORAD_SITE", [17609.5,10364.9,0], "RED_OPERATIONAL_DEPTH", 86, 800, true, "mission.sqm"],
    ["SHORAD_STORAGE", "SHORAD_SITE", [18517.7,15730.2,0], "RED_OPERATIONAL_DEPTH", 90, 800, true, "mission.sqm"],
    ["FARP_MOLOS", "FARP", [26847.0,24645.0,0], "RED_DEEP_REAR", 96, 900, true, "mission.sqm"],
    ["FARP_CHELONISI", "FARP", [17546.1,13233.6,0], "RED_OPERATIONAL_DEPTH", 82, 900, true, "mission.sqm"],
    ["HQ_PYRGOS", "COMMAND_LOGISTICS_COMPOUND", [17473.0,13188.2,0], "RED_OPERATIONAL_DEPTH", 100, 180, true, "Altis.wrp"],
    ["HQ_AGIOSGEORGIOS", "COMMAND_LOGISTICS_COMPOUND", [20913.9,19253.9,0], "RED_REAR", 96, 180, true, "Altis.wrp"],
    ["HQ_MILITARY04", "COMMAND_LOGISTICS_COMPOUND", [23624.7,21025.0,0], "RED_DEEP_REAR", 90, 180, true, "Altis.wrp"],
    ["HQ_THERISA", "COMMAND_LOGISTICS_COMPOUND", [10661.1,12432.9,0], "BLUE_OPERATIONAL_DEPTH", 70, 180, true, "Altis.wrp"],
    ["HQ_FRINI", "COMMAND_LOGISTICS_COMPOUND", [14797.3,20551.8,0], "CONTESTED_ZONE", 74, 180, true, "Altis.wrp"],
    ["DEPOT_STORAGE01", "INDUSTRIAL_LOGISTICS", [18314.6,15527.2,0], "RED_OPERATIONAL_DEPTH", 100, 120, true, "Altis.wrp"],
    ["DEPOT_POWERPLANT", "INDUSTRIAL_LOGISTICS", [15354.1,16012.2,0], "CONTESTED_ZONE", 98, 120, true, "Altis.wrp"],
    ["DEPOT_FACTORY02", "INDUSTRIAL_LOGISTICS", [12639.8,16445.2,0], "CONTESTED_ZONE", 82, 120, true, "Altis.wrp"],
    ["DEPOT_FACTORY01", "INDUSTRIAL_LOGISTICS", [14291.7,18985.3,0], "RED_FRONT", 76, 120, true, "Altis.wrp"],
    ["DEPOT_EDESSA", "INDUSTRIAL_LOGISTICS", [8227.0,10879.3,0], "BLUE_OPERATIONAL_DEPTH", 70, 120, true, "Altis.wrp"],
    ["DEPOT_KALOCHORI", "INDUSTRIAL_LOGISTICS", [20769.2,15761.1,0], "RED_OPERATIONAL_DEPTH", 84, 120, true, "Altis.wrp"],
    ["DEPOT_PANAGIA", "INDUSTRIAL_LOGISTICS", [20232.0,8853.1,0], "RED_REAR", 78, 120, true, "Altis.wrp"],
    ["DEPOT_GATOLIA", "INDUSTRIAL_LOGISTICS", [27075.7,21489.8,0], "RED_DEEP_REAR", 72, 120, true, "Altis.wrp"]
];

DRO2026_warehouseBindings = [
    ["I_Shed_Ind_F", [9.678,0.386,-1.279], "TARGET_SLOT_A"],
    ["I_Shed_Ind_F", [7.768,0.727,-1.345], "TARGET_SLOT_B"]
];

DRO2026_formationTemplates = createHashMapFromArray [
    ["S300_BATTERY", createHashMapFromArray [
        ["minCount",1], ["maxCount",2], ["primaryRoles",["SAM_LONG_RANGE","FIRE_CONTROL_RADAR"]],
        ["launcherCount",2], ["launcherSpacing",[70,220]], ["radarSpacing",[90,260]], ["optionalRoles",["SIGNALS","LOGISTICS_AMMO","LOGISTICS_REPAIR","SHORAD"]]
    ]],
    ["EARLY_WARNING_RADAR", createHashMapFromArray [
        ["minCount",1], ["maxCount",1], ["primaryRoles",["EARLY_WARNING_RADAR"]],
        ["optionalRoles",["SIGNALS","SHORAD","SPECIAL_FORCES"]]
    ]],
    ["SHORAD_SITE", createHashMapFromArray [
        ["minCount",2], ["maxCount",5], ["primaryRoles",["SAM_MEDIUM_RANGE","SAM_SHORT_RANGE","SHORAD"]],
        ["optionalRoles",["SIGNALS","LOGISTICS_AMMO","SPECIAL_FORCES"]]
    ]],
    ["BALLISTIC_MISSILE_SITE", createHashMapFromArray [
        ["minCount",1], ["maxCount",2], ["primaryRoles",["BALLISTIC_MISSILE_LAUNCHER"]],
        ["launcherCount",[1,2]], ["optionalRoles",["SIGNALS","LOGISTICS_AMMO","SHORAD","SPECIAL_FORCES"]],
        ["stateMachine",["HIDDEN","MOVING_TO_FIRE_POSITION","PREPARING","READY","FIRED","DISPLACING","RELOADING","DEGRADED","DESTROYED"]]
    ]],
    ["ARTILLERY_SITE", createHashMapFromArray [
        ["minCount",2], ["maxCount",4], ["primaryRoles",["ARTILLERY_TUBE","ARTILLERY_TUBE_HEAVY","ARTILLERY_ROCKET_LIGHT","ARTILLERY_ROCKET_HEAVY","MORTAR"]],
        ["gunCount",[2,4]], ["gunSpacing",[40,250]], ["optionalRoles",["SIGNALS","LOGISTICS_AMMO","LOGISTICS_REPAIR","SHORAD"]]
    ]],
    ["BM35_LAUNCH_SITE", createHashMapFromArray [
        ["minCount",1], ["maxCount",3], ["primaryRoles",["UAV_LAUNCHER"]],
        ["launcherCount",[2,4]], ["launcherSpacing",[15,60]], ["optionalRoles",["SIGNALS","LOGISTICS_GENERAL","SHORAD","SPECIAL_FORCES"]]
    ]],
    ["INDUSTRIAL_LOGISTICS", createHashMapFromArray [
        ["minCount",1], ["maxCount",3], ["primaryRoles",["LOGISTICS_AMMO","LOGISTICS_FUEL","LOGISTICS_REPAIR","LOGISTICS_GENERAL"]],
        ["sectionCount",[2,4]], ["buildingPatterns",["I_Shed_Ind_F","Shed_Big_F","Land_Hangar_F"]]
    ]],
    ["COMMAND_LOGISTICS_COMPOUND", createHashMapFromArray [
        ["minCount",1], ["maxCount",3], ["primaryRoles",["COMMAND","SIGNALS"]],
        ["optionalRoles",["LOGISTICS_GENERAL","LOGISTICS_FUEL","SPECIAL_FORCES","SHORAD"]]
    ]],
    ["FARP", createHashMapFromArray [
        ["minCount",0], ["maxCount",2], ["primaryRoles",["HELICOPTER_ATTACK","HELICOPTER_TRANSPORT"]],
        ["optionalRoles",["LOGISTICS_FUEL","LOGISTICS_AMMO","LOGISTICS_REPAIR","SHORAD"]]
    ]],
    ["SPECIAL_FORCES", createHashMapFromArray [
        ["minCount",1], ["maxCount",3], ["primaryRoles",["SPECIAL_FORCES"]],
        ["activeHunterLimit",1], ["capabilities",["RECON","SABOTAGE","FPV_HUNTER","AMBUSH","TARGET_DESIGNATION","COUNTER_RECON"]]
    ]]
];

DRO2026_operationPhaseOrder = ["DEPLOYMENT","RECON","SHAPING","DISRUPTION","DEEP_STRIKE","COUNTERATTACK","EXPLOITATION","ENDGAME"];
DRO2026_endgameRequirements = createHashMapFromArray [
    ["minimumCompletedEffects",4],
    ["minimumStrategicDomains",3],
    ["requiredAny",["NODE_AA_LONG_01","NODE_LOGISTICS_01","NODE_DRONE_REAR_01","NODE_ARTILLERY_01","NODE_ENEMY_HQ"]],
    ["requiredThreats",["NODE_AA_LONG_01","NODE_LOGISTICS_01","NODE_ENEMY_HQ"]]
];

missionNamespace setVariable ["DRO2026_primaryRoleRegistry", DRO2026_primaryRoleRegistry];
missionNamespace setVariable ["DRO2026_forbiddenPools", DRO2026_forbiddenPools];
missionNamespace setVariable ["DRO2026_strategicCandidateSites", DRO2026_strategicCandidateSites];
missionNamespace setVariable ["DRO2026_formationTemplates", DRO2026_formationTemplates];
missionNamespace setVariable ["DRO2026_warehouseBindings", DRO2026_warehouseBindings];
missionNamespace setVariable ["DRO2026_strategicDataInitialized", true];

["STRATEGIC","REFERENCE_DATA_READY",createHashMapFromArray [
    ["candidateSites",count DRO2026_strategicCandidateSites],
    ["primaryRoles",count DRO2026_primaryRoleRegistry],
    ["formationTemplates",count DRO2026_formationTemplates]
],"STRATEGIC_DATA"] call DRO2026_fnc_logStructured;
true
