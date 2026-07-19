if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;

[] spawn {
    private _playerDeadline = diag_tickTime + 45;
    waitUntil {sleep 0.1; !isNull player || {diag_tickTime > _playerDeadline}};
    if (isNull player) exitWith {diag_log "[DRO2026] clientInit: player unavailable after timeout"};

    if !(player diarySubjectExists "dro2026") then {player createDiarySubject ["dro2026", "DRO 2026"]};
    player createDiaryRecord ["dro2026", ["Поддержка", "
        <font size='18' face='PuristaBold'>Панель поддержки штаба</font><br/><br/>
        Через меню связи или действие игрока открывается единая панель. В ней отображаются конкретные БПЛА, артиллерийские системы и авиация выбранной в лобби фракции.<br/><br/>
        FPV применяется только по свежей подтверждённой цели. Дружественный FPV можно запросить в ручном режиме и подключиться к нему через появившееся действие.<br/><br/>
        Дальние БПЛА допускают залп до десяти аппаратов при наличии запаса и свободного лимита симуляции.
    "]];
    player createDiaryRecord ["dro2026", ["Совместимость", "
        Сервер публикует клиенту только проверенный каталог выбранной стороны. Наземные пусковые не используются как летающие аппараты; неподдерживаемые или опасные editor/spawner-классы скрываются.
    "]];

    // Legacy populateLobby disabled UAV support unless pUAVClasses contained a
    // Plane-derived class. That rejected quadcopters and several utility-faction
    // RQ-7/MQ-4/Forpost implementations before the RC6 catalog was built. Keep the
    // button selectable whenever any compatible airborne UAV class is available;
    // this does not auto-enable the category, it only restores the player's choice.
    [] spawn {
        while {
            (missionNamespace getVariable ["playersReady", 0]) == 0 &&
            {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}
        } do {
            private _display = findDisplay 626262;
            if (!isNull _display) then {
                private _candidateClasses = [];
                if (!isNil "pUAVClasses") then {_candidateClasses append pUAVClasses};
                _candidateClasses append [
                    "rksla3_uav_rq7shadow_01_blufor", "HE_MQ4A_Blufor", "RUS_VKS_forpostru",
                    "B_UAV_02_dynamicLoadout_F", "O_UAV_02_dynamicLoadout_F", "I_UAV_02_dynamicLoadout_F",
                    "B_UAV_01_F", "O_UAV_01_F", "I_UAV_01_F"
                ];
                private _hasUAV = (_candidateClasses findIf {
                    isClass (configFile >> "CfgVehicles" >> _x) &&
                    {_x isKindOf "Air"} &&
                    {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") >= 1}
                }) >= 0;
                if (_hasUAV) then {
                    private _uavControl = _display displayCtrl 6014;
                    if (!isNull _uavControl) then {_uavControl ctrlEnable true};
                };
            };
            sleep 0.5;
        };
    };

    // Lobby/loadout configuration is user-driven and may legitimately take longer
    // than four minutes. The old deadline caused clientInit to exit permanently
    // before playersReady (confirmed by the 2026-07-19 RPT), so the support menu
    // never appeared. Wait for the actual start, with mission end as the only abort.
    waitUntil {
        sleep 0.5;
        (missionNamespace getVariable ["playersReady", 0]) == 1 ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};

    private _catalogDeadline = diag_tickTime + 90;
    waitUntil {
        sleep 0.25;
        missionNamespace getVariable ["DRO2026_supportCatalogReady", false] ||
        {diag_tickTime > _catalogDeadline} ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if !(missionNamespace getVariable ["DRO2026_supportCatalogReady", false]) then {
        diag_log "[DRO2026] clientInit: support catalog timeout; panel remains available with diagnostic message";
    };
    sleep 2;

    if (isNil "DRO2026_commSupport" || {DRO2026_commSupport < 0}) then {
        DRO2026_commSupport = [player, "DRO2026_OpenSupportConsole", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    };
    if (isNil "DRO2026_commStatus" || {DRO2026_commStatus < 0}) then {
        DRO2026_commStatus = [player, "DRO2026_Status", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    };
    if (isNil "DRO2026_supportAction" || {DRO2026_supportAction < 0}) then {
        DRO2026_supportAction = player addAction [
            "Панель поддержки штаба",
            {[] call DRO2026_fnc_openSupportConsole},
            nil,
            5.5,
            false,
            true,
            "",
            "alive _target"
        ];
    };
    diag_log format ["[DRO2026] support UI installed; catalog ready=%1 entries=%2", missionNamespace getVariable ["DRO2026_supportCatalogReady", false], count (missionNamespace getVariable ["DRO2026_supportCatalog", []])];
};
