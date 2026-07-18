if (!isServer) exitWith {};
while {true} do {
    sleep (260 + random 220);
    if (DRO2026_alertLevel < 0.56 || {(count DRO2026_activeDrones) >= DRO2026_PHYSICAL_DRONE_LIMIT}) then {continue};
    private _contacts = DRO2026_contacts select {
        (_x getOrDefault ["owner", ""]) == "ENEMY" &&
        {(_x getOrDefault ["confidence", 0]) >= 0.68} &&
        {(time - (_x getOrDefault ["lastSeen", 0])) < 320}
    };
    if (count _contacts == 0) then {continue};
    private _targetPos = (selectRandom _contacts) getOrDefault ["position", getPosATL player];
    private _pool = DRO2026_assetRegistry getOrDefault ["AIR_EAST", []];
    if (count _pool == 0) then {continue};
    private _class = if (isClass (configFile >> "CfgVehicles" >> "RUS_VKS_su57") && {random 1 > 0.85}) then {"RUS_VKS_su57"} else {selectRandom _pool};
    private _spawn = _targetPos getPos [9000 + random 3000, 90 + (-10 + random 20)];
    private _lower = toLowerANSI _class;
    private _alt = if ((_lower find "su57") >= 0) then {780} else {if ((_lower find "mi8") >= 0) then {220} else {430}};
    _spawn set [2, _alt];
    private _air = createVehicle [_class, _spawn, [], 0, "FLY"];
    if (isNull _air) then {continue};
    private _grp = enemySide createVehicleCrew _air;
    if (!isNull _grp) then {
        [_grp, false] call DRO2026_fnc_registerManagedGroup;
        _grp setBehaviourStrong "CARELESS";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";
    };
    DRO2026_managedVehicles pushBackUnique _air;
    private _ingress = _targetPos getPos [1600, 90]; _ingress set [2, _alt];
    private _egress = _targetPos getPos [4200, 270]; _egress set [2, _alt + 40];
    if (!isNull (driver _air)) then {
        (driver _air) doMove _ingress;
        _air flyInHeight _alt;
    };
    private _doneStrike = false;
    private _timeout = time + 200;
    while {alive _air && {time < _timeout}} do {
        if (!_doneStrike && {_air distance2D _targetPos < 1350}) then {
            _doneStrike = true;
            for "_i" from 0 to 5 do {
                private _impact = _targetPos getPos [40 + random 160, random 360];
                [_impact] spawn {
                    params ["_impact"];
                    sleep (random 2.5);
                    createVehicle ["Bo_Mk82", _impact, [], 0, "CAN_COLLIDE"];
                };
            };
        };
        if (!isNull (driver _air) && {_doneStrike}) then {(driver _air) doMove _egress};
        sleep 1;
    };
    if (alive _air) then {deleteVehicleCrew _air; deleteVehicle _air};
};
