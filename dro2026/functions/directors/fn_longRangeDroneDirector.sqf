if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 16;
    private _intent = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _intentAction = _intent getOrDefault ["action", ""];
    private _networkReady = missionNamespace getVariable ["DRO2026_networkBuilt", false];
    private _authorized = !_networkReady || {
        count _intent > 0 && {
            _intentAction == "LONG_RANGE_ATTACK" &&
            {time >= (_intent getOrDefault ["earliestAt", 0])} &&
            {time <= (_intent getOrDefault ["expiresAt", time])}
        }
    };
    if (!_authorized) then {continue};

    private _nodeId = "NODE_DRONE_REAR_01";
    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
    if (count _node > 0 && {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"]}) then {continue};
    private _stocks = _node getOrDefault ["stocks", createHashMap];
    private _airframes = _stocks getOrDefault ["LONG_RANGE_DRONES", DRO2026_resources getOrDefault ["enemyLongRangeStock", 0]];
    private _fuel = _stocks getOrDefault ["FUEL", _airframes];
    private _stock = _airframes min _fuel;
    private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
    private _cooldown = DRO2026_LONG_RANGE_MIN_INTERVAL + random (DRO2026_LONG_RANGE_MAX_INTERVAL - DRO2026_LONG_RANGE_MIN_INTERVAL);
    if (_stock > 0 && {_slots > 0} && {(time - DRO2026_lastEnemyLongRange) >= _cooldown} && {DRO2026_alertLevel > 0.45}) then {
        private _isLiveStrategicContact = {
            params ["_contact"];
            private _target = _contact getOrDefault ["target", objNull];
            if (!isNull _target) exitWith {alive _target};
            private _subjectId = _contact getOrDefault ["subjectId", ""];
            if (_subjectId == "") exitWith {false};

            if ((_subjectId find "PLAYER:") == 0) exitWith {
                private _uid = _subjectId select [7];
                (allPlayers findIf {
                    !(_x isKindOf "VirtualMan_F") &&
                    {!isNull _x} &&
                    {alive _x} &&
                    {getPlayerUID _x == _uid}
                }) >= 0
            };
            if ((_subjectId find "SUPPORT:") == 0) exitWith {
                private _netId = _subjectId select [8];
                private _object = objectFromNetId _netId;
                !isNull _object && {alive _object}
            };

            private _siteIndex = DRO2026_sites findIf {
                (_x getOrDefault ["id", ""]) == _subjectId ||
                {(_x getOrDefault ["networkNodeId", ""]) == _subjectId}
            };
            if (_siteIndex >= 0) exitWith {
                private _site = DRO2026_sites select _siteIndex;
                private _object = _site getOrDefault ["object", objNull];
                private _status = _site getOrDefault ["status", "ACTIVE"];
                !(_status in ["DESTROYED", "DISABLED"]) && {
                    isNull _object || {alive _object}
                }
            };

            private _positionIndex = DRO2026_friendlyPositions findIf {(_x getOrDefault ["id", ""]) == _subjectId};
            if (_positionIndex >= 0) exitWith {
                private _record = DRO2026_friendlyPositions select _positionIndex;
                private _object = _record getOrDefault ["object", objNull];
                isNull _object || {alive _object}
            };

            private _subjectNode = DRO2026_networkNodes getOrDefault [_subjectId, createHashMap];
            count _subjectNode > 0 && {!((_subjectNode getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"])}
        };

        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 300} &&
            {(_x getOrDefault ["subjectId", ""]) != ""} &&
            {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])} &&
            {[_x] call _isLiveStrategicContact}
        };
        private _intentContactId = _intent getOrDefault ["contactId", ""];
        if (_intentContactId != "") then {
            private _preferred = _contacts select {(_x getOrDefault ["id", ""]) == _intentContactId};
            if (count _preferred > 0) then {_contacts = _preferred};
        };
        private _sites = DRO2026_sites select {
            (_x getOrDefault ["networkNodeId", ""]) == _nodeId || {(_x getOrDefault ["type", ""]) in ["STRATEGIC_DRONE_SITE", "DRONE_SITE"]}
        };
        _sites = _sites select {
            private _operator = _x getOrDefault ["operator", objNull];
            !isNull _operator && {alive _operator}
        };
        if (count _contacts > 0 && {count _sites > 0}) then {
            _contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 3500))}, "ASCEND"] call BIS_fnc_sortBy;
            private _contact = _contacts select 0;
            if !([_contact] call _isLiveStrategicContact) then {continue};
            private _site = selectRandom _sites;
            private _operator = _site getOrDefault ["operator", objNull];
            private _origin = _site getOrDefault ["position", ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
            private _maxSalvo = (if (DRO2026_alertLevel > 0.78) then {DRO2026_MAX_ENEMY_LONG_RANGE_SALVO} else {2}) min DRO2026_MAX_ENEMY_LONG_RANGE_SALVO;
            private _count = (1 + floor random _maxSalvo) min _stock min _slots;
            private _type = "AUTO";
            private _enemyPool = DRO2026_assetRegistry getOrDefault [if (enemySide == west) then {"LONG_RANGE_WEST"} else {if (enemySide == resistance) then {"LONG_RANGE_GUER"} else {"LONG_RANGE_EAST"}}, []];
            private _classification = toUpperANSI (_contact getOrDefault ["classification", ""]);
            private _fixedStrategic = (_classification find "HQ") >= 0 || {(_classification find "ШТАБ") >= 0} || {(_classification find "AA") >= 0} || {(_classification find "ПВО") >= 0} || {(_classification find "LOGISTICS") >= 0} || {(_classification find "ЛОГИСТ") >= 0};
            private _hasShahed = (_enemyPool findIf {
                private _name = toLowerANSI _x;
                (_name find "shahed") >= 0 || {(_name find "geran") >= 0}
            }) >= 0;
            if (_hasShahed && {enemySide == east} && {_fixedStrategic}) then {_type = "SHAHED"};
            if ((_classification find "ARTILLERY") >= 0 || {(_classification find "АРТИЛ") >= 0} || {(_classification find "DRONE") >= 0} || {(_classification find "БПЛА") >= 0}) then {
                if ((_enemyPool findIf {(toLowerANSI _x find "bm35") >= 0}) >= 0) then {_type = "BM35"};
            };

            [_nodeId, "LONG_RANGE_DRONES", -_count, "LONG_RANGE_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
            [_nodeId, "FUEL", -_count, "LONG_RANGE_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
            DRO2026_resources set ["enemyLongRangeStock", ((_airframes - _count) max 0)];
            DRO2026_lastEnemyLongRange = time;
            [_origin, _contact, _operator, _type, _count, _nodeId] spawn {
                params ["_origin", "_contact", "_operator", "_type", "_count", "_nodeId"];
                for "_index" from 0 to (_count - 1) do {
                    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
                    private _abort =
                        (missionNamespace getVariable ["DRO2026_missionEnding", false]) ||
                        {!isNull _operator && {!alive _operator}} ||
                        {count _node > 0 && {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"]}};
                    if (_abort) exitWith {
                        private _unlaunched = _count - _index;
                        [_nodeId, "LONG_RANGE_DRONES", _unlaunched, "LONG_RANGE_SALVO_ABORT"] call DRO2026_fnc_changeNetworkNodeStock;
                        [_nodeId, "FUEL", _unlaunched, "LONG_RANGE_SALVO_ABORT"] call DRO2026_fnc_changeNetworkNodeStock;
                        DRO2026_resources set ["enemyLongRangeStock", (DRO2026_resources getOrDefault ["enemyLongRangeStock", 0]) + _unlaunched];
                        [format ["Enemy long-range salvo aborted before %1 remaining launches", _unlaunched]] call DRO2026_fnc_log;
                    };
                    private _copy = createHashMap;
                    {_copy set [_x, _contact get _x]} forEach keys _contact;
                    if (isNull (_contact getOrDefault ["target", objNull]) && {_count > 1}) then {
                        private _position = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", [0,0,0]]];
                        private _uncertainty = _contact getOrDefault ["uncertaintyRadius", 100];
                        _copy set ["position", _position getPos [random (_uncertainty min 350), random 360]];
                        _copy set ["positionMean", _copy get "position"];
                    };
                    [_origin, _copy, enemySide, false, _operator, _type, false, _index, _count, true, _nodeId] spawn DRO2026_fnc_launchLongRangeStrike;
                    sleep (4 + random 6);
                };
            };
            ["DRONE_LAUNCHED", createHashMapFromArray [["role", "LONG_RANGE"], ["type", _type], ["count", _count], ["contactId", _contact getOrDefault ["id", ""]], ["subjectId", _contact getOrDefault ["subjectId", ""]]], _nodeId] call DRO2026_fnc_emitEvent;
            _intent set ["status", "EXECUTED"];
            _intent set ["executedAt", time];
            missionNamespace setVariable ["DRO2026_currentIntent", _intent];
            ["INTENT_EXECUTED", createHashMapFromArray [["intentId", _intent getOrDefault ["id", ""]], ["action", "LONG_RANGE_ATTACK"]], _nodeId] call DRO2026_fnc_emitEvent;
            [format ["Тыловой drone-node запустил %1 x %2 по %3, остаток %4", _count, _type, _classification, (_airframes - _count) max 0]] call DRO2026_fnc_log;
        };
    };
};