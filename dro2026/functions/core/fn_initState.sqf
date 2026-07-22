if (missionNamespace getVariable ["DRO2026_initialized", false]) exitWith {};
missionNamespace setVariable ["DRO2026_initialized", true];

DRO2026_assetRegistry = createHashMap;
DRO2026_ammoRegistry = createHashMap;
DRO2026_managedGroups = [];
DRO2026_managedVehicles = [];
DRO2026_contacts = [];
DRO2026_sites = [];
DRO2026_friendlyPositions = [];
DRO2026_activeDrones = [];
DRO2026_droneRegistry = createHashMap;
DRO2026_droneClassMetadata = createHashMap;
DRO2026_droneRegistryInitialized = false;
DRO2026_droneAdapterReady = false;
DRO2026_ddtConfigured = false;
DRO2026_ddtDeploySides = [];
DRO2026_droneWarfareDirectorStarted = false;
DRO2026_lastDroneAssignmentPass = -999;
DRO2026_lastDroneIntelPass = -999;
DRO2026_lastDroneInfosharePass = -999;
DRO2026_lastDroneUnassignedPass = -999;
DRO2026_activeConvoys = [];
DRO2026_supplyLanes = [];
DRO2026_supplyEvents = [];
DRO2026_usedObjectiveTypes = [];
DRO2026_usedObjectiveNodes = [];
DRO2026_objectiveQueue = [];
DRO2026_operationPackageName = "";
DRO2026_objectiveMeta = createHashMap;
DRO2026_reservedObjectivePositions = [];
DRO2026_processedSupportRequests = createHashMap;
DRO2026_contactQuarantine = createHashMap;
DRO2026_logDedupeCounters = createHashMap;
DRO2026_telemetryDedupe = createHashMap;
DRO2026_telemetryStats = createHashMapFromArray [["emitted",0],["suppressed",0]];
DRO2026_telemetryEventCounts = createHashMap;
DRO2026_telemetryEventIntervalCounts = createHashMap;
DRO2026_telemetrySequence = 0;
DRO2026_telemetryStarted = false;
DRO2026_telemetryMissionHandlers = [];
DRO2026_assetDescriptors = createHashMap;
DRO2026_assetRegistryInitialized = false;
DRO2026_assetRegistryInvalidated = false;
DRO2026_supportCatalogSignature = "";
DRO2026_supportChannels = [];
DRO2026_dynamicTasks = [];
DRO2026_logisticsJobs = [];
DRO2026_reserveMultiplierApplied = false;
DRO2026_dynamicObjectiveDirectorStarted = false;

DRO2026_theaterNodes = createHashMap;
DRO2026_theaterLayout = createHashMap;
DRO2026_theaterBuilt = false;
DRO2026_networkNodes = createHashMap;
DRO2026_networkEdges = createHashMap;
DRO2026_networkBuilt = false;
DRO2026_eventLog = [];
DRO2026_eventSequence = 0;
DRO2026_actionIntents = [];
DRO2026_siteHistory = [];
DRO2026_seedStreams = createHashMap;
DRO2026_strategicPlan = [];
DRO2026_strategicPlanBuilt = false;
DRO2026_endgameState = createHashMap;
DRO2026_endgameReadyEmitted = false;

// Interactive strategic warfare state. These limits prevent AA/OTRK/aviation saturation.
DRO2026_activeStrategicMunitions = [];
DRO2026_capabilityEffectsDirectorStarted = false;
DRO2026_strategicStrikeDirectorStarted = false;
DRO2026_missileDefenceDirectorStarted = false;
DRO2026_pointDefenceDirectorStarted = false;
DRO2026_enemyAirDirectorStarted = false;
DRO2026_activeEnemyAirMissions = 0;
DRO2026_enemyDecisionIntervalMultiplier = 1;
DRO2026_enemySensorIntervalMultiplier = 1;
DRO2026_enemyDispatchIntervalMultiplier = 1;
DRO2026_friendlyDecisionIntervalMultiplier = 1;
DRO2026_friendlyDispatchIntervalMultiplier = 1;
if (isNil "DRO2026_MAX_ISKANDER_LAUNCHES") then {DRO2026_MAX_ISKANDER_LAUNCHES = 2};
if (isNil "DRO2026_ISKANDER_COOLDOWN") then {DRO2026_ISKANDER_COOLDOWN = 900};
missionNamespace setVariable ["DRO2026_MAX_ISKANDER_LAUNCHES",DRO2026_MAX_ISKANDER_LAUNCHES];
missionNamespace setVariable ["DRO2026_ISKANDER_COOLDOWN",DRO2026_ISKANDER_COOLDOWN];
missionNamespace setVariable ["DRO2026_activeStrategicMunitions",DRO2026_activeStrategicMunitions];
missionNamespace setVariable ["DRO2026_activeEnemyAirMissions",0];

