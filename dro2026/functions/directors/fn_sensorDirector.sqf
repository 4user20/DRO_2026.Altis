if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _players = allPlayers select {alive _x};

    // Player intelligence: aggregate actual knowledge/visibility across connected players.
    {
        private _group = _x;
        if (!isNull _group && {(side _group) == enemySide} && {count units _group > 0}) then {
            private _leader = leader _group;
            if (alive _leader) then {
                private _bestKnowledge = 0;
                private _visible = false;
                {
                    private _observer = _x;
                    _bestKnowledge = _bestKnowledge max (_observer knowsAbout _leader);
                    if (!_visible && {_observer distance2D _leader < 550}) then {
                        _visible = ([_observer, "VIEW"] checkVisibility [eyePos _observer, eyePos _leader]) > 0.30;
                    };
                } forEach _players;
                if (_bestKnowledge > 1.2 || {_visible}) then {
                    private _confidence = if (_visible) then {0.74} else {
                        linearConversion [1.2, 4, _bestKnowledge, 0.45, 0.95, true]
                    };
                    ["PLAYER", vehicle _leader, getPosATL (vehicle _leader), _confidence, "ГРУППА"] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedGroups;

    {
        private _vehicle = _x;
        if (!isNull _vehicle && {alive _vehicle}) then {
            private _vehicleSide = side _vehicle;
            if (!isNull driver _vehicle) then {_vehicleSide = side (group (driver _vehicle))};
            if (_vehicleSide == enemySide) then {
                private _bestKnowledge = 0;
                {
                    _bestKnowledge = _bestKnowledge max (_x knowsAbout _vehicle);
                } forEach _players;
                if (_bestKnowledge > 1.1) then {
                    ["PLAYER", _vehicle, getPosATL _vehicle, linearConversion [1.1, 4, _bestKnowledge, 0.5, 1, true], "ТЕХНИКА"] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedVehicles;

    // Enemy knowledge: evaluate every unique player-group unit instead of server-local `player`.
    private _friendlyUnits = [];
    {
        _friendlyUnits append (units group _x);
    } forEach _players;
    _friendlyUnits = _friendlyUnits arrayIntersect _friendlyUnits;
    {
        private _friendly = vehicle _x;
        if (!isNull _friendly && {alive _friendly}) then {
            private _bestKnowledge = 0;
            {
                private _enemyGroup = _x;
                if (!isNull _enemyGroup && {(side _enemyGroup) == enemySide} && {count units _enemyGroup > 0}) then {
                    private _observer = leader _enemyGroup;
                    if (alive _observer && {_observer distance2D _friendly < 1900}) then {
                        _bestKnowledge = _bestKnowledge max (_observer knowsAbout _friendly);
                    };
                };
            } forEach DRO2026_managedGroups;
            if (_bestKnowledge > 1.5) then {
                ["ENEMY", _friendly, getPosATL _friendly, linearConversion [1.5, 4, _bestKnowledge, 0.5, 1, true], "НАША_ГРУППА"] call DRO2026_fnc_addContact;
                DRO2026_alertLevel = (DRO2026_alertLevel + 0.04) min 1;
            };
        };
    } forEach _friendlyUnits;

    private _now = time;
    {
        private _contact = _x;
        private _age = _now - (_contact getOrDefault ["lastSeen", _now]);
        private _confidence = _contact getOrDefault ["confidence", 0];
        if (_age > 20) then {
            private _newConfidence = (_confidence - 0.025) max 0;
            _contact set ["confidence", _newConfidence];
            if ((_contact getOrDefault ["owner", ""]) == "PLAYER") then {
                private _arguments = [
                    _contact getOrDefault ["id", ""],
                    _contact getOrDefault ["position", []],
                    _newConfidence,
                    _contact getOrDefault ["kind", "UNKNOWN"],
                    false
                ];
                if (hasInterface) then {_arguments call DRO2026_fnc_syncContactMarker};
                _arguments remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
            };
        };
    } forEach DRO2026_contacts;

    private _expired = DRO2026_contacts select {
        private _age = _now - (_x getOrDefault ["lastSeen", _now]);
        private _target = _x getOrDefault ["target", objNull];
        _age >= DRO2026_CONTACT_TTL ||
        {(!isNull _target) && {!alive _target}} ||
        {(_x getOrDefault ["confidence", 0]) <= 0.04}
    };
    {
        if ((_x getOrDefault ["owner", ""]) == "PLAYER") then {
            private _arguments = [_x getOrDefault ["id", ""], [], 0, "", true];
            if (hasInterface) then {_arguments call DRO2026_fnc_syncContactMarker};
            _arguments remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
        };
    } forEach _expired;
    DRO2026_contacts = DRO2026_contacts - _expired;

    sleep 5;
};