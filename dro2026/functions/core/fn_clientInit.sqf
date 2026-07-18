if (!hasInterface) exitWith {};
[] call DRO2026_fnc_initState;

[] spawn {
    waitUntil {!isNull player};
    player createDiarySubject ["dro2026", "DRO 2026"];
    player createDiaryRecord ["dro2026", ["Управление БПЛА", "
        <font size='18' face='PuristaBold'>Современный разведывательно-ударный контур</font><br/><br/>
        В меню связи доступны разведывательные БПЛА по типам, FPV-удар, дальние ударные БПЛА и сводка штаба.<br/><br/>
        FPV запускается только по подтверждённому контакту, отмеченному на карте. Дальние БПЛА можно отправлять и по назначенному району — особенно против логистики, ПВО, штабов и пунктов БПЛА.<br/><br/>
        Синие в основном используют FP-1 / FP-2 / BM-35 / FP-5, красные — FPV, Shahed/Geran, Forpost и дальние удары из восточного тыла.
    "]];
    player createDiaryRecord ["dro2026", ["Совместимость", "
        Миссия автоматически использует технику выбранных фракций. При наличии классов FP-2, FP-5, Bulava, BM-35, Drongo Artillery, S-300, RQ-7, MQ-4A, RUS VKS / VDV и дополнительных БПЛА они добавляются в соответствующие роли. При отсутствии модов работают ванильные резервные классы.
    "]];

    waitUntil {missionNamespace getVariable ["playersReady", 0] == 1};
    sleep 3;
    DRO2026_commFPV = [player, "DRO2026_Request_FPV", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commISR = [player, "DRO2026_Request_ISR", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commISRMicro = [player, "DRO2026_Request_ISR_Micro", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commISRRQ7 = [player, "DRO2026_Request_ISR_RQ7", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commISRMQ4 = [player, "DRO2026_Request_ISR_MQ4", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStrikeFP1 = [player, "DRO2026_Request_Strike_FP1", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStrikeFP2 = [player, "DRO2026_Request_Strike_FP2", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStrikeBM35 = [player, "DRO2026_Request_Strike_BM35", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStrikeBulava = [player, "DRO2026_Request_Strike_Bulava", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStrikeFP5 = [player, "DRO2026_Request_Strike_FP5", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commDecoy = [player, "DRO2026_Request_Decoy", nil, nil, ""] call BIS_fnc_addCommMenuItem;
    DRO2026_commStatus = [player, "DRO2026_Status", nil, nil, ""] call BIS_fnc_addCommMenuItem;
};
