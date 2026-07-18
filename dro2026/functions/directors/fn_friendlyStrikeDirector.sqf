if (!isServer) exitWith {};
while {true} do {
    sleep 18;
    if ((time - DRO2026_lastFriendlyStrike) > (85 + random 95) && {(count DRO2026_activeDrones) < DRO2026_PHYSICAL_DRONE_LIMIT}) then {
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "PLAYER" &&
            {(_x getOrDefault ["confidence", 0]) >= 0.72} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 230} && {
                private _t = _x getOrDefault ["target", objNull];
                isNull _t || {alive _t}
            }
        };
        if (count _contacts > 0) then {
            private _contact = selectRandom _contacts;
            private _targetPos = _contact getOrDefault ["position", []];
            private _fpvSites = DRO2026_sites select {
                (_x getOrDefault ["type", ""]) == "FRIENDLY_FPV_SITE" && {
                    private _operator = _x getOrDefault ["operator", objNull];
                    !isNull _operator && {alive _operator}
                } && {
                    private _p = _x getOrDefault ["position", []];
                    count _p > 1 && {_p distance2D _targetPos <= 4800}
                }
            };
            private _strategicSites = DRO2026_sites select {
                (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
                    private _operator = _x getOrDefault ["operator", objNull];
                    !isNull _operator && {alive _operator}
                }
            };
            private _fpvStock = DRO2026_resources getOrDefault ["friendlyFPVStock", 0];
            private _longStock = DRO2026_resources getOrDefault ["friendlyLongRangeStock", 0];

            if (count _fpvSites > 0 && {_fpvStock > 0}) then {
                _fpvSites = [_fpvSites, [], {(_x getOrDefault ["position", [0,0,0]]) distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;
                private _site = _fpvSites select 0;
                private _origin = _site getOrDefault ["position", _targetPos];
                private _operator = _site getOrDefault ["operator", objNull];
                [_origin, _contact, playersSide, _operator] spawn DRO2026_fnc_launchFPVStrike;
                DRO2026_resources set ["friendlyFPVStock", (_fpvStock - 1) max 0];
                ["ACK", "Штаб: Контакт подтверждён. Союзный расчёт FPV приступил к работе."] call DRO2026_fnc_hqVoice;
                DRO2026_lastFriendlyStrike = time;
            } else {
                if (count _strategicSites > 0 && {_longStock > 0}) then {
                    private _site = _strategicSites select 0;
                    private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];
                    private _operator = _site getOrDefault ["operator", objNull];
                    private _preferFP5 = (DRO2026_friendlyFP5Used < 2) && {(DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) > 0} && {random 1 < 0.22};
                    [_origin, _contact, playersSide, _preferFP5, _operator] spawn DRO2026_fnc_launchLongRangeStrike;
                    DRO2026_resources set ["friendlyLongRangeStock", (_longStock - 1) max 0];
                    if (_preferFP5) then {
                        DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
                        DRO2026_resources set ["friendlyFP5Stock", ((DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) - 1) max 0];
                    };
                    ["ACK", "Штаб: Цель принята. По ней работает дальний ударный БПЛА."] call DRO2026_fnc_hqVoice;
                    DRO2026_lastFriendlyStrike = time;
                };
            };
        };
    };
};
