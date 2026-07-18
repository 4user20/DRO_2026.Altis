params ["_position", ["_min", 2], ["_max", 4], ["_radius", 80], ["_static", true]];
private _side = if (!isNil "enemySide") then {enemySide} else {east};
private _currentEnemyAI = {alive _x && {side (group _x) == _side}} count allUnits;
private _remaining = ((missionNamespace getVariable ["DRO2026_MAX_TOTAL_ENEMY_AI", 72]) - _currentEnemyAI) max 0;
if (_remaining <= 0) exitWith {grpNull};
if ((count DRO2026_managedGroups) >= (missionNamespace getVariable ["DRO2026_MAX_MANAGED_GROUPS", 14])) exitWith {grpNull};

private _factor = (missionNamespace getVariable ["DRO2026_spawnBudgetFactor", 1]) min 1;
private _countMin = ((round (_min * _factor)) max 1) min _remaining;
private _countMax = ((round (_max * _factor)) max _countMin) min _remaining;
private _classes = [];
if (!isNil "eInfClasses") then {_classes = eInfClasses select {[_x, _side] call DRO2026_fnc_isSafeInfantryClass}};
if (count _classes == 0) then {
    _classes = if (_side == west) then {["B_Soldier_F", "B_Soldier_GL_F", "B_Soldier_AR_F"]} else {
        if (_side == resistance) then {["I_Soldier_F", "I_Soldier_GL_F", "I_Soldier_AR_F"]} else {["O_Soldier_F", "O_Soldier_GL_F", "O_Soldier_AR_F"]}
    };
};
private _group = createGroup [_side, true];
private _count = [_countMin, _countMax] call BIS_fnc_randomInt;
for "_i" from 1 to _count do {_group createUnit [selectRandom _classes, _position, [], 8, "FORM"]};
if (!isNull _group) then {
    [_group] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", _static];
    _group setBehaviourStrong "AWARE";
    _group setCombatMode "YELLOW";
    if (_static) then {[_group, _position, _radius] call BIS_fnc_taskDefend};
};
_group
