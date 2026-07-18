params ["_arty", "_positions", ["_taskName", ""], ["_marker", ""]];
if (isNull _arty) exitWith {};
waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {!alive _arty}};
if (!alive _arty) exitWith {};
private _shotsAtPosition = 0;
private _firstMission = true;

while {
    alive _arty && {
        (_taskName == "") || {(missionNamespace getVariable [format ["%1Completed", _taskName], 0]) == 0}
    }
} do {
    private _delay = if (_firstMission) then {18 + random 22} else {
        private _supplyFactor = linearConversion [0, 100, DRO2026_resources getOrDefault ["enemySupply", 0], 1.55, 0.78, true];
        (58 + random 65) * _supplyFactor
    };
    sleep _delay;
    _firstMission = false;

    if (!alive _arty) exitWith {};
    private _ammoPool = getArtilleryAmmo [_arty];
    if (count _ammoPool > 0 && {(DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0]) > 2}) then {
        private _candidatePositions = [];
        {
            private _p = _x getOrDefault ["position", []];
            if (count _p > 1) then {_candidatePositions pushBack _p};
        } forEach DRO2026_friendlyPositions;

        private _enemyContacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= 0.58} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 300}
        };
        {
            private _p = _x getOrDefault ["position", []];
            if (count _p > 1) then {_candidatePositions pushBack _p};
        } forEach _enemyContacts;

        if (alive player) then {_candidatePositions pushBack (getPosATL player)};
        private _solutions = [];
        {
            private _targetPos = _x;
            {
                if (_targetPos inRangeOfArtillery [[_arty], _x]) then {
                    _solutions pushBack [_targetPos, _x];
                };
            } forEach _ammoPool;
        } forEach _candidatePositions;

        if (count _solutions > 0) then {
            private _solution = selectRandom _solutions;
            _solution params ["_targetPos", "_mag"];
            private _rounds = 2 + floor random 3;
            _arty doArtilleryFire [_targetPos, _mag, _rounds];
            DRO2026_resources set ["enemyArtilleryAmmo", ((DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0]) - _rounds) max 0];
            _shotsAtPosition = _shotsAtPosition + 1;

            private _estimated = (getPosATL _arty) getPos [180 + random 420, random 360];
            if (_marker != "") then {
                _marker setMarkerPos _estimated;
                _marker setMarkerSize [360, 360];
                _marker setMarkerAlpha 0.72;
            };
            ["PLAYER", objNull, _estimated, 0.62, "ВЕРОЯТНАЯ АРТИЛЛЕРИЯ"] call DRO2026_fnc_addContact;
            [format ["Артиллерия выполнила огневую задачу: %1 выстр., цель %2 м", _rounds, round (_arty distance2D _targetPos)]] call DRO2026_fnc_log;
        } else {
            [format ["Артиллерия %1 не имеет решения по доступным союзным целям", typeOf _arty]] call DRO2026_fnc_log;
        };
    };

    if (_shotsAtPosition >= 2 && {canMove _arty} && {count _positions > 1} && {!isNull (driver _arty)}) then {
        private _alternatives = _positions select {_arty distance2D _x > 180};
        if (count _alternatives > 0) then {
            private _next = selectRandom _alternatives;
            private _group = group (driver _arty);
            while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
            private _wp = _group addWaypoint [_next, 25];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";
            private _moveDeadline = time + 210;
            waitUntil {
                sleep 3;
                !alive _arty || {!canMove _arty} || {_arty distance2D _next < 45} || {time > _moveDeadline}
            };
            _shotsAtPosition = 0;
            [format ["Артиллерия сменила позицию, остаток боезапаса %1%%", round (DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0])]] call DRO2026_fnc_log;
        };
    };
};
