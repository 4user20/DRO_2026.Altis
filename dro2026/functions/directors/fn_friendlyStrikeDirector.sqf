if (!isServer) exitWith {};
private _lastRecommendation = -999;
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 18;
    private _mode = toUpperANSI (DRO2026_supportPreset getOrDefault ["automation", "RECOMMEND_ONLY"]);
    if !(_mode in ["MANUAL", "RECOMMEND_ONLY", "AUTO_DEFENSIVE", "AUTO_FULL"]) then {_mode = "RECOMMEND_ONLY"};
    if (_mode == "MANUAL") then {continue};
    if ((time - DRO2026_lastFriendlyStrike) <= (85 + random 95) || {(count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT}) then {continue};

    private _contacts = DRO2026_contacts select {
        (_x getOrDefault ["owner", ""]) == "PLAYER" &&
        {(_x getOrDefault ["confidence", 0]) >= 0.72} &&
        {(_x getOrDefault ["uncertaintyRadius", 9999]) <= 320} &&
        {(time - (_x getOrDefault ["lastSeen", 0])) < 230} &&
        {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])} && {
            private _target = _x getOrDefault ["target", objNull];
            isNull _target || {alive _target}
        }
    };
    if (count _contacts == 0) then {continue};

    private _contactValue = {
        params ["_contact"];
        private _target = _contact getOrDefault ["target", objNull];
        private _classification = toUpperANSI (_contact getOrDefault ["classification", "UNKNOWN"]);
        private _value = (_contact getOrDefault ["confidence", 0]) - ((_contact getOrDefault ["uncertaintyRadius", 0]) / 2000);
        if (!isNull _target) then {
            if (_target isKindOf "Tank") then {_value = _value + 0.45};
            if (_target isKindOf "Wheeled_APC_F" || {_target isKindOf "Tracked_APC_F"}) then {_value = _value + 0.34};
            if (_target isKindOf "Air") then {_value = _value + 0.42};
            if (_target isKindOf "Man") then {_value = _value - 0.18};
        };
        if ((_classification find "ARTILLERY") >= 0 || {(_classification find "АРТИЛЛЕР") >= 0}) then {_value = _value + 0.38};
        if ((_classification find "ПВО") >= 0 || {(_classification find "AA") >= 0}) then {_value = _value + 0.32};
        if ((_classification find "EW") >= 0 || {(_classification find "РЭБ") >= 0}) then {_value = _value + 0.30};
        _value
    };
    _contacts = [_contacts, [], {-([_x] call _contactValue)}, "ASCEND"] call BIS_fnc_sortBy;
    private _contact = _contacts select 0;
    private _targetPosition = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
    if (count _targetPosition < 2) then {continue};

    private _humanPlayers = allPlayers select {!(_x isKindOf "VirtualMan_F")};
    private _nearFriendly = (_humanPlayers findIf {alive _x && {_x distance2D _targetPosition < 1700}}) >= 0;
    if (!_nearFriendly) then {
        _nearFriendly = (DRO2026_friendlyPositions findIf {
            private _position = _x getOrDefault ["position", []];
            count _position > 1 && {_position distance2D _targetPosition < 1800}
        }) >= 0;
    };
    if (_mode == "AUTO_DEFENSIVE" && {!_nearFriendly}) then {continue};

    private _fpvSites = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE" && {
            private _operator = _x getOrDefault ["operator", objNull];
            !isNull _operator && {alive _operator}
        } && {
            private _position = _x getOrDefault ["position", []];
            count _position > 1 && {_position distance2D _targetPosition <= 4800}
        }
    };
    private _strategicSites = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
            private _operator = _x getOrDefault ["operator", objNull];
            !isNull _operator && {alive _operator}
        }
    };
    private _fpvStock = DRO2026_resources getOrDefault ["friendlyFPVStock", 0];
    private _longStock = DRO2026_resources getOrDefault ["friendlyLongRangeStock", 0];
    private _fp5Stock = DRO2026_resources getOrDefault ["friendlyFP5Stock", 0];
    private _canUseFP5 = _mode == "AUTO_FULL" &&
        {DRO2026_friendlyFP5Used < 2} &&
        {_fp5Stock > 0} &&
        {([_contact] call _contactValue) > 1.1};
    private _strategicAvailable = _longStock > 0 || {_canUseFP5};
    private _recommendedSystem = if (count _fpvSites > 0 && {_fpvStock > 0}) then {"FPV"} else {
        if (count _strategicSites > 0 && {_strategicAvailable}) then {"LONG_RANGE"} else {"NONE"}
    };
    if (_recommendedSystem == "NONE") then {continue};

    if (_mode == "RECOMMEND_ONLY") then {
        if ((time - _lastRecommendation) > 120) then {
            private _payload = createHashMapFromArray [
                ["contactId", _contact getOrDefault ["id", ""]],
                ["classification", _contact getOrDefault ["classification", "ЦЕЛЬ"]],
                ["position", +_targetPosition],
                ["confidence", _contact getOrDefault ["confidence", 0]],
                ["uncertainty", _contact getOrDefault ["uncertaintyRadius", 0]],
                ["recommendedSystem", _recommendedSystem],
                ["defensive", _nearFriendly]
            ];
            ["SUPPORT_RECOMMENDED", _payload, "FRIENDLY_HQ"] call DRO2026_fnc_emitEvent;
            [
                "ACK",
                format ["Штаб: выявлена приоритетная цель %1. Рекомендуем запросить %2 через панель поддержки; ресурс автоматически не расходуется.", _contact getOrDefault ["classification", "ЦЕЛЬ"], if (_recommendedSystem == "FPV") then {"FPV"} else {"дальний БПЛА"}],
                -2
            ] call DRO2026_fnc_hqVoice;
            _lastRecommendation = time;
        };
        continue;
    };

    if (_recommendedSystem == "FPV") then {
        _fpvSites = [_fpvSites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPosition}, "ASCEND"] call BIS_fnc_sortBy;
        private _site = _fpvSites select 0;
        private _origin = _site getOrDefault ["position", _targetPosition];
        private _operator = _site getOrDefault ["operator", objNull];
        DRO2026_resources set ["friendlyFPVStock", (_fpvStock - 1) max 0];
        [_origin, _contact, playersSide, _operator, false, objNull] spawn DRO2026_fnc_launchFPVStrike;
        ["FRIENDLY_AUTO_STRIKE", createHashMapFromArray [["mode", _mode], ["system", "FPV"], ["contactId", _contact getOrDefault ["id", ""]]], "FRIENDLY_HQ"] call DRO2026_fnc_emitEvent;
        ["ACK", "Штаб: автоматический защитный контур назначил FPV по подтверждённой цели.", -2] call DRO2026_fnc_hqVoice;
        DRO2026_lastFriendlyStrike = time;
    } else {
        private _site = _strategicSites select 0;
        private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
        private _operator = _site getOrDefault ["operator", objNull];
        private _preferFP5 = _canUseFP5;
        private _type = if (_preferFP5) then {"FP5"} else {"AUTO"};
        private _reservePool = if (_preferFP5) then {"friendlyFP5Stock"} else {"friendlyLongRangeStock"};
        private _reserveStock = DRO2026_resources getOrDefault [_reservePool, 0];
        if (_reserveStock <= 0) then {continue};
        DRO2026_resources set [_reservePool, (_reserveStock - 1) max 0];
        [_origin, _contact, playersSide, _preferFP5, _operator, _type, false, 0, 1, true] spawn DRO2026_fnc_launchLongRangeStrike;
        ["FRIENDLY_AUTO_STRIKE", createHashMapFromArray [["mode", _mode], ["system", if (_preferFP5) then {"FP5"} else {"LONG_RANGE"}], ["contactId", _contact getOrDefault ["id", ""]]], "FRIENDLY_HQ"] call DRO2026_fnc_emitEvent;
        ["ACK", "Штаб: автоматический контур назначил дальний ударный БПЛА по высокоценной цели.", -2] call DRO2026_fnc_hqVoice;
        DRO2026_lastFriendlyStrike = time;
    };
};