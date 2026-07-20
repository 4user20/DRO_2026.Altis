if (!isServer) exitWith {};
private _alertAnnounced = false;
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _now = time;
    if (DRO2026_alertLevel > 0.55 && {!_alertAnnounced}) then {["ALERT"] call DRO2026_fnc_hqVoice; _alertAnnounced = true};
    if (DRO2026_alertLevel < 0.35) then {_alertAnnounced = false};

    {
        private _edgeId = _x;
        private _edge = DRO2026_networkEdges get _edgeId;
        if (
            (_edge getOrDefault ["status", "OPEN"]) == "PAUSED" &&
            {_now >= (_edge getOrDefault ["pausedUntil", 1e12])}
        ) then {
            _edge set ["status", "OPEN"];
            _edge deleteAt "pausedUntil";
            _edge set ["lastUpdatedAt", _now];
            DRO2026_networkEdges set [_edgeId, _edge];
            ["ROUTE_RESUMED", createHashMapFromArray [["edgeId", _edgeId], ["risk", _edge getOrDefault ["risk", 0.12]]], "NODE_LOGISTICS_01"] call DRO2026_fnc_emitEvent;
        };
    } forEach keys DRO2026_networkEdges;

    private _intent = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _action = _intent getOrDefault ["action", ""];
    private _ready = count _intent == 0 || {_now >= (_intent getOrDefault ["earliestAt", 0]) && {_now <= (_intent getOrDefault ["expiresAt", _now])}};
    private _known = DRO2026_contacts select {
        (_x getOrDefault ["owner", ""]) == "ENEMY" &&
        {(_x getOrDefault ["confidence", 0]) >= 0.58} &&
        {(_now - (_x getOrDefault ["lastSeen", 0])) < 260} &&
        {[_x] call DRO2026_fnc_isLiveContactSubject}
    };
    private _contactId = _intent getOrDefault ["contactId", ""];
    if (_contactId != "") then {
        private _preferred = _known select {(_x getOrDefault ["id", ""]) == _contactId};
        if (count _preferred > 0) then {_known = _preferred};
    };

    if (_ready && {_action == "ROUTE_ADAPT"}) then {
        private _recent = (keys DRO2026_networkEdges) select {
            private _edge = DRO2026_networkEdges get _x;
            (_edge getOrDefault ["interdictionPressure", 0]) > 0
        };
        if (count _recent > 0) then {
            _recent = [_recent, [], {
                private _edge = DRO2026_networkEdges get _x;
                -((_edge getOrDefault ["risk", 0]) + ((_edge getOrDefault ["interdictionPressure", 0]) * 0.15))
            }, "ASCEND"] call BIS_fnc_sortBy;
            private _edgeId = _recent select 0;
            private _edge = DRO2026_networkEdges get _edgeId;
            private _risk = _edge getOrDefault ["risk", 0.12];
            private _pressure = _edge getOrDefault ["interdictionPressure", 0];
            private _delay = (_edge getOrDefault ["travelTime", 600]) * (1.35 + _risk);
            private _resumeAt = _now + _delay;
            if (_risk > 0.75) then {
                _edge set ["status", "PAUSED"];
                _edge set ["pausedUntil", _resumeAt];
            } else {
                _edge set ["status", "OPEN"];
                _edge deleteAt "pausedUntil";
            };
            _edge set ["nextDeliveryAt", _resumeAt];
            _edge set ["interdictionPressure", (_pressure - 0.5) max 0];
            _edge set ["escortLevel", ((_edge getOrDefault ["escortLevel", 0]) + 1) min 3];
            _edge set ["lastUpdatedAt", _now];
            DRO2026_networkEdges set [_edgeId, _edge];
            ["ROUTE_ADAPTED", createHashMapFromArray [["edgeId", _edgeId], ["risk", _risk], ["escortLevel", _edge get "escortLevel"], ["status", _edge get "status"], ["resumeAt", _resumeAt]], "NODE_LOGISTICS_01"] call DRO2026_fnc_emitEvent;
            _intent set ["status", "EXECUTED"];
            _intent set ["executedAt", _now];
            missionNamespace setVariable ["DRO2026_currentIntent", _intent];
        } else {
            _intent set ["status", "CANCELLED"];
            _intent set ["cancelReason", "NO_INTERDICTED_ROUTE"];
            missionNamespace setVariable ["DRO2026_currentIntent", _intent];
        };
    };

    if (count _known > 0 && {DRO2026_alertLevel > 0.48}) then {
        _known = [_known, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 3000))}, "ASCEND"] call BIS_fnc_sortBy;
        private _contact = _known select 0;
        [_contact] call DRO2026_fnc_orderEncirclement;

        if (_ready && {_action == "REINFORCE"}) then {
            private _nonStatic = DRO2026_managedGroups select {
                private _leader = leader _x;
                !isNull _x &&
                {!isNull _leader} &&
                {alive _leader} &&
                {side _x == enemySide} &&
                {!(_x getVariable ["DRO2026_static", false])} &&
                {({alive _x} count units _x) > 0}
            };
            private _hq = DRO2026_networkNodes getOrDefault ["NODE_ENEMY_HQ", createHashMap];
            private _hqStatus = _hq getOrDefault ["status", "ACTIVE"];
            private _stocks = _hq getOrDefault ["stocks", createHashMap];
            private _replacements = _stocks getOrDefault ["INFANTRY_REPLACEMENTS", 0];
            private _fuel = _stocks getOrDefault ["FUEL", 0];
            private _canSpawn = !(missionNamespace getVariable ["DRO2026_missionEnding", false]) && {
                count _hq > 0 && {!(_hqStatus in ["DESTROYED", "DISABLED", "CANCELLED"])}
            } && {
                count _nonStatic < 4
            } && {
                DRO2026_fpsAverage >= DRO2026_MIN_FPS_FOR_REINFORCEMENTS
            } && {
                _replacements >= 4 && {_fuel >= 2}
            } && {
                DRO2026_reinforcementWaves < DRO2026_MAX_REINFORCEMENT_WAVES
            };
            if (_canSpawn) then {
                private _rear = ["ENEMY_TACTICAL_REAR"] call DRO2026_fnc_getTheaterNode;
                private _targetPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", _rear]];
                private _uncertainty = _contact getOrDefault ["uncertaintyRadius", 100];
                _targetPos = _targetPos getPos [random (_uncertainty min 350), random 360];
                private _spawn = [_rear, 150, 650, 5, 0, 0.45, 0, [], [_rear, _rear]] call BIS_fnc_findSafePos;
                if (_spawn isEqualTo [0,0,0]) then {_spawn = _rear};
                private _group = [_spawn, 3, 4, 100, false] call DRO2026_fnc_spawnGuard;
                if (!isNull _group && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}) then {
                    _group setVariable ["DRO2026_static", false];
                    private _waypoint = _group addWaypoint [_targetPos getPos [450, random 360], 50];
                    _waypoint setWaypointType "MOVE";
                    _waypoint setWaypointSpeed "FULL";
                    private _search = _group addWaypoint [_targetPos, 80];
                    _search setWaypointType "SAD";
                    ["NODE_ENEMY_HQ", "INFANTRY_REPLACEMENTS", -4, "REINFORCE"] call DRO2026_fnc_changeNetworkNodeStock;
                    ["NODE_ENEMY_HQ", "FUEL", -2, "REINFORCE"] call DRO2026_fnc_changeNetworkNodeStock;
                    DRO2026_resources set ["enemyReinforcement", ((DRO2026_resources getOrDefault ["enemyReinforcement", 0]) - 10) max 0];
                    DRO2026_reinforcementWaves = DRO2026_reinforcementWaves + 1;
                    ["REINFORCEMENT_DISPATCHED", createHashMapFromArray [["contactId", _contact getOrDefault ["id", ""]], ["group", groupId _group], ["wave", DRO2026_reinforcementWaves]], "NODE_ENEMY_HQ"] call DRO2026_fnc_emitEvent;
                    _intent set ["status", "EXECUTED"];
                    _intent set ["executedAt", time];
                    missionNamespace setVariable ["DRO2026_currentIntent", _intent];
                } else {
                    if (!isNull _group) then {
                        {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
                        deleteGroup _group;
                    };
                    _intent set ["status", "CANCELLED"];
                    _intent set ["cancelReason", "MATERIALIZATION_FAILED_OR_MISSION_ENDING"];
                    missionNamespace setVariable ["DRO2026_currentIntent", _intent];
                };
            } else {
                _intent set ["status", "CANCELLED"];
                _intent set ["cancelReason", "NO_RESOURCES_OR_BUDGET"];
                missionNamespace setVariable ["DRO2026_currentIntent", _intent];
            };
        };
    };
    DRO2026_alertLevel = (DRO2026_alertLevel - 0.006) max 0.15;
    sleep 20;
};