private _configuredSeed = missionNamespace getVariable ["DRO2026_OPERATION_SEED",-1];
private _existingSeed = missionNamespace getVariable ["DRO2026_operationSeed",-1];
private _operationSeed = if (_configuredSeed isEqualType 0 && {_configuredSeed > 0}) then {_configuredSeed} else {
    if (_existingSeed isEqualType 0 && {_existingSeed > 0}) then {_existingSeed} else {1 + floor random 2147483000}
};
missionNamespace setVariable ["DRO2026_operationSeed",_operationSeed,true];

private _doctrineIndex = floor ([4,"DOCTRINE",0] call DRO2026_fnc_seededRandom);
private _doctrines = ["DRONE_HEAVY","ARTILLERY_HEAVY","DEFENSIVE_NETWORK","MOBILE_RESERVES"];
DRO2026_operationState = createHashMapFromArray [
    ["schema", 3],
    ["phase", "DEPLOYMENT"],
    ["doctrine", _doctrines param [_doctrineIndex,"DEFENSIVE_NETWORK"]],
    ["alertState", "GREEN"],
    ["playerNoise", 0],
    ["civilianTrust", 55],
    ["operationScore", 0],
    ["activeOpportunities", []],
    ["completedEffects", []],
    ["startedAt", time],
    ["lastPhaseChange", time],
    ["operationSeed",_operationSeed],
    ["endgameReady",false],
    ["strategicMunitionsActive",0],
    ["iskanderLaunches",0]
];

DRO2026_voiceQueue = [];
DRO2026_voiceWorkerActive = false;
DRO2026_fpsAverage = 45;
DRO2026_spawnBudgetFactor = 1;
DRO2026_alertLevel = 0.20;
DRO2026_intelQuality = 0.35;
DRO2026_directorsStarted = false;
DRO2026_lastFPVRequest = -999;
DRO2026_lastISRRequest = -999;
DRO2026_lastEnemyFPV = -999;
DRO2026_lastEnemyISR = -999;
DRO2026_lastEnemyLongRange = -999;
DRO2026_lastFriendlyStrike = -999;
DRO2026_lastLongSupportRequest = -999;
DRO2026_friendlyFP5Used = 0;
DRO2026_reinforcementWaves = 0;
DRO2026_supportAssets = createHashMap;
DRO2026_supportDialogOpen = false;
DRO2026_supportCatalog = [];
DRO2026_supportCatalogReady = false;
DRO2026_supportCatalogVersion = 0;
DRO2026_supportCategories = ["UAV", "ARTY", "CAS"];
DRO2026_supportFireLockUntil = -1;
DRO2026_activeHeavySupport = 0;
DRO2026_missionEnding = false;
if (isServer) then {
    addMissionEventHandler ["Ended", {missionNamespace setVariable ["DRO2026_missionEnding", true]}];
    addMissionEventHandler ["MPEnded", {missionNamespace setVariable ["DRO2026_missionEnding", true]}];
};
DRO2026_civilTraffic = [];
DRO2026_supportPreset = createHashMapFromArray [["isrDefault", "AUTO"], ["strikeDefault", "AUTO"], ["automation", "RECOMMEND_ONLY"]];

DRO2026_resources = createHashMapFromArray [
    ["enemySupply", 100], ["enemyArtilleryAmmo", 80], ["enemyDroneStock", 48],
    ["enemyLongRangeStock", 12], ["enemyReinforcement", 78], ["enemyEW", 65],
    ["enemyAirDefence", 70], ["friendlySupply", 80], ["friendlyFPVStock", 18],
    ["friendlyISRStock", 8], ["smallQuadISR", 4], ["tacticalISR", 3], ["longRangeISR", 2], ["MALE_HALE_ISR", 1], ["reusableISR", 6], ["expendableISR", 4], ["friendlyLongRangeStock", 20], ["friendlyFP5Stock", 2],
    ["friendlyDecoyStock", 6], ["friendlyArtilleryStock", 18], ["friendlyAirSorties", 4]
];

