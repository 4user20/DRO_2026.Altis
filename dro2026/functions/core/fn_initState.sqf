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
DRO2026_activeConvoys = [];
DRO2026_supplyLanes = [];
DRO2026_supplyEvents = [];
DRO2026_usedObjectiveTypes = [];
DRO2026_objectiveQueue = [];
DRO2026_operationPackageName = "";
DRO2026_objectiveMeta = createHashMap;
DRO2026_reservedObjectivePositions = [];
DRO2026_theaterNodes = createHashMap;
DRO2026_theaterBuilt = false;
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
DRO2026_lastEnemyLongRange = -999;
DRO2026_lastFriendlyStrike = -999;
DRO2026_lastLongSupportRequest = -999;
DRO2026_friendlyFP5Used = 0;
DRO2026_reinforcementWaves = 0;
DRO2026_supportAssets = createHashMap;
DRO2026_supportDialogOpen = false;
DRO2026_missionEnding = false;
if (isServer) then {
    addMissionEventHandler ["Ended", {missionNamespace setVariable ["DRO2026_missionEnding", true]}];
    addMissionEventHandler ["MPEnded", {missionNamespace setVariable ["DRO2026_missionEnding", true]}];
};
DRO2026_civilTraffic = [];
DRO2026_supportPreset = createHashMapFromArray [["isrDefault", "AUTO"], ["strikeDefault", "AUTO"]];

DRO2026_resources = createHashMapFromArray [
    ["enemySupply", 100], ["enemyArtilleryAmmo", 80], ["enemyDroneStock", 48],
    ["enemyLongRangeStock", 12], ["enemyReinforcement", 78], ["enemyEW", 65],
    ["enemyAirDefence", 70], ["friendlySupply", 80], ["friendlyFPVStock", 18],
    ["friendlyISRStock", 8], ["friendlyLongRangeStock", 20], ["friendlyFP5Stock", 2],
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

[] call DRO2026_fnc_registerAssets;
[format ["Состояние инициализировано, версия %1", DRO2026_VERSION]] call DRO2026_fnc_log;