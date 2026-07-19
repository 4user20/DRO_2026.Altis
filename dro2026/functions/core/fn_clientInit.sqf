if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;

[] spawn {
    private _playerDeadline = time + 45;
    waitUntil {sleep 0.1; !isNull player || {time > _playerDeadline}};
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

    private _readyDeadline = time + 240;
    waitUntil {
        sleep 0.5;
        ((missionNamespace getVariable ["playersReady", 0]) == 1 && {missionNamespace getVariable ["DRO2026_supportCatalogReady", false]}) || {time > _readyDeadline}
    };
    if ((missionNamespace getVariable ["playersReady", 0]) != 1) exitWith {diag_log "[DRO2026] clientInit: playersReady timeout"};
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
};
