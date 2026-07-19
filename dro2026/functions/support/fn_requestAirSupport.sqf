params ["_position", "_class", ["_quantity", 1], ["_requester", objNull]];

if (!isServer) exitWith {
    [player, "AIR", [_position, _class, _quantity]] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
};
[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: авиационная поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};

private _allowedClasses = DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []];
if !(_class in _allowedClasses) exitWith {
    [format ["Штаб: авиационный класс %1 не входит в реестр выбранной фракции.", _class], _requester] call DRO2026_fnc_supportMessage;
};
if (!isClass (configFile >> "CfgVehicles" >> _class) || {!(_class isKindOf "Air")}) exitWith {
    [format ["Штаб: авиационный класс %1 недоступен.", _class], _requester] call DRO2026_fnc_supportMessage;
};
if (time < DRO2026_supportFireLockUntil || {DRO2026_activeHeavySupport >= DRO2026_MAX_CONCURRENT_HEAVY_SUPPORT}) exitWith {
    [format ["Штаб: тяжёлый огневой канал занят. Ожидайте %1 сек.", ceil ((DRO2026_supportFireLockUntil - time) max 1)], _requester] call DRO2026_fnc_supportMessage;
};

private _airWindow = [_position, playersSide] call DRO2026_fnc_getAirWindow;
private _windowState = _airWindow getOrDefault ["state", "CLOSED"];
if (_windowState == "CLOSED") exitWith {
    [format ["Штаб: воздушное окно закрыто. Причины: %1", (_airWindow getOrDefault ["reasons", []]) joinString "; "], _requester] call DRO2026_fnc_supportMessage;
};

_quantity = ((round _quantity) max 1) min 2;
if (_windowState == "CONTESTED") then {_quantity = 1};
private _sorties = DRO2026_resources getOrDefault ["friendlyAirSorties", 0];
if (_sorties <= 0) exitWith {["Штаб: авиационные вылеты на эту операцию исчерпаны.", _requester] call DRO2026_fnc_supportMessage};
_quantity = _quantity min _sorties;

private _isHostileTarget = {
    params ["_target"];
    if (isNull _target || {!alive _target}) exitWith {false};
    private _targetSide = side _target;
    if (_target isKindOf "Man") then {_targetSide = side (group _target)};
    if (count crew _target > 0) then {_targetSide = side (group ((crew _target) select 0))};
    _targetSide == enemySide
};
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.72} &&
    {(_x getOrDefault ["uncertaintyRadius", 9999]) <= DRO2026_MAX_CONTACT_UNCERTAINTY_FOR_CAS} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 180} &&
    {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])} &&
    {(_x getOrDefault ["positionMean", _x getOrDefault ["position", [0,0,0]]]) distance2D _position < 750}
};
private _targets = [];
{
    private _target = _x getOrDefault ["target", objNull];
    if ([_target] call _isHostileTarget) then {_targets pushBackUnique [_target, _x getOrDefault ["id", ""], _x getOrDefault ["confidence", 0]]};
} forEach _contacts;
if (count _targets == 0) then {
    {
        private _site = _x;
        private _nodeId = _site getOrDefault ["networkNodeId", ""];
        private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
        private _known = (_node getOrDefault ["knownByPlayer", "UNKNOWN"]) in ["CONFIRMED", "TRACKED"];
        private _object = _site getOrDefault ["object", objNull];
        private _sitePosition = _site getOrDefault ["position", []];
        if (_known && {[_object] call _isHostileTarget} && {count _sitePosition > 1} && {_sitePosition distance2D _position < 650}) then {
            _targets pushBackUnique [_object, format ["NODE:%1", _nodeId], 0.84];
        };
    } forEach DRO2026_sites;
};
if (count _targets == 0) exitWith {
    ["Штаб: авиации нужна свежая подтверждённая физическая цель с приемлемой точностью координат.", _requester] call DRO2026_fnc_supportMessage;
};

