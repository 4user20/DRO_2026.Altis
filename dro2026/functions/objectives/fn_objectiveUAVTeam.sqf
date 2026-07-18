params ["_AOIndex"];
private _pos = ["ENEMY_DRONE_FORWARD"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_UAVTEAM_%1", floor random 1000000];
private _marker = format ["D26_M_UAVTEAM_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos]; _marker setMarkerShape "ELLIPSE"; _marker setMarkerSize [260,260]; _marker setMarkerBrush "Border"; _marker setMarkerColor _color; _marker setMarkerAlpha 0.68; _marker setMarkerText " Передовая группа БПЛА";
private _team = [_pos, enemySide, "FPV_TEAM"] call DRO2026_fnc_createDroneTeam;
private _operator = _team getOrDefault ["operator", objNull];
private _assistant = _team getOrDefault ["assistant", objNull];
private _antenna = _team getOrDefault ["antenna", objNull];
private _cache = createVehicle ["Land_Pallet_MilBoxes_F", _pos getPos [9, 170], [], 0, "CAN_COLLIDE"];
private _parkedClass = if (enemySide == west) then {["FPV_WEST", "B_UAV_01_F"] call DRO2026_fnc_getRoleClass} else {["FPV_EAST", "O_UAV_01_F"] call DRO2026_fnc_getRoleClass};
private _parked = createVehicle [_parkedClass, _pos getPos [12, 260], [], 0, "NONE"];
if (!isNull _parked) then {_parked setFuel 0; _parked setDamage 0.15};
private _critical = [_operator, _assistant, _antenna, _cache, _parked] select {!isNull _x};
DRO2026_sites pushBack createHashMapFromArray [["type", "FPV_TEAM"], ["position", _pos], ["object", _operator], ["operator", _operator], ["team", _team], ["objects", _critical]];
private _title = "Подавить передовую группу БПЛА";
private _desc = "В обозначенной точке действует конкретная операторская группа FPV и разведывательных квадрокоптеров. Пока оператор жив и антенна работает, группа может запускать аппараты по подтверждённым контактам в радиусе нескольких километров. Уничтожьте оператора, антенну и запас аппаратов.";
private _meta = createHashMapFromArray [["type", "UAV_TEAM"], ["critical", _critical], ["operator", _operator]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.93, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _operator, _antenna, _cache] spawn {
    params ["_task", "_operator", "_antenna", "_cache"];
    waitUntil {sleep 2; !alive _operator && {!alive _antenna || {!alive _cache}}};
    [_task, "TARGET_DESTROYED", [["enemyDroneStock", -14], ["enemySupply", -4]]] call DRO2026_fnc_completeObjective;
};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 8; ["NEW_TASK", "Штаб: Подавите передовую операторскую группу беспилотников."] call DRO2026_fnc_hqVoice};
_taskName