DRO2026_voiceMap = createHashMapFromArray [
    ["RADIO_CHECK", [["dro2026\audio\racia2\A1.ogg", 5.4, "Штаб: Альфа, Альфа! Я База. Приём."]]],
    ["NEW_TASK", [["dro2026\audio\racia2\A11.ogg", 3.7, "Штаб: Альфа, у вас новое задание."]]],
    ["ACK", [["dro2026\audio\racia2\A14.ogg", 2.0, "Штаб: Альфа, принято."], ["dro2026\audio\racia2\A31.ogg", 1.7, "Штаб: Альфа, плюс."], ["dro2026\audio\racia2\A61.ogg", 3.2, "Штаб: Альфа, принято. Оставайтесь на связи."]]],
    ["ARTILLERY_TASK", [["dro2026\audio\racia2\A15.ogg", 7.0, "Штаб: В вашем районе действует артиллерия противника. Найдите и уничтожьте её."]]],
    ["ARTILLERY_DESTROYED", [["dro2026\audio\racia2\A13.ogg", 1.9, "Штаб: Артиллерия уничтожена."]]],
    ["CONVOY_TASK", [["dro2026\audio\racia2\A34.ogg", 6.8, "Штаб: В вашем направлении выдвинулась колонна противника. Уничтожьте её."]]],
    ["CONVOY_DESTROYED", [["dro2026\audio\racia2\A23.ogg", 1.6, "Штаб: Колонна уничтожена."]]],
    ["AMMO_TASK", [["dro2026\audio\racia2\A76.ogg", 5.4, "Штаб: Найдите и уничтожьте склад с боеприпасами."]]],
    ["LOGISTICS_DESTROYED", [["dro2026\audio\racia2\A66.ogg", 2.2, "Штаб: Склад с оружием уничтожен."], ["dro2026\audio\racia2\A21.ogg", 2.3, "Штаб: Топливный склад уничтожен."]]],
    ["EW_TASK", [["dro2026\audio\racia2\A130.ogg", 7.4, "Штаб: Новая задача. Найдите и уничтожьте систему РЭБ в вашем районе."], ["dro2026\audio\racia2\A131.ogg", 4.7, "Штаб: Она мешает работать нашим птичкам."]]],
    ["AA_DESTROYED", [["dro2026\audio\racia2\A68.ogg", 4.1, "Штаб: ПВО уничтожено. Отлично сработали."]]],
    ["CONTACT", [["dro2026\audio\racia2\A28.ogg", 6.7, "Альфа: Цель обнаружена. Запрашиваю поддержку."]]],
    ["TARGET_DESTROYED", [["dro2026\audio\racia2\A30.ogg", 2.1, "Штаб: Цель уничтожена."]]],
    ["ALERT", [["dro2026\audio\racia2\A52.ogg", 2.8, "Штаб: Мы обнаружены. Противник поднял тревогу."]]],
    ["STATUS_QUERY", [["dro2026\audio\racia2\A69.ogg", 4.9, "Штаб: Как у вас обстановка, Альфа?"]]],
    ["TASK_COMPLETE", [["dro2026\audio\racia2\A6.ogg", 4.5, "Альфа: База, задача выполнена."], ["dro2026\audio\racia2\A70.ogg", 2.2, "Штаб: Задача выполнена."]]],
    ["RETREAT", [["dro2026\audio\racia2\A86.ogg", 8.4, "Штаб: У противника слишком большие силы. Альфа, отступите."]]],
    ["RADIO_END", [["dro2026\audio\racia2\A18.ogg", 1.6, "Штаб: Конец связи."]]]
];

[] call DRO2026_fnc_initStrategicOperationData;
[] call DRO2026_fnc_registerAssets;
["STRATEGIC","OPERATION_SEED",createHashMapFromArray [["seed",_operationSeed],["version",DRO2026_VERSION],["maxIskanderLaunches",DRO2026_MAX_ISKANDER_LAUNCHES]],"OPERATION"] call DRO2026_fnc_logStructured;
[format ["Состояние инициализировано, версия %1, seed %2", DRO2026_VERSION, _operationSeed]] call DRO2026_fnc_log;