if (!isServer) exitWith {};
while {true} do {
    sleep 12;
    private _cooldown = DRO2026_ENEMY_FPV_MIN_INTERVAL + random (DRO2026_ENEMY_FPV_MAX_INTERVAL - DRO2026_ENEMY_FPV_MIN_INTERVAL);
    if ((time - DRO2026_lastEnemyFPV) >= _cooldown && {DRO2026_alertLevel > 0.35} && {(DRO2026_resources getOrDefault ["enemyDroneStock", 0]) > 0} && {(count DRO2026_activeDrones) < DRO2026_PHYSICAL_DRONE_LIMIT}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" && {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} && {(time - (_x getOrDefault ["lastSeen", 0])) < 210} && {
                private _t = _x getOrDefault ["target", objNull]; isNull _t || {alive _t}
            }
        };
        if (count _contacts > 0) then {
            private _contact = selectRandom _contacts;
            private _targetPos = _contact getOrDefault ["position", []];
            private _sites = DRO2026_sites select {
                (_x getOrDefault ["type", ""]) in ["FPV_TEAM", "DRONE_SITE", "STRATEGIC_DRONE_SITE"] && {
                    private _operator = _x getOrDefault ["operator", objNull]; !isNull _operator && {alive _operator}
                } && {private _p = _x getOrDefault ["position", []]; count _p > 1 && {_p distance2D _targetPos <= 4800}}
            };
            if (count _sites > 0) then {
                _sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
                private _site = _sites select 0;
                private _operator = _site getOrDefault ["operator", objNull];
                private _origin = _site getOrDefault ["position", getPosATL _operator];
                [_origin, _contact, enemySide, _operator] spawn DRO2026_fnc_launchFPVStrike;
                DRO2026_resources set ["enemyDroneStock", ((DRO2026_resources getOrDefault ["enemyDroneStock", 0]) - 1) max 0];
                DRO2026_lastEnemyFPV = time;
                [format ["Вражеский FPV запущен по контакту %1 с площадки на удалении %2 м", _contact getOrDefault ["kind", ""], round (_origin distance2D _targetPos)]] call DRO2026_fnc_log;
            };
        };
    };
};
