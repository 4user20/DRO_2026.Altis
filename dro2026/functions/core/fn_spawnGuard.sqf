params ["_position", ["_min", 3], ["_max", 6], ["_radius", 80], ["_static", true]];
private _group = grpNull;
private _factor = missionNamespace getVariable ["DRO2026_spawnBudgetFactor", 1];
private _countMin = ((round (_min * _factor)) max 2);
private _countMax = ((round (_max * _factor)) max _countMin);
private _side = if (!isNil "enemySide") then {enemySide} else {east};
private _classes = [];
if (!isNil "eInfClasses") then {_classes = eInfClasses select {[_x, _side] call DRO2026_fnc_isSafeInfantryClass}};
if (count _classes == 0) then {
    _classes = if (_side == west) then {["B_Soldier_F", "B_Soldier_GL_F", "B_Soldier_AR_F"]} else {
        if (_side == resistance) then {["I_Soldier_F", "I_Soldier_GL_F", "I_Soldier_AR_F"]} else {["O_Soldier_F", "O_Soldier_GL_F", "O_Soldier_AR_F"]}
    };
};
_group = createGroup [_side, true];
private _count = [_countMin, _countMax] call BIS_fnc_randomInt;
for "_i" from 1 to _count do {_group createUnit [selectRandom _classes, _position, [], 8, "FORM"]};
if (!isNull _group) then {
    [_group] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", _static];
    _group setBehaviourStrong "AWARE";
    _group setCombatMode "YELLOW";
    if (_static) then {[_group, _position, _radius] call BIS_fnc_taskPatrol};
};
_group
