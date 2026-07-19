if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 16;
    private _intent = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _intentAction = _intent getOrDefault ["action", ""];
    private _authorized = count _intent == 0 || {
        _intentAction == "LONG_RANGE_ATTACK" && {time >= (_intent getOrDefault ["earliestAt", 0])} && {time <= (_intent getOrDefault ["expiresAt", time])}
    };
    if (!_authorized && {missionNamespace getVariable ["DRO2026_networkBuilt", false]}) then {continue};

    private _node = DRO2026_networkNodes getOrDefault ["NODE_DRONE_REAR_01", createHashMap];
    if (count _node > 0 && {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"]}) then {continue};
    private _stocks = _node getOrDefault ["stocks", createHashMap];
    private _airframes = _stocks getOrDefault ["LONG_RANGE_DRONES", DRO2026_resources getOrDefault ["enemyLongRangeStock", 0]];
    private _fuel = _stocks getOrDefault ["FUEL", _airframes];
    private _stock = _airframes min _fuel;
    private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
    private _cooldown = DRO2026_LONG_RANGE_MIN_INTERVAL + random (DRO2026_LONG_RANGE_MAX_INTERVAL - DRO2026_LONG_RANGE_MIN_INTERVAL);
    if (_stock > 0 && {_slots > 0} && {(time - DRO2026_lastEnemyLongRange) >= _cooldown} && {DRO2026_alertLevel > 0.45}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 300} &&
            {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])}
        };
        private _intentContactId = _intent getOrDefault ["contactId", ""];
        if (_intentContactId != "") then {
            private _preferred = _contacts select {(_x getOrDefault ["id", ""]) == _intentContactId};
            if (count _preferred > 0) then {_contacts = _preferred};
        };
        private _sites = DRO2026_sites select {
            (_x getOrDefault ["networkNodeId", ""]) == "NODE_DRONE_REAR_01" || {(_x getOrDefault ["type", ""]) in ["STRATEGIC_DRONE_SITE", "DRONE_SITE"]}
        };
        _sites = _sites select {
            private _operator = _x getOrDefault ["operator", objNull];
            !isNull _operator && {alive _operator}
        };
        if (count _contacts > 0 && {count _sites > 0}) then {
            _contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 3500))}, "ASCEND"] call BIS_fnc_sortBy;
            private _contact = _contacts select 0;
            private _site = selectRandom _sites;
            private _operator = _site getOrDefault ["operator", objNull];
            private _origin = _site getOrDefault ["position", ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
            private _maxSalvo = if (DRO2026_alertLevel > 0.78) then {5} else {2};
            private _count = (1 + floor random _maxSalvo) min _stock min _slots;
            private _type = "AUTO";
            private _enemyPool = DRO2026_assetRegistry getOrDefault [if (enemySide == west) then {"LONG_RANGE_WEST"} else {"LONG_RANGE_EAST"}, []];
            private _hasShahed = (_enemyPool findIf {
                private _name = toLowerANSI _x;
                (_name find "shahed") >= 0 || {(_name find "geran") >= 0}
            }) >= 0;
            if (_hasShahed && {enemySide == east} && {random 1 < 0.72}) then {_type = "SHAHED"};

            ["NODE_DRONE_REAR_01", "LONG_RANGE_DRONES", -_count, "LONG_RANGE_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
            ["NODE_DRONE_REAR_01", "FUEL", -_count, "LONG_RANGE_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
            DRO2026_resources set ["enemyLongRangeStock", ((_airframes - _count) max 0)];
            DRO2026_lastEnemyLongRange = time;
            [_origin, _contact, _operator, _type, _count] spawn {
                params ["_origin", "_contact", "_operator", "_type", "_count"];
                for "_index" from 0 to (_count - 1) do {
                    private _copy = createHashMap;
                    {_copy set [_x, _contact get _x]} forEach keys _contact;
                    if (isNull (_contact getOrDefault ["target", objNull]) && {_count > 1}) then {
                        private _position = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", [0,0,0]]];
                        private _uncertainty = _contact getOrDefault ["uncertaintyRadius", 100];
                        _copy set ["position", _position getPos [random (_uncertainty min 350), random 360]];
                        _copy set ["positionMean", _copy get "position"];
                    };
                    [_origin, _copy, enemySide, false, _operator, _type, false, _index, _count] spawn DRO2026_fnc_launchLongRangeStrike;
                    sleep (3 + random 5);
                };
            };
            ["DRONE_LAUNCHED", createHashMapFromArray [["role", "LONG_RANGE"], ["type", _type], ["count", _count], ["contactId", _contact getOrDefault ["id", ""]]], "NODE_DRONE_REAR_01"] call DRO2026_fnc_emitEvent;
            if (_intentAction == "LONG_RANGE_ATTACK") then {
                _intent set ["status", "EXECUTED"];
                _intent set ["executedAt", time];
                missionNamespace setVariable ["DRO2026_currentIntent", _intent];
                ["INTENT_EXECUTED", createHashMapFromArray [["intentId", _intent getOrDefault ["id", ""]], ["action", "LONG_RANGE_ATTACK"]], "NODE_DRONE_REAR_01"] call DRO2026_fnc_emitEvent;
            };
            [format ["Тыловой drone-node запустил %1 x %2, остаток %3", _count, _type, (_airframes - _count) max 0]] call DRO2026_fnc_log;
        };
    };
};