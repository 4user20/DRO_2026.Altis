params ["_position", "_class", ["_quantity", 1]];
[] call DRO2026_fnc_initState;
if (!isClass (configFile >> "CfgVehicles" >> _class) || {!(_class isKindOf "Air")}) exitWith {systemChat format ["Штаб: авиационный класс %1 недоступен.", _class]};
_quantity = ((round _quantity) max 1) min 2;
private _sorties = DRO2026_resources getOrDefault ["friendlyAirSorties", 0];
if (_sorties <= 0) exitWith {systemChat "Штаб: авиационные вылеты на эту операцию исчерпаны."};
_quantity = _quantity min _sorties;

private _targets = [];
{
    private _target = _x getOrDefault ["target", objNull];
    private _pos = _x getOrDefault ["position", []];
    if (!isNull _target && {alive _target} && {count _pos > 1} && {_pos distance2D _position < 900}) then {_targets pushBackUnique _target};
} forEach (DRO2026_contacts select {(_x getOrDefault ["owner", ""]) == "PLAYER" && {(_x getOrDefault ["confidence", 0]) >= 0.62}});
if (count _targets == 0) then {
    {
        private _obj = _x getOrDefault ["object", objNull];
        private _pos = _x getOrDefault ["position", []];
        if (!isNull _obj && {alive _obj} && {count _pos > 1} && {_pos distance2D _position < 900}) then {_targets pushBackUnique _obj};
    } forEach DRO2026_sites;
};
if (count _targets == 0) exitWith {systemChat "Штаб: авиации нужна подтверждённая физическая цель в указанном районе."};
DRO2026_resources set ["friendlyAirSorties", (_sorties - _quantity) max 0];

[_class, _position, _targets, _quantity] spawn {
    params ["_class", "_position", "_targets", "_quantity"];
    for "_i" from 0 to (_quantity - 1) do {
        private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", 90];
        private _spawn = _position getPos [9000 + random 2500, (_axis + 180 + (-18 + random 36)) mod 360];
        private _isHeli = _class isKindOf "Helicopter";
        _spawn set [2, if (_isHeli) then {240} else {620 + random 180}];
        private _air = createVehicle [_class, _spawn, [], 0, "FLY"];
        if (!isNull _air) then {
            private _grp = playersSide createVehicleCrew _air;
            if (!isNull _grp) then {
                _grp setBehaviourStrong "COMBAT";
                _grp setCombatMode "RED";
                _grp setSpeedMode "FULL";
            };
            private _target = selectRandom _targets;
            if (!isNull (driver _air)) then {
                (driver _air) doTarget _target;
                (driver _air) doMove (getPosATL _target);
            };
            _air flyInHeight (if (_isHeli) then {120} else {420});
            [_air, _target, _position, _axis] spawn {
                params ["_air", "_target", "_position", "_axis"];
                private _deadline = time + 240;
                private _engagementIssued = false;
                while {alive _air && {time < _deadline}} do {
                    if (!_engagementIssued && {!isNull _target} && {alive _target} && {_air distance2D _target < 2400}) then {
                        _engagementIssued = true;
                        _air reveal [_target, 4];
                        _air fireAtTarget [_target];
                        if (!isNull (driver _air)) then {(driver _air) doTarget _target};
                    };
                    if (isNull _target || {!alive _target} || {_engagementIssued && {_air distance2D _position < 650}}) exitWith {};
                    sleep 1;
                };
                private _egress = _position getPos [9500, (_axis + 180) mod 360];
                _egress set [2, if (_air isKindOf "Helicopter") then {260} else {700}];
                if (!isNull (driver _air)) then {(driver _air) doMove _egress};
                private _exitDeadline = time + 150;
                waitUntil {sleep 2; !alive _air || {_air distance2D _position > 8000} || {time > _exitDeadline}};
                if (alive _air) then {deleteVehicleCrew _air; deleteVehicle _air};
            };
        };
        sleep (8 + random 8);
    };
};
["ACK", format ["Штаб: авиационная поддержка подтверждена, вылетов %1.", _quantity]] call DRO2026_fnc_hqVoice;
