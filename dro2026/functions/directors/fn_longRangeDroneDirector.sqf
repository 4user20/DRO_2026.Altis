if (!isServer) exitWith {};
while {true} do {
    sleep 20;
    private _cooldown = DRO2026_LONG_RANGE_MIN_INTERVAL + random (DRO2026_LONG_RANGE_MAX_INTERVAL - DRO2026_LONG_RANGE_MIN_INTERVAL);
    private _stock = DRO2026_resources getOrDefault ["enemyLongRangeStock", 0];
    if (_stock > 0 && {(time - DRO2026_lastEnemyLongRange) >= _cooldown} && {DRO2026_alertLevel > 0.45} && {(count DRO2026_activeDrones) < DRO2026_PHYSICAL_DRONE_LIMIT}) then {
        private _contacts = DRO2026_contacts select {(_x getOrDefault ["owner", ""]) == "ENEMY" && {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE} && {(time - (_x getOrDefault ["lastSeen", 0])) < 330}};
        private _sites = DRO2026_sites select {(_x getOrDefault ["type", ""]) in ["STRATEGIC_DRONE_SITE", "DRONE_SITE"] && {private _operator = _x getOrDefault ["operator", objNull]; !isNull _operator && {alive _operator}}};
        if (count _contacts > 0 && {count _sites > 0}) then {
            private _contact = selectRandom _contacts;
            private _site = selectRandom _sites;
            private _operator = _site getOrDefault ["operator", objNull];
            private _origin = _site getOrDefault ["position", ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
            [_origin, _contact, enemySide, false, _operator] spawn DRO2026_fnc_launchLongRangeStrike;
            DRO2026_resources set ["enemyLongRangeStock", (_stock - 1) max 0];
            DRO2026_lastEnemyLongRange = time;
            [format ["Противник применил дальний БПЛА по подтверждённому контакту %1", _contact getOrDefault ["kind", ""]]] call DRO2026_fnc_log;
        };
    };
};
