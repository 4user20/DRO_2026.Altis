params ["_AOIndex"];
private _pos = ["ENEMY_TACTICAL_REAR"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_REAR_%1", floor random 1000000];
private _marker = format ["D26_M_REAR_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos]; _marker setMarkerShape "ELLIPSE"; _marker setMarkerSize [420,420]; _marker setMarkerBrush "Border"; _marker setMarkerColor _color; _marker setMarkerAlpha 0.58; _marker setMarkerText " Узел тыловой связи";
private _relay = createVehicle ["Land_TTowerSmall_1_F", _pos getPos [25, 50], [], 0, "NONE"];
private _logRole = if (enemySide == west) then {"LOGISTICS_WEST"} else {"LOGISTICS_EAST"};
private _fuel = createVehicle [[_logRole, if (enemySide == west) then {"B_Truck_01_fuel_F"} else {"O_Truck_03_fuel_F"}] call DRO2026_fnc_getRoleClass, _pos getPos [22, 160], [], 0, "NONE"];
private _ammo = createVehicle [[_logRole, if (enemySide == west) then {"B_Truck_01_ammo_F"} else {"O_Truck_03_ammo_F"}] call DRO2026_fnc_getRoleClass, _pos getPos [28, 225], [], 0, "NONE"];
private _critical = [_relay, _fuel, _ammo];
{if (_x isKindOf "AllVehicles") then {DRO2026_managedVehicles pushBackUnique _x}} forEach _critical;
[_pos, 5, 8, 150] call DRO2026_fnc_spawnGuard;
DRO2026_sites pushBack createHashMapFromArray [["type", "REAR_LINK"], ["position", _pos], ["object", _relay], ["objects", _critical]];
private _title = "Отсечь тыл наступающей группировки";
private _desc = "Этот конкретный узел связывает передовые подразделения с топливом, боеприпасами и управлением. Уничтожьте ретранслятор и обе машины снабжения до начала усиленной реакции противника. Успех задержит окружение вашей группы и сократит артиллерийские и беспилотные удары.";
private _meta = createHashMapFromArray [["type", "CUT_REAR"], ["critical", _critical]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.9, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _critical] spawn {
    params ["_task", "_critical"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1};
    private _deadline = time + 3300;
    waitUntil {sleep 3; ({alive _x} count _critical) <= 1 || {time > _deadline}};
    if (({alive _x} count _critical) <= 1) then {[_task, "TASK_COMPLETE", [["enemySupply", -24], ["enemyReinforcement", -26], ["enemyArtilleryAmmo", -10], ["enemyDroneStock", -7]]] call DRO2026_fnc_completeObjective} else {[_task, "FAILED", true] spawn BIS_fnc_taskSetState; missionNamespace setVariable [format ["%1Completed", _task], -1, true]; DRO2026_alertLevel = 0.9};
};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 8; ["NEW_TASK", "Штаб: Отрежьте конкретный узел снабжения наступающей группировки."] call DRO2026_fnc_hqVoice};
_taskName
