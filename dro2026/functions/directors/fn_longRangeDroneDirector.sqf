if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 20;
    private _cooldown = DRO2026_LONG_RANGE_MIN_INTERVAL + random (DRO2026_LONG_RANGE_MAX_INTERVAL - DRO2026_LONG_RANGE_MIN_INTERVAL);
    private _stock = DRO2026_resources getOrDefault ["enemyLongRangeStock", 0];
    private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
    if (_stock > 0 && {_slots > 0} && {(time - DRO2026_lastEnemyLongRange) >= _cooldown} && {DRO2026_alertLevel > 0.45}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 300}
        };
        private _sites = DRO2026_sites select {
            (_x getOrDefault ["type", ""]) in ["STRATEGIC_DRONE_SITE", "DRONE_SITE"] && {
                private _operator = _x getOrDefault ["operator", objNull];
                !isNull _operator && {alive _operator}
            }
        };
        if (count _contacts > 0 && {count _sites > 0}) then {
            private _contact = selectRandom _contacts;
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

            DRO2026_resources set ["enemyLongRangeStock", (_stock - _count) max 0];
            DRO2026_lastEnemyLongRange = time;
            [_origin, _contact, _operator, _type, _count] spawn {
                params ["_origin", "_contact", "_operator", "_type", "_count"];
                for "_index" from 0 to (_count - 1) do {
                    private _copy = createHashMap;
                    {
                        _copy set [_x, _contact get _x];
                    } forEach keys _contact;
                    if (isNull (_contact getOrDefault ["target", objNull]) && {_count > 1}) then {
                        private _position = _contact getOrDefault ["position", [0,0,0]];
                        _copy set ["position", _position getPos [80 + random 300, random 360]];
                    };
                    [_origin, _copy, enemySide, false, _operator, _type, false, _index, _count] spawn DRO2026_fnc_launchLongRangeStrike;
                    sleep (3 + random 5);
                };
            };
            [format ["Противник запустил пакет дальних БПЛА: тип %1, количество %2", _type, _count]] call DRO2026_fnc_log;
        };
    };
};
