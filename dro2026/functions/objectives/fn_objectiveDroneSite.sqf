params ["_AOIndex"];
private _pos = ["ENEMY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_DRONE_%1", floor random 1000000];
private _marker = format ["D26_M_DRONE_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerSize [380,380];
_marker setMarkerBrush "Border";
_marker setMarkerColor _color;
_marker setMarkerAlpha 0.62;
_marker setMarkerText " Тыловая площадка БПЛА";

private _team = [_pos, enemySide, "STRATEGIC_DRONE_SITE"] call DRO2026_fnc_createDroneTeam;
private _operator = _team getOrDefault ["operator", objNull];
private _assistant = _team getOrDefault ["assistant", objNull];
private _antenna = _team getOrDefault ["antenna", objNull];
private _tent = _team getOrDefault ["tent", objNull];
private _teamGroup = _team getOrDefault ["group", grpNull];
if (isNull _operator) exitWith {deleteMarker _marker; [_AOIndex] call DRO2026_fnc_objectiveUAVTeam};

private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _controlFallback = switch (enemySide) do {case west: {"B_Truck_01_box_F"}; case resistance: {"I_Truck_02_box_F"}; default {"O_Truck_03_device_F"}};
private _controlClass = [format ["EW_%1", _suffix], _controlFallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _control = if (_controlClass == "") then {objNull} else {createVehicle [_controlClass, _pos getPos [28, 110], [], 0, "NONE"]};
private _stock = createVehicle ["Land_Cargo20_military_green_F", _pos getPos [26, 245], [], 0, "NONE"];
private _generator = createVehicle ["Land_PortableGenerator_01_F", _pos getPos [18, 310], [], 0, "CAN_COLLIDE"];
if (!isNull _control) then {DRO2026_managedVehicles pushBackUnique _control};
private _guardGroup = [_pos, 3, 5, 120] call DRO2026_fnc_spawnGuard;
private _siteObjects = [_operator, _assistant, _antenna, _tent, _control, _stock, _generator] select {!isNull _x};
private _objectiveCritical = [_operator, _antenna, _control, _stock, _generator] select {!isNull _x};
private _siteObject = if (!isNull _control) then {_control} else {_operator};
private _extra = createHashMapFromArray [
    ["operator", _operator], ["group", _teamGroup], ["team", _team],
    ["guardGroup", _guardGroup], ["background", false]
];
private _site = ["STRATEGIC_DRONE_SITE", _pos, _siteObject, _siteObjects, _extra] call DRO2026_fnc_createSiteRecord;
private _rollback = {
    if (!isNull _control) then {deleteVehicleCrew _control};
    {if (!isNull _x) then {deleteVehicle _x}} forEach _siteObjects;
    {
        if (!isNull _x) then {
            {if (!isNull _x) then {deleteVehicle _x}} forEach units _x;
            deleteGroup _x;
        };
    } forEach [_teamGroup, _guardGroup];
    deleteMarker _marker;
};
if !([_site, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    call _rollback;
    [_AOIndex] call DRO2026_fnc_objectiveUAVTeam
};
DRO2026_sites pushBack _site;

private _title = "Вывести из строя тыловую площадку БПЛА";
private _desc = "На конкретной площадке находятся операторская группа, антенна, машина управления, генератор и запас аппаратов. Доступные ударные аппараты запускаются директором только при наличии живого оператора и подтверждённой цели. Уничтожьте оператора и не менее двух элементов инфраструктуры.";
private _meta = createHashMapFromArray [["type", "DRONE_SITE"], ["critical", _siteObjects], ["operator", _operator], ["siteId", _site get "id"]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.9, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _objectiveCritical, _operator, _site] spawn {
    params ["_task", "_objectiveCritical", "_operator", "_site"];
    waitUntil {
        sleep 3;
        (!alive _operator && {({!isNull _x && {alive _x}} count _objectiveCritical) <= 2}) ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {
        _site set ["status", "CANCELLED"];
        _site set ["physicalState", "DISABLED"];
        _site set ["disabledAt", time];
    };
    [_task, "TARGET_DESTROYED", [["enemyDroneStock", -24], ["enemyLongRangeStock", -5], ["enemySupply", -8]]] call DRO2026_fnc_completeObjective;
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 8; ["NEW_TASK", "Штаб: Найдите и выведите из строя тыловую площадку беспилотников."] call DRO2026_fnc_hqVoice};
};
_taskName
