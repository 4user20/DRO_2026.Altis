params ["_missionName"];

private _missionText = if (_missionName != "") then {
    format ["<font size='20' face='PuristaBold'>%1</font>", _missionName]
} else {""};

private _insertName = switch (insertType) do {
    case "SEA": {"высадка с моря"};
    case "HELI": {"вертолётная высадка"};
    case "HALO": {"высотное десантирование"};
    default {"наземное выдвижение"};
};
private _markerText = markerText "campMkr";
private _locationText = format [
    "<br/><br/>Группа %1 начинает операцию способом «%2» из района <marker name='campMkr'>%3</marker>. Основной район действий отмечен на карте. Конкретные цели находятся в списке задач.",
    playerCallsign,
    _insertName,
    _markerText
];

private _numEnemies = {side _x == enemySide} count allUnits;
private _enemyAssessment = if (_numEnemies < 60) then {
    "В районе действует рассредоточенная группировка противника."
} else {
    if (_numEnemies < 85) then {
        "В районе действует группировка средней плотности с мобильными резервами."
    } else {
        "Ожидается высокая плотность сил противника и активное применение резервов."
    }
};
private _enemyText = format ["<br/><br/>%1 %2", enemyFactionName, _enemyAssessment];

private _secondaryText = "";
if (count AOLocations > 1) then {
    private _names = [];
    {
        if (_forEachIndex > 0 && {(_x select 4) == 0}) then {
            private _loc = nearestLocation [_x select 0, ""];
            private _mkr = format ["mkrSecondaryLoc%1", _forEachIndex];
            _names pushBack format ["<marker name='%2'>%1</marker>", text _loc, _mkr];
        };
    } forEach AOLocations;
    if (count _names > 0) then {
        _secondaryText = format ["<br/><br/>Дополнительная активность отмечена в районах: %1.", [_names] call sun_stringCommaList];
    };
};

private _civilianText = if (!isNil "civTrue" && {civTrue}) then {
    "<br/><br/>В районе могут находиться гражданские. Перед применением артиллерии, авиации и FPV подтверждайте цель."
} else {
    "<br/><br/>Подтверждённого гражданского присутствия в районе операции нет."
};

private _resupplyText = if (getMarkerColor "resupplyMkr" == "") then {""} else {
    "<br/><br/>На карте отмечена <marker name='resupplyMkr'>точка снабжения</marker>."
};

private _modernText = "<br/><br/><font size='16' face='PuristaBold'>Оперативная логика DRO 2026</font><br/>Противник использует логистическую сеть, артиллерию, ПВО, РЭБ и беспилотные средства. Уничтожение узлов меняет дальнейшую интенсивность огня, число подкреплений и запас БПЛА. FPV доступен только по подтверждённым контактам. Для создания контактов используйте наблюдение и разведывательный БПЛА через меню связи.";
private _cancelText = "<br/><br/>Если задача объективно невыполнима, её можно отменить через список задач; завершённые или проваленные эпизоды учитываются при итоговой оценке.";

briefingString = format ["%1%2%3%4%5%6%7%8", _missionText, _locationText, _enemyText, _secondaryText, _civilianText, _resupplyText, _modernText, _cancelText];
publicVariable "briefingString";
[briefingString, {player createDiaryRecord ["Diary", ["Брифинг", _this]]}] remoteExec ["call", 0, true];
["BRIEFING"] spawn dro_sendProgressMessage;
