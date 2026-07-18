if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;

[] spawn {
    private _playerDeadline = time + 45;
    waitUntil {sleep 0.1; !isNull player || {time > _playerDeadline}};
    if (isNull player) exitWith {diag_log "[DRO2026] clientInit: player unavailable after timeout"};

    if !(player diarySubjectExists "dro2026") then {player createDiarySubject ["dro2026", "DRO 2026"]};
    player createDiaryRecord ["dro2026", ["Поддержка", "
        <font size='18' face='PuristaBold'>Панель поддержки штаба</font><br/><br/>
        Через меню связи открывается единая панель, где выбираются конкретный тип БПЛА, артиллерийская система, авиация и количество средств.<br/><br/>
        FPV применяется только по свежей подтверждённой цели. Дружественный FPV можно запросить в ручном режиме и подключиться к нему через появившееся действие.<br/><br/>
        Дальние БПЛА допускают залп до десяти аппаратов при наличии запаса и свободного лимита симуляции.
    "]];
    player createDiaryRecord ["dro2026", ["Совместимость", "
        Миссия автоматически скрывает недоступные модовые средства. Наземные пусковые не используются как летающие аппараты: их штатный ammo-класс извлекается из оружия и магазина либо применяется безопасный fallback.
    "]];

    private _readyDeadline = time + 180;
    waitUntil {sleep 0.5; missionNamespace getVariable ["playersReady", 0] == 1 || {time > _readyDeadline}};
    if ((missionNamespace getVariable ["playersReady", 0]) != 1) exitWith {diag_log "[DRO2026] clientInit: playersReady timeout"};
    sleep 2;

    if (isNil "DRO2026_commSupport" || {DRO2026_commSupport < 0}) then {
        DRO2026_commSupport = [player, "DRO2026_OpenSupportConsole", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    };
    if (isNil "DRO2026_commStatus" || {DRO2026_commStatus < 0}) then {
        DRO2026_commStatus = [player, "DRO2026_Status", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    };
};
