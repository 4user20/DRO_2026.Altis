if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _players = allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}};

    // Player intelligence: aggregate actual knowledge/visibility across connected human players.
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
                    private _confidence = if (_visible) then {0.78} else {linearConversion [1.2, 4, _bestKnowledge, 0.45, 0.92, true]};
                    private _source = if (_visible) then {"VISUAL"} else {"AI_KNOWLEDGE"};
                    private _uncertainty = if (_visible) then {22} else {linearConversion [1.2, 4, _bestKnowledge, 150, 55, true]};
                    ["PLAYER", vehicle _leader, getPosATL (vehicle _leader), _confidence, "ГРУППА", _source, _uncertainty] call DRO2026_fnc_addContact;
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
                {_bestKnowledge = _bestKnowledge max (_x knowsAbout _vehicle)} forEach _players;
                if (_bestKnowledge > 1.1) then {
                    [
                        "PLAYER", _vehicle, getPosATL _vehicle,
                        linearConversion [1.1, 4, _bestKnowledge, 0.5, 0.96, true],
                        "ТЕХНИКА", "AI_KNOWLEDGE", linearConversion [1.1, 4, _bestKnowledge, 180, 60, true]
                    ] call DRO2026_fnc_addContact;
                };
            };
        };
    } forEach DRO2026_managedVehicles;

    // Enemy knowledge: evaluate every unique human player-group unit instead of server-local `player`.
    private _friendlyUnits = [];
    {_friendlyUnits append (units group _x)} forEach _players;
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
                [
                    "ENEMY", _friendly, getPosATL _friendly,
                    linearConversion [1.5, 4, _bestKnowledge, 0.5, 0.96, true],
                    "НАША_ГРУППА", "AI_KNOWLEDGE", linearConversion [1.5, 4, _bestKnowledge, 170, 55, true]
                ] call DRO2026_fnc_addContact;
                DRO2026_alertLevel = (DRO2026_alertLevel + 0.04) min 1;
            };
        };
    } forEach _friendlyUnits;

    private _now = time;
    {
        private _contact = _x;
        private _age = _now - (_contact getOrDefault ["lastSeen", _now]);
        private _confidence = _contact getOrDefault ["confidence", 0];
        private _bda = _contact getOrDefault ["bdaState", "DETECTED"];
        private _target = _contact getOrDefault ["target", objNull];
        private _oldBda = _bda;

        if (!isNull _target && {!alive _target} && {!(_bda in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])}) then {
            _bda = if ((_contact getOrDefault ["confidence", 0]) >= 0.82 && {"VISUAL" in (_contact getOrDefault ["sources", []])}) then {"CONFIRMED_DESTROYED"} else {"PROBABLY_DESTROYED"};
            _contact set ["bdaState", _bda];
            _contact set ["target", objNull];
            _contact set ["engagedAt", _now];
        };

        if (_age > 20) then {
            private _decayRate = _contact getOrDefault ["decayRate", 0.006];
            private _growth = _contact getOrDefault ["uncertaintyGrowth", 15];
            private _decayMultiplier = if (_bda in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]) then {0.30} else {1};
            private _newConfidence = (_confidence - (_decayRate * 5 * _decayMultiplier)) max 0;
            private _newUncertainty = ((_contact getOrDefault ["uncertaintyRadius", 80]) + (_growth * 5 * _decayMultiplier)) min 2200;
            private _velocity = _contact getOrDefault ["velocityEstimate", [0,0,0]];
            private _mean = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
            if (count _mean > 1 && {vectorMagnitude _velocity > 0.25} && {!(_bda in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])}) then {
                _mean = _mean vectorAdd (_velocity vectorMultiply 5);
                _contact set ["positionMean", _mean];
                _contact set ["position", +_mean];
            };
            _contact set ["confidence", _newConfidence];
            _contact set ["uncertaintyRadius", _newUncertainty];
        };

        if (_oldBda != _bda) then {
            ["BDA_UPDATED", createHashMapFromArray [["contactId", _contact getOrDefault ["id", ""]], ["from", _oldBda], ["to", _bda]], _contact getOrDefault ["id", ""]] call DRO2026_fnc_emitEvent;
        };
        if ((_contact getOrDefault ["owner", ""]) == "PLAYER") then {
            private _arguments = [
                _contact getOrDefault ["id", ""],
                _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]],
                _contact getOrDefault ["confidence", 0],
                _contact getOrDefault ["classification", _contact getOrDefault ["kind", "UNKNOWN"]],
                false,
                _contact getOrDefault ["uncertaintyRadius", 80],
                _contact getOrDefault ["bdaState", "DETECTED"]
            ];
            if (hasInterface) then {_arguments call DRO2026_fnc_syncContactMarker};
            _arguments remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
        };
    } forEach DRO2026_contacts;

    private _expired = DRO2026_contacts select {
        private _age = _now - (_x getOrDefault ["lastSeen", _now]);
        private _bda = _x getOrDefault ["bdaState", "DETECTED"];
        if (_bda in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]) then {
            _age >= 900
        } else {
            _age >= DRO2026_CONTACT_TTL || {(_x getOrDefault ["confidence", 0]) <= 0.04}
        }
    };
    {
        if ((_x getOrDefault ["owner", ""]) == "PLAYER") then {
            private _arguments = [_x getOrDefault ["id", ""], [], 0, "", true, 0, ""];
            if (hasInterface) then {_arguments call DRO2026_fnc_syncContactMarker};
            _arguments remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
        };
        ["CONTACT_EXPIRED", createHashMapFromArray [["contactId", _x getOrDefault ["id", ""]], ["bdaState", _x getOrDefault ["bdaState", ""]]], _x getOrDefault ["id", ""]] call DRO2026_fnc_emitEvent;
    } forEach _expired;
    DRO2026_contacts = DRO2026_contacts - _expired;

    sleep 5;
};