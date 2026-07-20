if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 10;
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {};
    private _intent = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _intentAction = _intent getOrDefault ["action", ""];
    private _networkReady = missionNamespace getVariable ["DRO2026_networkBuilt", false];
    private _authorized = !_networkReady || {
        count _intent > 0 && {
            _intentAction == "FPV_ATTACK" &&
            {time >= (_intent getOrDefault ["earliestAt", 0])} &&
            {time <= (_intent getOrDefault ["expiresAt", time])}
        }
    };
    if (!_authorized) then {continue};

    private _nodeId = "NODE_FPV_FORWARD_01";
    private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
    if (count _node > 0 && {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"]}) then {continue};
    private _stocks = _node getOrDefault ["stocks", createHashMap];
    private _kits = _stocks getOrDefault ["FPV_KITS", DRO2026_resources getOrDefault ["enemyDroneStock", 0]];
    private _batteries = _stocks getOrDefault ["BATTERIES", _kits];
    private _stock = _kits min _batteries;
    private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
    private _cooldown = DRO2026_ENEMY_FPV_MIN_INTERVAL + random (DRO2026_ENEMY_FPV_MAX_INTERVAL - DRO2026_ENEMY_FPV_MIN_INTERVAL);
    if ((time - DRO2026_lastEnemyFPV) >= _cooldown && {DRO2026_alertLevel > 0.35} && {_stock > 0} && {_slots > 0}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 190} &&
            {[_x] call DRO2026_fnc_isLiveContactSubject}
        };
        private _intentContactId = _intent getOrDefault ["contactId", ""];
        if (_intentContactId != "") then {
            private _preferred = _contacts select {(_x getOrDefault ["id", ""]) == _intentContactId};
            if (count _preferred > 0) then {_contacts = _preferred};
        };
        if (count _contacts > 0) then {
            _contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 2500))}, "ASCEND"] call BIS_fnc_sortBy;
            private _contact = _contacts select 0;
            private _targetPos = _contact getOrDefault ["positionMean", _contact getOrDefault ["position", []]];
            private _sites = DRO2026_sites select {
                ((_x getOrDefault ["networkNodeId", ""]) == _nodeId || {(_x getOrDefault ["type", ""]) == "FPV_TEAM"}) && {
                    private _siteId = _x getOrDefault ["id", ""];
                    _siteId != "" && {[_siteId] call DRO2026_fnc_isSiteOperational}
                } && {
                    private _position = _x getOrDefault ["position", []];
                    count _position > 1 && {_position distance2D _targetPos <= 4800}
                }
            };
            if (count _sites > 0) then {
                _sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
                private _site = _sites select 0;
                private _siteId = _site getOrDefault ["id", ""];
                private _operator = _site getOrDefault ["operator", objNull];
                private _origin = _site getOrDefault ["position", getPosATL _operator];
                private _count = (if (DRO2026_alertLevel > 0.72 && {random 1 < 0.45}) then {2} else {1}) min _stock min _slots;
                [_nodeId, "FPV_KITS", -_count, "FPV_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
                [_nodeId, "BATTERIES", -_count, "FPV_ATTACK"] call DRO2026_fnc_changeNetworkNodeStock;
                DRO2026_resources set ["enemyDroneStock", ((_kits - _count) max 0)];
                DRO2026_lastEnemyFPV = time;
                [_origin, _contact, _operator, _count, _nodeId, _siteId] spawn {
                    params ["_origin", "_contact", "_operator", "_count", "_nodeId", "_siteId"];
                    for "_index" from 0 to (_count - 1) do {
                        private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
                        private _abort =
                            (missionNamespace getVariable ["DRO2026_missionEnding", false]) ||
                            {!isNull _operator && {!alive _operator}} ||
                            {!([_siteId] call DRO2026_fnc_isSiteOperational)} ||
                            {!([_contact] call DRO2026_fnc_isLiveContactSubject)} ||
                            {count _node > 0 && {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED", "RELOCATING"]}};
                        if (_abort) exitWith {
                            private _unlaunched = _count - _index;
                            [_nodeId, "FPV_KITS", _unlaunched, "FPV_SALVO_ABORT"] call DRO2026_fnc_changeNetworkNodeStock;
                            [_nodeId, "BATTERIES", _unlaunched, "FPV_SALVO_ABORT"] call DRO2026_fnc_changeNetworkNodeStock;
                            DRO2026_resources set ["enemyDroneStock", (DRO2026_resources getOrDefault ["enemyDroneStock", 0]) + _unlaunched];
                            [format ["Enemy FPV salvo aborted before %1 remaining launches", _unlaunched]] call DRO2026_fnc_log;
                        };
                        private _launchOrigin = _origin getPos [4 + random 12, random 360];
                        [_launchOrigin, _contact, enemySide, _operator, false, objNull, "", _nodeId, _siteId] spawn DRO2026_fnc_launchFPVStrike;
                        sleep (2 + random 3);
                    };
                };
                ["DRONE_LAUNCH_RESERVED", createHashMapFromArray [["role", "FPV"], ["count", _count], ["contactId", _contact getOrDefault ["id", ""]], ["siteId", _siteId]], _nodeId] call DRO2026_fnc_emitEvent;

                private _launches = (_node getOrDefault ["launchesSinceRelocation", 0]) + _count;
                private _threshold = _node getOrDefault ["relocationThreshold", 1 + floor random 3];
                _node set ["launchesSinceRelocation", _launches];
                _node set ["relocationThreshold", _threshold];
                DRO2026_networkNodes set [_nodeId, _node];
                if (_launches >= _threshold) then {
                    _node set ["launchesSinceRelocation", 0];
                    _node set ["relocationThreshold", 1 + floor random 3];
                    DRO2026_networkNodes set [_nodeId, _node];
                    [_nodeId] spawn DRO2026_fnc_relocateDroneTeam;
                };

                _intent set ["status", "EXECUTED"];
                _intent set ["executedAt", time];
                missionNamespace setVariable ["DRO2026_currentIntent", _intent];
                ["INTENT_EXECUTED", createHashMapFromArray [["intentId", _intent getOrDefault ["id", ""]], ["action", "FPV_ATTACK"]], _nodeId] call DRO2026_fnc_emitEvent;
                [format ["FPV-node зарезервировал %1 аппарат(а), остаток комплектов %2; relocation %3/%4", _count, (_kits - _count) max 0, _launches, _threshold]] call DRO2026_fnc_log;
            };
        };
    };
};
