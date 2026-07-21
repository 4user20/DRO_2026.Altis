params [
    ["_aircraft",objNull,[objNull]],
    ["_target",objNull,[objNull]],
    ["_attackerSide",playersSide,[east]],
    ["_homeATL",[],[[]]],
    ["_missionId","AIR_MISSION",[""]]
];
if (!isServer || {isNull _aircraft} || {isNull _target} || {!alive _aircraft} || {!alive _target}) exitWith {createHashMapFromArray [["ok",false],["code","INVALID_ASSET_OR_TARGET"]]};
private _group = group (driver _aircraft);
if (isNull _group) exitWith {createHashMapFromArray [["ok",false],["code","GROUP_MISSING"]]};
private _weapon = [_aircraft] call DRO2026_fnc_getStandoffWeapon;
if !(_weapon getOrDefault ["ok",false]) exitWith {createHashMapFromArray [["ok",false],["code","NO_STANDOFF_WEAPON"]]};
private _muzzle = _weapon getOrDefault ["muzzle",""];
private _weaponRange = (_weapon getOrDefault ["range",2500]) max 1800;
private _isHelicopter = _aircraft isKindOf "Helicopter";
private _targetATL = getPosATL _target;
if (count _homeATL < 2) then {_homeATL = getPosATL _aircraft};
private _defenderSide = if (_attackerSide == playersSide) then {enemySide} else {playersSide};
private _aaNodeId = if (_defenderSide == playersSide) then {"NODE_FRIENDLY_AA_LONG"} else {"NODE_AA_LONG_01"};
private _aaNode = DRO2026_networkNodes getOrDefault [_aaNodeId,createHashMap];
private _aaActive = count _aaNode > 0 && {!((toUpperANSI (_aaNode getOrDefault ["status","ACTIVE"])) in ["DESTROYED","DISABLED","CANCELLED"])} && {((_aaNode getOrDefault ["stocks",createHashMap]) getOrDefault ["AA_MISSILES",0]) > 0};
private _aaPosition = _aaNode getOrDefault ["position",[]];
private _aaEnvelope = if (_aaActive) then {12500} else {0};
private _desiredRange = ((_weaponRange * 0.72) max 1800) min (if (_isHelicopter) then {5200} else {7000});
private _approachBearing = _targetATL getDir _homeATL;
if (_aaActive && {count _aaPosition >= 2}) then {
    private _awayFromAA = _aaPosition getDir _targetATL;
    private _homeCandidate = _targetATL getPos [_desiredRange,_approachBearing];
    private _aaCandidate = _targetATL getPos [_desiredRange,_awayFromAA];
    if ((_aaCandidate distance2D _aaPosition) > (_homeCandidate distance2D _aaPosition)) then {_approachBearing = _awayFromAA};
};
private _firePoint = _targetATL getPos [_desiredRange,_approachBearing];
private _terrainHeight = getTerrainHeightASL _firePoint;
_firePoint set [2,if (_isHelicopter) then {55 + random 35} else {360 + random 140}];
if (_aaActive && {count _aaPosition >= 2} && {_firePoint distance2D _aaPosition < (_aaEnvelope * 0.72)} && {_weaponRange < 3500}) exitWith {
    createHashMapFromArray [["ok",false],["code","NO_SAFE_STANDOFF_GEOMETRY"],["aaNodeId",_aaNodeId]]
};
_group setBehaviourStrong "COMBAT";
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_aircraft flyInHeight (if (_isHelicopter) then {65} else {420});
private _driver = driver _aircraft;
if (!isNull _driver) then {_driver doMove _firePoint};
["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","STANDOFF_INGRESS"],["firePoint",_firePoint],["range",_desiredRange],["muzzle",_muzzle]],_missionId] call DRO2026_fnc_emitEvent;
private _ingressDeadline = time + 220;
waitUntil {
    sleep 2;
    !alive _aircraft || {!alive _target} || {_aircraft distance2D _firePoint < 420} || {time > _ingressDeadline} || {missionNamespace getVariable ["DRO2026_missionEnding",false]}
};
if (!alive _aircraft || {!alive _target} || {time > _ingressDeadline}) exitWith {createHashMapFromArray [["ok",false],["code","INGRESS_FAILED"]]};
_aircraft reveal [_target,4];
private _crew = crew _aircraft;
{_x doTarget _target} forEach _crew;
private _shots = 0;
private _fired = false;
private _fireDeadline = time + 55;
while {alive _aircraft && {alive _target} && {time < _fireDeadline} && {_shots < 2}} do {
    private _aim = _aircraft aimedAtTarget [_target,_muzzle];
    if (_aim > 0.12 || {_aircraft distance2D _target <= (_weaponRange * 0.95)}) then {
        private _didFire = _aircraft fireAtTarget [_target,_muzzle];
        if (!_didFire) then {
            private _gunner = gunner _aircraft;
            if (!isNull _gunner) then {_gunner doTarget _target; _gunner doFire _target};
        };
        _fired = true;
        _shots = _shots + 1;
        ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","STANDOFF_FIRED"],["shot",_shots],["muzzle",_muzzle]],_missionId] call DRO2026_fnc_emitEvent;
        sleep 8;
    } else {
        if (!isNull _driver) then {_driver doMove (_targetATL getPos [(_desiredRange * 0.86) max 1500,_approachBearing])};
        sleep 2;
    };
};
private _egressBearing = (_approachBearing + 180 + (-20 + random 40)) mod 360;
private _egress = _targetATL getPos [9000,_egressBearing];
_egress set [2,if (_isHelicopter) then {120} else {680}];
if (!isNull _driver) then {_driver doMove _egress};
["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","EGRESS"],["shots",_shots]],_missionId] call DRO2026_fnc_emitEvent;
private _result = createHashMapFromArray [["ok",_fired],["code",if (_fired) then {"STANDOFF_ATTACK_EXECUTED"} else {"NO_WEAPON_RELEASE"}],["shots",_shots],["weapon",_weapon],["firePoint",_firePoint]];
_result