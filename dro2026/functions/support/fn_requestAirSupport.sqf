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

_quantity = ((round _quantity) max 1) min 2;
private _sorties = DRO2026_resources getOrDefault ["friendlyAirSorties", 0];
if (_sorties <= 0) exitWith {
    ["Штаб: авиационные вылеты на эту операцию исчерпаны.", _requester] call DRO2026_fnc_supportMessage;
};
_quantity = _quantity min _sorties;

private _isHostileTarget = {
    params ["_target"];
    if (isNull _target || {!alive _target}) exitWith {false};
    private _targetSide = side _target;
    if (_target isKindOf "Man") then {_targetSide = side (group _target)};
    if (count crew _target > 0) then {_targetSide = side (group ((crew _target) select 0))};
    _targetSide == enemySide
};

private _targets = [];
{
    private _target = _x getOrDefault ["target", objNull];
    private _targetPosition = _x getOrDefault ["position", []];
    if ([_target] call _isHostileTarget && {count _targetPosition > 1} && {_targetPosition distance2D _position < 900}) then {
        _targets pushBackUnique _target;
    };
} forEach (DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.62} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 240}
});

if (count _targets == 0) then {
    private _enemySiteTypes = [
        "ENEMY_HQ", "STRATEGIC_DRONE_SITE", "FPV_TEAM", "ARTILLERY_SITE",
        "AIR_DEFENCE_SITE", "ENEMY_LAYERED_AA", "CONVOY", "LOGISTICS_RUN",
        "LOGISTICS_HUB", "EW_SITE", "DRONE_SITE"
    ];
    {
        private _object = _x getOrDefault ["object", objNull];
        private _sitePosition = _x getOrDefault ["position", []];
        if ((_x getOrDefault ["type", ""]) in _enemySiteTypes &&
            {[_object] call _isHostileTarget} &&
            {count _sitePosition > 1} &&
            {_sitePosition distance2D _position < 900}) then {
            _targets pushBackUnique _object;
        };
    } forEach DRO2026_sites;
};
if (count _targets == 0) exitWith {
    ["Штаб: авиации нужна свежая подтверждённая физическая цель противника в указанном районе.", _requester] call DRO2026_fnc_supportMessage;
};

DRO2026_resources set ["friendlyAirSorties", (_sorties - _quantity) max 0];
[_class, _position, _targets, _quantity, _requester] spawn {
    params ["_class", "_position", "_targets", "_quantity", "_requester"];
    for "_index" from 0 to (_quantity - 1) do {
        private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", 90];
        private _spawn = _position getPos [9000 + random 2500, (_axis + 180 + (-18 + random 36)) mod 360];
        private _isHelicopter = _class isKindOf "Helicopter";
        _spawn set [2, if (_isHelicopter) then {240} else {620 + random 180}];
        private _aircraft = createVehicle [_class, _spawn, [], 0, "FLY"];
        if (isNull _aircraft) then {
            DRO2026_resources set ["friendlyAirSorties", (DRO2026_resources getOrDefault ["friendlyAirSorties", 0]) + 1];
            ["Штаб: борт не смог выйти на задачу; вылет возвращён в резерв.", _requester] call DRO2026_fnc_supportMessage;
        } else {
            private _group = playersSide createVehicleCrew _aircraft;
            if (isNull _group || {isNull driver _aircraft}) then {
                deleteVehicleCrew _aircraft;
                deleteVehicle _aircraft;
                DRO2026_resources set ["friendlyAirSorties", (DRO2026_resources getOrDefault ["friendlyAirSorties", 0]) + 1];
                ["Штаб: для борта не найден совместимый экипаж; вылет возвращён в резерв.", _requester] call DRO2026_fnc_supportMessage;
            } else {
                [_group, false] call DRO2026_fnc_registerManagedGroup;
                DRO2026_managedVehicles pushBackUnique _aircraft;
                _group setBehaviourStrong "COMBAT";
                _group setCombatMode "RED";
                _group setSpeedMode "FULL";
                private _target = selectRandom _targets;
                _aircraft reveal [_target, 4];
                (driver _aircraft) doTarget _target;
                (driver _aircraft) doMove (getPosATL _target);
                _aircraft flyInHeight (if (_isHelicopter) then {120} else {420});
                [_aircraft, _target, _position, _axis] spawn {
                    params ["_aircraft", "_target", "_position", "_axis"];
                    private _deadline = time + 240;
                    private _engagementIssued = false;
                    private _lastFireOrder = -10;
                    while {
                        alive _aircraft &&
                        {time < _deadline} &&
                        {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}
                    } do {
                        if (!isNull _target && {alive _target}) then {
                            _aircraft reveal [_target, 4];
                            if (!isNull driver _aircraft) then {
                                (driver _aircraft) doTarget _target;
                                if (_aircraft distance2D _target < 2600 && {(time - _lastFireOrder) > 4}) then {
                                    _lastFireOrder = time;
                                    _engagementIssued = true;
                                    (driver _aircraft) doFire _target;
                                };
                            };
                        };
                        if (isNull _target || {!alive _target}) exitWith {};
                        sleep 1;
                    };
                    private _egress = _position getPos [9500, (_axis + 180) mod 360];
                    _egress set [2, if (_aircraft isKindOf "Helicopter") then {260} else {700}];
                    if (!isNull driver _aircraft) then {(driver _aircraft) doMove _egress};
                    private _exitDeadline = time + 150;
                    waitUntil {
                        sleep 2;
                        !alive _aircraft ||
                        {_aircraft distance2D _position > 8000} ||
                        {time > _exitDeadline} ||
                        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
                    };
                    if (alive _aircraft) then {
                        deleteVehicleCrew _aircraft;
                        deleteVehicle _aircraft;
                    };
                };
            };
        };
        sleep (8 + random 8);
    };
};
[
    "ACK",
    format ["Штаб: авиационная поддержка подтверждена, вылетов %1.", _quantity],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;