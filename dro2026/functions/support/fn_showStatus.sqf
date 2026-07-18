[] call DRO2026_fnc_initState;
private _playerContacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" && {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV}
};
private _enemyContacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "ENEMY" && {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV}
};
private _friendlyOperators = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) in ["FRIENDLY_FPV_SITE", "FRIENDLY_DRONE_SITE"] && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
private _enemyOperators = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) in ["FPV_TEAM", "DRONE_SITE", "STRATEGIC_DRONE_SITE"] && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
private _text = format [
    "<t size='1.25' font='RobotoCondensedBold'>СВОДКА ШТАБА</t><br/><br/>" +
    "Операция: %1<br/>" +
    "Подтверждённые наши/вражеские контакты: %2 / %3<br/>" +
    "Живые расчёты БПЛА: %4 / %5<br/><br/>" +
    "Наш резерв: FPV %6 · разведка %7 · дальние %8 · FP-5 %9 · обманки %10<br/>" +
    "Активные физические БПЛА: %11/%12<br/>" +
    "Качество разведданных: %13%%<br/><br/>" +
    "Оценка противника:<br/>Логистика %14%% · Артбоезапас %15%% · FPV %16 · дальние %17 · РЭБ %18%% · ПВО %19%%",
    if (DRO2026_operationPackageName == "") then {"формируется"} else {DRO2026_operationPackageName},
    count _playerContacts,
    count _enemyContacts,
    count _friendlyOperators,
    count _enemyOperators,
    DRO2026_resources getOrDefault ["friendlyFPVStock", 0],
    DRO2026_resources getOrDefault ["friendlyISRStock", 0],
    DRO2026_resources getOrDefault ["friendlyLongRangeStock", 0],
    DRO2026_resources getOrDefault ["friendlyFP5Stock", 0],
    DRO2026_resources getOrDefault ["friendlyDecoyStock", 0],
    count DRO2026_activeDrones,
    DRO2026_PHYSICAL_DRONE_LIMIT,
    round (DRO2026_intelQuality * 100),
    round (DRO2026_resources getOrDefault ["enemySupply", 0]),
    round (DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0]),
    round (DRO2026_resources getOrDefault ["enemyDroneStock", 0]),
    round (DRO2026_resources getOrDefault ["enemyLongRangeStock", 0]),
    round (DRO2026_resources getOrDefault ["enemyEW", 0]),
    round (DRO2026_resources getOrDefault ["enemyAirDefence", 0])
];
hint parseText _text;
["STATUS_QUERY"] call DRO2026_fnc_hqVoice;
