if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep (105 + random 105);
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];
    if (_stock > 0 && {(count DRO2026_activeDrones) < DRO2026_PHYSICAL_DRONE_LIMIT}) then {
        private _sites = DRO2026_sites select {
            (_x getOrDefault ["type", ""]) in ["FPV_TEAM", "DRONE_SITE", "STRATEGIC_DRONE_SITE"] && {
                private _operator = _x getOrDefault ["operator", objNull];
                !isNull _operator && {alive _operator}
            }
        };
        if (count _sites > 0) then {
            private _site = selectRandom _sites;
            private _operator = _site getOrDefault ["operator", objNull];
            private _origin = _site getOrDefault ["position", ["ENEMY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode];
            private _searchCenter = if (count DRO2026_friendlyPositions > 0) then {
                (selectRandom DRO2026_friendlyPositions) getOrDefault ["position", getPosATL player]
            } else {
                getPosATL player
            };
            private _class = if (isClass (configFile >> "CfgVehicles" >> "RUS_VKS_forpostru") && {random 1 > 0.45}) then {"RUS_VKS_forpostru"} else {["ENEMY_ISR_UAV", "O_UAV_01_F"] call DRO2026_fnc_getRoleClass};
            if (!isClass (configFile >> "CfgVehicles" >> _class)) then {_class = "O_UAV_01_F"};
            private _isMicro = _class isKindOf "UAV_01_base_F";
            private _spawn = _origin vectorAdd [0, 0, if (_isMicro) then {75} else {210}];
            private _isForpost = (toLowerANSI _class find "forpost") >= 0;
            if (_isForpost) then {_spawn = _origin vectorAdd [0,0,280];};
            private _uav = createVehicle [_class, _spawn, [], 0, "FLY"];
            if (!isNull _uav) then {
                private _group = enemySide createVehicleCrew _uav;
                _uav flyInHeight (if (_isMicro) then {95} else {245});
                _uav setVariable ["DRO2026_operator", _operator];
                _operator setVariable ["DRO2026_activeUAV", _uav];
                DRO2026_activeDrones pushBack _uav;
                DRO2026_managedVehicles pushBackUnique _uav;
                DRO2026_resources set ["enemyDroneStock", (_stock - 1) max 0];
                if (!isNull _group) then {
                    _group setBehaviourStrong "CARELESS";
                    _group setCombatMode "BLUE";
                    _group setSpeedMode "NORMAL";
                };
                [_uav, _searchCenter, _isMicro, _operator] spawn {
                    params ["_uav", "_searchCenter", "_isMicro", "_operator"];
                    private _end = time + (if (_isMicro) then {320} else {480});
                    private _angle = random 360;
                    private _announced = false;
                    while {alive _uav && {time < _end} && {alive _operator}} do {
                        _angle = (_angle + 14 + random 17) mod 360;
                        private _baseRadius = if (_isMicro) then {360} else {720};
                        private _orbitRadius = (_baseRadius + (-70 + random 140)) max 180;
                        private _orbit = _searchCenter getPos [_orbitRadius, _angle];
                        _orbit set [2, (if (_isMicro) then {105} else {255}) + (-15 + random 30)];
                        if (!isNull (driver _uav)) then {(driver _uav) doMove _orbit};

                        if (!_announced && {((player knowsAbout _uav) > 1.1) || {player distance2D _uav < 900}}) then {
                            _announced = true;
                            ["ACK", "Штаб: В районе работает разведывательный БПЛА противника."] call DRO2026_fnc_hqVoice;
                        };

                        {
                            private _friendly = vehicle _x;
                            if (alive _friendly && {_friendly distance2D _uav < (if (_isMicro) then {900} else {1550})}) then {
                                private _to = aimPos _friendly;
                                if (_to isEqualTo [0,0,0]) then {_to = getPosASL _friendly vectorAdd [0,0,1.5]};
                                private _vis = _uav checkVisibility [eyePos _uav, _to];
                                if (_vis > 0.10) then {
                                    ["ENEMY", _friendly, getPosATL _friendly, (0.58 + (_vis * 0.32)) min 0.94, "БПЛА_РАЗВЕДКА"] call DRO2026_fnc_addContact;
                                    DRO2026_alertLevel = DRO2026_alertLevel max 0.54;
                                };
                            };
                        } forEach units (group player);

                        {
                            private _position = _x getOrDefault ["position", []];
                            if (count _position > 1 && {_uav distance2D _position < (if (_isMicro) then {950} else {1700})}) then {
                                ["ENEMY", objNull, _position, 0.76, _x getOrDefault ["type", "ОПОРНЫЙ_ПУНКТ"]] call DRO2026_fnc_addContact;
                                DRO2026_alertLevel = DRO2026_alertLevel max 0.50;
                            };
                        } forEach DRO2026_friendlyPositions;

                        {
                            private _sitePos = _x getOrDefault ["position", []];
                            if (count _sitePos > 1 && {_uav distance2D _sitePos < (if (_isMicro) then {1000} else {1850})}) then {
                                ["ENEMY", _x getOrDefault ["object", objNull], _sitePos, 0.78, _x getOrDefault ["type", "ОБЪЕКТ"]] call DRO2026_fnc_addContact;
                                DRO2026_alertLevel = DRO2026_alertLevel max 0.54;
                            };
                        } forEach (DRO2026_sites select {(_x getOrDefault ["type", ""]) in ["FRIENDLY_HQ", "FRIENDLY_DRONE_SITE", "FRIENDLY_FPV_SITE", "FRIENDLY_LAYERED_AA"]});
                        sleep 5;
                    };
                    if (alive _uav) then {
                        deleteVehicleCrew _uav;
                        deleteVehicle _uav;
                    } else {
                        DRO2026_alertLevel = (DRO2026_alertLevel + 0.08) min 1;
                    };
                };
            };
        };
    };
};
