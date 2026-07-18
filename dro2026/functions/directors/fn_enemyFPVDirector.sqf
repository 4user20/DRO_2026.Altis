if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 12;
    private _cooldown = DRO2026_ENEMY_FPV_MIN_INTERVAL + random (DRO2026_ENEMY_FPV_MAX_INTERVAL - DRO2026_ENEMY_FPV_MIN_INTERVAL);
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];
    private _slots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
    if ((time - DRO2026_lastEnemyFPV) >= _cooldown && {DRO2026_alertLevel > 0.35} && {_stock > 0} && {_slots > 0}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= DRO2026_CONTACT_REQUIRED_FOR_FPV} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 190} && {
                private _t = _x getOrDefault ["target", objNull];
                isNull _t || {alive _t}
            }
        };
        if (count _contacts > 0) then {
            private _contact = selectRandom _contacts;
            private _targetPos = _contact getOrDefault ["position", []];
            private _sites = DRO2026_sites select {
                (_x getOrDefault ["type", ""]) in ["FPV_TEAM", "DRONE_SITE", "STRATEGIC_DRONE_SITE"] && {
                    private _operator = _x getOrDefault ["operator", objNull];
                    !isNull _operator && {alive _operator}
                } && {
                    private _p = _x getOrDefault ["position", []];
                    count _p > 1 && {_p distance2D _targetPos <= 4800}
                }
            };
            if (count _sites > 0) then {
                _sites = [_sites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
                private _site = _sites select 0;
                private _operator = _site getOrDefault ["operator", objNull];
                private _origin = _site getOrDefault ["position", getPosATL _operator];
                private _count = (if (DRO2026_alertLevel > 0.72 && {random 1 < 0.45}) then {2} else {1}) min _stock min _slots;
                DRO2026_resources set ["enemyDroneStock", (_stock - _count) max 0];
                DRO2026_lastEnemyFPV = time;
                [_origin, _contact, _operator, _count] spawn {
                    params ["_origin", "_contact", "_operator", "_count"];
                    for "_i" from 0 to (_count - 1) do {
                        private _launchOrigin = _origin getPos [4 + random 12, random 360];
                        [_launchOrigin, _contact, enemySide, _operator, false] spawn DRO2026_fnc_launchFPVStrike;
                        sleep (2 + random 3);
                    };
                };
                [format ["Вражеская FPV-группа запустила %1 аппарат(а) по контакту %2, удаление %3 м", _count, _contact getOrDefault ["kind", ""], round (_origin distance2D _targetPos)]] call DRO2026_fnc_log;
            };
        };
    };
};
