params ["_AOIndex"];
private _pos = ["ENEMY_LOGISTICS"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_LOG_%1", floor random 1000000];
private _marker = format ["D26_M_LOG_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos]; _marker setMarkerShape "ELLIPSE"; _marker setMarkerSize [330,330]; _marker setMarkerBrush "Border"; _marker setMarkerColor _color; _marker setMarkerAlpha 0.65; _marker setMarkerText " Тыловой распределительный узел";
private _critical = [];
private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _sideNumber = [enemySide] call DRO2026_fnc_getSideNumber;
private _role = format ["LOGISTICS_%1", _suffix];
private _classes = (DRO2026_assetRegistry getOrDefault [_role, []]) select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg && {getNumber (_cfg >> "side") == _sideNumber}
};
if (count _classes == 0) then {
    private _fallback = switch (enemySide) do {case west: {"B_Truck_01_ammo_F"}; case resistance: {"I_Truck_02_ammo_F"}; default {"O_Truck_03_ammo_F"}};
    private _class = [_role, _fallback, enemySide] call DRO2026_fnc_getSideRoleClass;
    if (_class != "") then {_classes = [_class]};
};
for "_i" from 0 to 2 do {
    if (count _classes > 0) then {
        private _spawn = _pos getPos [18 + (_i * 13), 30 + (_i * 100)];
        private _vehicle = createVehicle [selectRandom _classes, _spawn, [], 0, "NONE"];
        if (!isNull _vehicle) then {_critical pushBack _vehicle; DRO2026_managedVehicles pushBackUnique _vehicle};
    };
};
{private _object = createVehicle [_x, _pos getPos [24 + random 30, random 360], [], 0, "CAN_COLLIDE"]; if (!isNull _object) then {_object setDir random 360; _critical pushBack _object}} forEach ["Land_Cargo20_military_green_F", "CargoNet_01_box_F", "Land_Pallet_MilBoxes_F"];
private _hq = createVehicle [["COMMAND", "Land_Cargo_HQ_V1_F"] call DRO2026_fnc_getRoleClass, _pos getPos [42, 220], [], 0, "NONE"];
if (!isNull _hq) then {_critical pushBack _hq};
if (count _critical < 4 || {isNull _hq}) exitWith {{if (!isNull _x) then {deleteVehicle _x}} forEach _critical; deleteMarker _marker; ""};
[_pos, 5, 8, 150] call DRO2026_fnc_spawnGuard;
DRO2026_sites pushBack createHashMapFromArray [["type", "LOGISTICS_HUB"], ["position", _pos], ["object", _hq], ["objects", _critical]];
private _title = "Нарушить работу тылового узла";
private _desc = "Разведка установила конкретный тыловой распределительный узел. Уничтожьте не менее четырёх критических объектов: транспорт, контейнеры и штабной модуль.";
private _meta = createHashMapFromArray [["type", "LOGISTICS_HUB"], ["critical", _critical]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.9, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _critical] spawn {params ["_task", "_objects"]; waitUntil {sleep 3; ({!isNull _x && {alive _x}} count _objects) <= 2 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}}; if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {[_task, "LOGISTICS_DESTROYED", [["enemySupply", -38], ["enemyArtilleryAmmo", -18], ["enemyDroneStock", -9], ["enemyReinforcement", -14]]] call DRO2026_fnc_completeObjective}};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}}; if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 7; ["AMMO_TASK"] call DRO2026_fnc_hqVoice}};
_taskName
