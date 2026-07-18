if (!isServer) exitWith {};
private _alertAnnounced = false;
while {true} do {
    if (DRO2026_alertLevel > 0.55 && {!_alertAnnounced}) then {["ALERT"] call DRO2026_fnc_hqVoice; _alertAnnounced = true};
    if (DRO2026_alertLevel < 0.35) then {_alertAnnounced = false};
    private _known = DRO2026_contacts select {(_x getOrDefault ["owner", ""]) == "ENEMY" && {(_x getOrDefault ["confidence", 0]) >= 0.58} && {(time - (_x getOrDefault ["lastSeen", 0])) < 260}};
    if (count _known > 0 && {DRO2026_alertLevel > 0.48}) then {
        private _contact = _known select ((count _known) - 1);
        [_contact] call DRO2026_fnc_orderEncirclement;
        private _nonStatic = DRO2026_managedGroups select {!isNull _x && {side _x == enemySide} && {!(_x getVariable ["DRO2026_static", false])} && {count units _x > 0}};
        if (count _nonStatic < 3 && {DRO2026_alertLevel > 0.68} && {DRO2026_fpsAverage >= DRO2026_MIN_FPS_FOR_REINFORCEMENTS} && {(DRO2026_resources getOrDefault ["enemyReinforcement", 0]) >= 10}) then {
            private _rear = ["ENEMY_TACTICAL_REAR"] call DRO2026_fnc_getTheaterNode;
            private _targetPos = _contact getOrDefault ["position", getPosATL player];
            private _spawn = [_rear, 150, 650, 5, 0, 0.45, 0, [], [_rear, _rear]] call BIS_fnc_findSafePos;
            if (_spawn isEqualTo [0,0,0]) then {_spawn = _rear};
            private _grp = [_spawn, 4, 6, 100, false] call DRO2026_fnc_spawnGuard;
            if (!isNull _grp) then {_grp setVariable ["DRO2026_static", false]; private _wp = _grp addWaypoint [_targetPos getPos [450, random 360], 50]; _wp setWaypointType "MOVE"; _wp setWaypointSpeed "FULL"; private _wp2 = _grp addWaypoint [_targetPos, 80]; _wp2 setWaypointType "SAD"; DRO2026_resources set ["enemyReinforcement", ((DRO2026_resources getOrDefault ["enemyReinforcement", 0]) - 10) max 0]};
        };
    };
    DRO2026_alertLevel = (DRO2026_alertLevel - 0.006) max 0.15;
    sleep 35;
};
