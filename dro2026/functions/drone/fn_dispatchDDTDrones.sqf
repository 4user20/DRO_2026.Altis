params [["_maxLaunches", 3]];
if (!isServer) exitWith {0};
if !(missionNamespace getVariable ["DRO2026_ddtConfigured", false]) exitWith {0};
if !(missionNamespace getVariable ["ddtReady", false]) exitWith {0};
if (isNil "DDT_fnc_GroupDeployUAV") exitWith {0};

private _ownedSides = missionNamespace getVariable ["DRO2026_ddtDeploySides", []];
private _behaviours = missionNamespace getVariable ["ddtDeployBehaviour", ["SAFE", "AWARE", "COMBAT"]];
private _attackRange = missionNamespace getVariable ["ddtAttackRangeFPV", 2500];
private _bomberRange = missionNamespace getVariable ["ddtAttackRangeBomber", 1800];
private _cooldown = missionNamespace getVariable ["ddtCooldownValue", 180];
private _launched = 0;

{
    private _group = _x;
    if (_launched >= _maxLaunches) exitWith {};
    if (!isNull _group && {(side _group) in _ownedSides} && {_group getVariable ["DRO2026_droneLoadoutAssigned", false]} &&
        {!(_group getVariable ["ddtExclude", false])} && {(units _group) findIf {isPlayer _x} < 0} &&
        {alive leader _group} && {simulationEnabled leader _group} && {(behaviour leader _group) in _behaviours}) then {
        private _busy = false;
        private _leader = leader _group;

        if (serverTime >= (_group getVariable ["ddtCooldown", -1])) then {
            if (!isNil "DDT_fnc_GroupHasFPVAT" && {!isNil "DDT_fnc_GetTargetsAT"}) then {
                private _hasAT = _group call DDT_fnc_GroupHasFPVAT;
                private _atTargets = if (_hasAT) then {[_leader, _attackRange] call DDT_fnc_GetTargetsAT} else {[]};
                if (_hasAT && {count _atTargets > 0}) then {
                    _group setVariable ["ddtCooldown", serverTime + _cooldown, true];
                    [_group, "FPVAT"] call DDT_fnc_GroupDeployUAV;
                    _launched = _launched + 1;
                    _busy = true;
                };
            };
            if (!_busy && {!isNil "DDT_fnc_GroupHasFPV"} && {!isNil "DDT_fnc_GetSoftTargets"}) then {
                private _hasAP = _group call DDT_fnc_GroupHasFPV;
                private _softTargets = if (_hasAP) then {[_leader, _attackRange] call DDT_fnc_GetSoftTargets} else {[]};
                if (_hasAP && {count _softTargets > 0}) then {
                    _group setVariable ["ddtCooldown", serverTime + _cooldown, true];
                    [_group, "FPV"] call DDT_fnc_GroupDeployUAV;
                    _launched = _launched + 1;
                    _busy = true;
                };
            };
            if (!_busy && {!isNil "DDT_fnc_GroupHasBomber"} && {!isNil "DDT_fnc_GetTargetsBomber"}) then {
                private _hasBomber = _group call DDT_fnc_GroupHasBomber;
                private _bomberTargets = if (_hasBomber) then {[_leader, _bomberRange] call DDT_fnc_GetTargetsBomber} else {[]};
                if (_hasBomber && {count _bomberTargets > 0}) then {
                    _group setVariable ["ddtCooldown", serverTime + _cooldown, true];
                    [_group, "BOMBER"] call DDT_fnc_GroupDeployUAV;
                    _launched = _launched + 1;
                    _busy = true;
                };
            };
        };

        if (!_busy && {_launched < _maxLaunches} && {!isNil "DDT_fnc_GroupHasRecon"}) then {
            private _hasRecon = _group call DDT_fnc_GroupHasRecon;
            private _reconNear = false;
            if (!isNil "DDT_fnc_FriendlyReconNear") then {_reconNear = _group call DDT_fnc_FriendlyReconNear};
            if (_hasRecon && {!_reconNear}) then {
                [_group, "RECON"] call DDT_fnc_GroupDeployUAV;
                _launched = _launched + 1;
            };
        };
    };
} forEach DRO2026_managedGroups;
_launched
