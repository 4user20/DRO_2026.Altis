params ["_arty", "_positions", ["_taskName", ""], ["_marker", ""]];
if (!isServer || {isNull _arty}) exitWith {};
if (!local _arty) exitWith {
    ["ARTILLERY","LOCALITY_REJECTED",createHashMapFromArray [["class",typeOf _arty],["netId",netId _arty],["owner",owner _arty]],"ARTILLERY"] call DRO2026_fnc_logStructured;
};
waitUntil {
    sleep 1;
    missionNamespace getVariable ["playersReady", 0] == 1 ||
    {!alive _arty} ||
    {missionNamespace getVariable ["DRO2026_missionEnding", false]}
};
if (!alive _arty || {missionNamespace getVariable ["DRO2026_missionEnding", false]}) exitWith {};
private _shotsAtPosition = 0;
private _firstMission = true;

while {
    alive _arty &&
    {local _arty} &&
    {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} && {
        (_taskName == "") || {(missionNamespace getVariable [format ["%1Completed", _taskName], 0]) == 0}
    }
} do {
    private _delay = if (_firstMission) then {18 + random 22} else {
        private _supplyFactor = linearConversion [0, 100, DRO2026_resources getOrDefault ["enemySupply", 0], 1.55, 0.78, true];
        (58 + random 65) * _supplyFactor
    };
    sleep _delay;
    _firstMission = false;
    if (!alive _arty || {!local _arty} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}) exitWith {};

    private _intent = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _intentAction = _intent getOrDefault ["action", ""];
    private _networkReady = missionNamespace getVariable ["DRO2026_networkBuilt", false];
    private _intentReady = !_networkReady || {
        count _intent > 0 && {
            _intentAction == "ARTILLERY_FIRE" &&
            {time >= (_intent getOrDefault ["earliestAt", 0])} &&
            {time <= (_intent getOrDefault ["expiresAt", time])}
        }
    };
    if (!_intentReady) then {continue};

    private _ammoNode = DRO2026_networkNodes getOrDefault ["NODE_ARTILLERY_01", createHashMap];
    private _nodeStocks = _ammoNode getOrDefault ["stocks", createHashMap];
    private _nodeAmmo = _nodeStocks getOrDefault ["ARTILLERY_AMMO", DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0]];
    private _ammoPool = getArtilleryAmmo [_arty];
    if (count _ammoPool > 0 && {_nodeAmmo > 2}) then {
        private _intentContactId = _intent getOrDefault ["contactId", ""];
        private _enemyContacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["confidence", 0]) >= 0.58} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 300} &&
            {!((toUpperANSI (_x getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"])} &&
            {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])}
        };
        if (_intentContactId != "") then {
            private _preferred = _enemyContacts select {(_x getOrDefault ["id", ""]) == _intentContactId};
            if (count _preferred > 0) then {_enemyContacts = _preferred};
        };

        private _targetCandidates = [];
        {
            private _meanASL = _x getOrDefault ["positionASL",_x getOrDefault ["positionMean", _x getOrDefault ["position", []]]];
            if (count _meanASL > 1) then {
                private _uncertainty = _x getOrDefault ["uncertaintyRadius", 80];
                private _aimASL = _meanASL getPos [random (_uncertainty min 260), random 360];
                private _aimAGL = ASLToAGL _aimASL;
                _targetCandidates pushBack [_aimAGL, _x getOrDefault ["id", ""], _x getOrDefault ["confidence", 0], "CONTACT"];
            };
        } forEach _enemyContacts;

        private _phase = DRO2026_operationState getOrDefault ["phase", "RECON"];
        private _alert = DRO2026_operationState getOrDefault ["alertState", "GREEN"];
        if (count _targetCandidates == 0 && {_phase == "COUNTERATTACK"} && {_alert == "RED"}) then {
            {
                private _staticPos = _x getOrDefault ["position", []];
                if (count _staticPos > 1) then {
                    _targetCandidates pushBack [_staticPos getPos [80 + random 180, random 360], "STATIC_AREA", 0.45, "AREA_DENIAL"];
                };
            } forEach DRO2026_friendlyPositions;
        };

        private _solutions = [];
        {
            _x params ["_targetPos", "_contactId", "_confidence", "_targetKind"];
            {
                private _eta = _arty getArtilleryETA [_targetPos,_x];
                if (_eta >= 0 && {_targetPos inRangeOfArtillery [[_arty], _x]}) then {
                    _solutions pushBack [_targetPos, _x, _contactId, _confidence, _targetKind,_eta];
                };
            } forEach _ammoPool;
        } forEach _targetCandidates;

        if (count _solutions > 0) then {
            private _solution = selectRandom _solutions;
            _solution params ["_targetPos", "_mag", "_contactId", "_confidence", "_targetKind","_eta"];
            private _rounds = ((2 + floor random 3) min floor _nodeAmmo) max 1;
            if (_rounds > 0 && {local _arty}) then {
                _arty doArtilleryFire [_targetPos, _mag, _rounds];
                ["NODE_ARTILLERY_01", "ARTILLERY_AMMO", -_rounds, "FIRE_MISSION"] call DRO2026_fnc_changeNetworkNodeStock;
                private _remaining = ((_nodeAmmo - _rounds) max 0);
                DRO2026_resources set ["enemyArtilleryAmmo", _remaining];
                _shotsAtPosition = _shotsAtPosition + 1;

                private _fireMission = createHashMapFromArray [
                    ["observerContact", _contactId], ["targetAreaAGL", +_targetPos], ["ammoType", _mag],
                    ["rounds", _rounds], ["eta",_eta], ["priority", _confidence], ["targetKind", _targetKind], ["createdAt", time]
                ];
                ["FIRE_MISSION_EXECUTED", _fireMission, "NODE_ARTILLERY_01"] call DRO2026_fnc_emitEvent;

                private _estimated = (getPosATL _arty) getPos [180 + random 420, random 360];
                if (_marker != "") then {
                    _marker setMarkerPos _estimated;
                    _marker setMarkerSize [360, 360];
                    _marker setMarkerAlpha 0.72;
                };
                ["PLAYER", objNull, _estimated, 0.62, "ВЕРОЯТНАЯ АРТИЛЛЕРИЯ", "COUNTERBATTERY", 380, "NODE_ARTILLERY_01", 0.08] call DRO2026_fnc_addContact;
                [format ["Артиллерия выполнила огневую задачу: %1 выстр., источник %2, удаление %3 м", _rounds, _targetKind, round (_arty distance2D _targetPos)]] call DRO2026_fnc_log;
                _intent set ["status", "EXECUTED"];
                _intent set ["executedAt", time];
                missionNamespace setVariable ["DRO2026_currentIntent", _intent];
                ["INTENT_EXECUTED", createHashMapFromArray [["intentId", _intent getOrDefault ["id", ""]], ["action", "ARTILLERY_FIRE"]], "NODE_ARTILLERY_01"] call DRO2026_fnc_emitEvent;
            };
        } else {
            [format ["Артиллерия %1 не имеет решения по подтверждённым контактам", typeOf _arty]] call DRO2026_fnc_log;
        };
    };

    if (_shotsAtPosition >= 2 && {canMove _arty} && {count _positions > 1} && {!isNull (driver _arty)}) then {
        private _stocks = (DRO2026_networkNodes getOrDefault ["NODE_ARTILLERY_01", createHashMap]) getOrDefault ["stocks", createHashMap];
        private _fuel = _stocks getOrDefault ["FUEL", 0];
        private _alternatives = _positions select {_arty distance2D _x > 180};
        if (_fuel > 0 && {count _alternatives > 0}) then {
            private _next = selectRandom _alternatives;
            private _group = group (driver _arty);
            while {count waypoints _group > 0} do {deleteWaypoint ((waypoints _group) select 0)};
            private _wp = _group addWaypoint [_next, 25];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";
            ["NODE_ARTILLERY_01", "FUEL", -1, "SHOOT_AND_SCOOT"] call DRO2026_fnc_changeNetworkNodeStock;
            private _moveDeadline = time + 210;
            waitUntil {
                sleep 3;
                !alive _arty || {!canMove _arty} || {_arty distance2D _next < 45} ||
                {time > _moveDeadline} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}
            };
            _shotsAtPosition = 0;
            if (!isNull _arty) then {
                ["SITE_RELOCATED", createHashMapFromArray [["nodeId", "NODE_ARTILLERY_01"], ["position", getPosATL _arty]], "NODE_ARTILLERY_01"] call DRO2026_fnc_emitEvent;
            };
        };
    };
};
