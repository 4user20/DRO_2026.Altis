if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    // Разведданные игрока: только реально созданные и отслеживаемые силы.
    {
        private _grp = _x;
        if (!isNull _grp && {(side _grp) == enemySide} && {count units _grp > 0}) then {
            private _lead = leader _grp;
            if (alive _lead) then {
                private _knowledge = player knowsAbout _lead;
                private _visible = false;
                if ((player distance2D _lead) < 550) then {
                    _visible = (player checkVisibility [eyePos player, eyePos _lead]) > 0.30;
                };
                if (_knowledge > 1.2 || {_visible}) then {
                    private _confidence = if (_visible) then {0.74} else {linearConversion [1.2, 4, _knowledge, 0.45, 0.95, true]};
                    ["PLAYER", vehicle _lead, getPosATL (vehicle _lead), _confidence, "ГРУППА"] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedGroups;

    {
        private _veh = _x;
        if (alive _veh) then {
            private _vehSide = side _veh;
            if (!isNull (driver _veh)) then {_vehSide = side (group (driver _veh))};
            if (_vehSide == enemySide) then {
                private _knowledge = player knowsAbout _veh;
                if (_knowledge > 1.1) then {
                    ["PLAYER", _veh, getPosATL _veh, linearConversion [1.1, 4, _knowledge, 0.5, 1, true], "ТЕХНИКА"] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedVehicles;

    // Противник получает контакт только при фактическом обнаружении игрока/его группы.
    {
        private _friendly = vehicle _x;
        private _bestKnowledge = 0;
        {
            if (!isNull _x && {(side _x) == enemySide} && {count units _x > 0}) then {
                private _observer = leader _x;
                if (alive _observer && {(_observer distance2D _friendly) < 1900}) then {
                    _bestKnowledge = _bestKnowledge max (_observer knowsAbout _friendly);
                };
            };
        } forEach DRO2026_managedGroups;
        if (_bestKnowledge > 1.5) then {
            ["ENEMY", _friendly, getPosATL _friendly, linearConversion [1.5, 4, _bestKnowledge, 0.5, 1, true], "НАША_ГРУППА"] call DRO2026_fnc_addContact;
            DRO2026_alertLevel = (DRO2026_alertLevel + 0.04) min 1;
        };
    } forEach units (group player);

    // Контакты стареют; точные данные не сохраняются бесконечно.
    private _now = time;
    {
        private _age = _now - (_x getOrDefault ["lastSeen", _now]);
        private _confidence = _x getOrDefault ["confidence", 0];
        if (_age > 20) then {
            _x set ["confidence", (_confidence - 0.025) max 0];
            private _marker = _x getOrDefault ["marker", ""];
            if (_marker != "" && {hasInterface}) then {
                _marker setMarkerAlphaLocal (linearConversion [0, 1, (_x getOrDefault ["confidence", 0]), 0, 0.85, true]);
            };
        };
    } forEach DRO2026_contacts;

    private _expired = DRO2026_contacts select {
        private _age = _now - (_x getOrDefault ["lastSeen", _now]);
        private _target = _x getOrDefault ["target", objNull];
        _age >= DRO2026_CONTACT_TTL || {(!isNull _target) && {!alive _target}} || {(_x getOrDefault ["confidence", 0]) <= 0.04}
    };
    {
        private _marker = _x getOrDefault ["marker", ""];
        if (_marker != "" && {hasInterface}) then {deleteMarkerLocal _marker};
    } forEach _expired;
    DRO2026_contacts = DRO2026_contacts - _expired;

    sleep 5;
};