private _missionId = format ["AIR_%1_%2", floor diag_tickTime, floor random 1000000];
["SUPPORT_REQUESTED", createHashMapFromArray [["missionId", _missionId], ["type", "AIR"], ["class", _class], ["window", _windowState], ["quantity", _quantity]], _missionId] call DRO2026_fnc_emitEvent;
DRO2026_resources set ["friendlyAirSorties", (_sorties - _quantity) max 0];
DRO2026_supportFireLockUntil = time + DRO2026_SUPPORT_HEAVY_FIRE_SPACING;
DRO2026_activeHeavySupport = DRO2026_activeHeavySupport + 1;
[_missionId, _class, _position, _targets, _quantity, _requester] spawn {
    params ["_missionId", "_class", "_position", "_targets", "_quantity", "_requester"];
    private _missionAircraft = [];
    for "_index" from 0 to (_quantity - 1) do {
        private _axis = DRO2026_theaterLayout getOrDefault ["AXIS", DRO2026_theaterNodes getOrDefault ["AXIS", 90]];
        private _spawn = _position getPos [9000 + random 2500, (_axis + 180 + (-18 + random 36)) mod 360];
        private _isHelicopter = _class isKindOf "Helicopter";
        _spawn set [2, if (_isHelicopter) then {240} else {620 + random 180}];
        private _spawnDirection = _spawn getDir _position;
        private _aircraft = createVehicle [_class, _spawn, [], 0, "FLY"];
        if (isNull _aircraft) then {
            DRO2026_resources set ["friendlyAirSorties", (DRO2026_resources getOrDefault ["friendlyAirSorties", 0]) + 1];
            ["Штаб: борт не смог выйти на задачу; вылет возвращён в резерв.", _requester] call DRO2026_fnc_supportMessage;
            ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", "ABORTED"], ["reason", "SPAWN_FAILED"]], _missionId] call DRO2026_fnc_emitEvent;
        } else {
            _aircraft setDir _spawnDirection;
            _aircraft setPosATL _spawn;
            private _group = playersSide createVehicleCrew _aircraft;
            if (isNull _group || {isNull (driver _aircraft)}) then {
                deleteVehicleCrew _aircraft;
                deleteVehicle _aircraft;
                if (!isNull _group) then {deleteGroup _group};
                DRO2026_resources set ["friendlyAirSorties", (DRO2026_resources getOrDefault ["friendlyAirSorties", 0]) + 1];
                ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", "ABORTED"], ["reason", "NO_CREW"]], _missionId] call DRO2026_fnc_emitEvent;
            } else {
                private _initialSpeed = if (_isHelicopter) then {38} else {145};
                _aircraft setVelocity [sin _spawnDirection * _initialSpeed, cos _spawnDirection * _initialSpeed, 0];
                _missionAircraft pushBack _aircraft;
                _aircraft setVariable ["DRO2026_airMissionId", _missionId, true];
                [_group, false] call DRO2026_fnc_registerManagedGroup;
                DRO2026_managedVehicles pushBackUnique _aircraft;
                _group setBehaviourStrong "COMBAT";
                _group setCombatMode "RED";
                _group setSpeedMode "FULL";
                private _targetRecord = selectRandom _targets;
                _targetRecord params ["_target", "_contactId", "_targetConfidence"];
                _aircraft reveal [_target, 4];
                (driver _aircraft) doTarget _target;
                (driver _aircraft) doMove (getPosATL _target);
                _aircraft flyInHeight (if (_isHelicopter) then {120} else {420});
                ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", "INBOUND"], ["contactId", _contactId]], _missionId] call DRO2026_fnc_emitEvent;
                [_missionId, _aircraft, _target, _contactId, _position, _axis, _group] spawn {
                    params ["_missionId", "_aircraft", "_target", "_contactId", "_position", "_axis", "_group"];
                    private _deadline = time + 240;
                    private _engagementIssued = false;
                    private _lastFireOrder = -10;
                    private _abortReason = "";
                    while {alive _aircraft && {time < _deadline} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
                        if (isNull _target || {!alive _target}) exitWith {_abortReason = "TARGET_LOST"};
                        private _window = [getPosATL _target, playersSide] call DRO2026_fnc_getAirWindow;
                        if ((_window getOrDefault ["state", "CLOSED"]) == "CLOSED") exitWith {
                            _abortReason = if (_window getOrDefault ["civiliansClose", false]) then {"CIVILIAN_RISK"} else {
                                if (_window getOrDefault ["friendliesClose", false]) then {"FRIENDLIES_CLOSE"} else {"AA_ACTIVE"}
                            };
                        };
                        _aircraft reveal [_target, 4];
                        if (!isNull (driver _aircraft)) then {
                            (driver _aircraft) doTarget _target;
                            if (_aircraft distance2D _target < 2600 && {(time - _lastFireOrder) > 6}) then {
                                _lastFireOrder = time;
                                _engagementIssued = true;
                                (driver _aircraft) doFire _target;
                                private _gunner = gunner _aircraft;
                                if (!isNull _gunner && {_gunner != driver _aircraft}) then {
                                    _gunner doTarget _target;
                                    _gunner doFire _target;
                                };
                                ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", "ATTACKING"], ["contactId", _contactId]], _missionId] call DRO2026_fnc_emitEvent;
                            };
                        };
                        sleep 1.5;
                    };
                    private _state = if (_abortReason != "") then {"ABORTED"} else {if (_engagementIssued) then {"EGRESS"} else {"ABORTED"}};
                    ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", _state], ["reason", _abortReason]], _missionId] call DRO2026_fnc_emitEvent;
                    private _egress = _position getPos [9500, (_axis + 180) mod 360];
                    _egress set [2, if (_aircraft isKindOf "Helicopter") then {260} else {700}];
                    if (!isNull (driver _aircraft)) then {(driver _aircraft) doMove _egress};
                    private _exitDeadline = time + 150;
                    waitUntil {sleep 2; !alive _aircraft || {_aircraft distance2D _position > 8000} || {time > _exitDeadline} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
                    if (!isNull _aircraft) then {
                        deleteVehicleCrew _aircraft;
                        if (alive _aircraft) then {deleteVehicle _aircraft};
                    };
                    if (!isNull _group) then {deleteGroup _group};
                    ["AIR_MISSION_STATE_CHANGED", createHashMapFromArray [["missionId", _missionId], ["state", "COMPLETE"], ["reason", _abortReason]], _missionId] call DRO2026_fnc_emitEvent;
                };
            };
        };
        sleep (10 + random 10);
    };
    private _releaseAt = time + 300;
    waitUntil {
        sleep 3;
        ({!isNull _x && {alive _x}} count _missionAircraft) == 0 || {time > _releaseAt} || {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    DRO2026_activeHeavySupport = (DRO2026_activeHeavySupport - 1) max 0;
};
[
    "ACK",
    format ["Штаб: авиационная поддержка подтверждена. Борт %1, окно %2, вылетов %3.", getText (configFile >> "CfgVehicles" >> _class >> "displayName"), _windowState, _quantity],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;