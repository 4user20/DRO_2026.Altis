params ["_AOIndex"];
private _pos = ["ENEMY_ARTILLERY"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_ARTY_%1", floor random 1000000];
private _marker = format ["D26_M_ARTY_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerSize [420,420];
_marker setMarkerBrush "Border";
_marker setMarkerColor _color;
_marker setMarkerAlpha 0.58;
_marker setMarkerText " Предполагаемый район артиллерии";

private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _fallback = switch (enemySide) do {case west: {"B_MBT_01_arty_F"}; case resistance: {"I_Truck_02_MRL_F"}; default {"O_MBT_02_arty_F"}};
private _class = [format ["ARTILLERY_%1", _suffix], _fallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _arty = if (_class == "") then {objNull} else {createVehicle [_class, _pos, [], 0, "NONE"]};
if (isNull _arty || {count getArtilleryAmmo [_arty] == 0}) then {
    if (!isNull _arty) then {deleteVehicle _arty};
    private _mortar = switch (enemySide) do {case west: {"B_Mortar_01_F"}; case resistance: {"I_Mortar_01_F"}; default {"O_Mortar_01_F"}};
    private _mortarClass = [format ["ARTILLERY_%1", _suffix], _mortar, enemySide] call DRO2026_fnc_getSideRoleClass;
    _arty = if (_mortarClass == "") then {objNull} else {createVehicle [_mortarClass, _pos, [], 0, "NONE"]};
};
if (isNull _arty || {count getArtilleryAmmo [_arty] == 0} || {!([_arty, enemySide] call DRO2026_fnc_crewManagedVehicle)}) exitWith {
    if (!isNull _arty) then {deleteVehicleCrew _arty; deleteVehicle _arty};
    deleteMarker _marker;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsHub
};
_arty setDir random 360;
private _crewGroup = if (isNull (gunner _arty)) then {if (isNull (driver _arty)) then {grpNull} else {group (driver _arty)}} else {group (gunner _arty)};
private _positions = [_pos];
for "_i" from 1 to 3 do {
    private _candidate = [_pos, 320, 850, 10, 0, 0.3, 0, [], [_pos, _pos]] call BIS_fnc_findSafePos;
    if !(_candidate isEqualTo [0,0,0]) then {_positions pushBack _candidate};
};
private _guardGroup = [_pos, 3, 5, 110] call DRO2026_fnc_spawnGuard;
private _extra = createHashMapFromArray [["positions", _positions], ["group", _crewGroup], ["guardGroup", _guardGroup], ["background", false]];
private _site = ["ARTILLERY_SITE", _pos, _arty, [_arty], _extra] call DRO2026_fnc_createSiteRecord;
if !([_site, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    deleteVehicleCrew _arty;
    deleteVehicle _arty;
    {
        if (!isNull _x) then {
            {if (!isNull _x) then {deleteVehicle _x}} forEach units _x;
            deleteGroup _x;
        };
    } forEach [_crewGroup, _guardGroup];
    deleteMarker _marker;
    [_AOIndex] call DRO2026_fnc_objectiveLogisticsHub
};
DRO2026_sites pushBack _site;

private _title = "Контрбатарейная охота";
private _desc = "Артиллерийский расчёт реально занимает огневые позиции, ведёт короткие серии по выявленным союзным точкам и после двух огневых задач меняет место. Маркер показывает уточняемый район, а не постоянную точку. Найдите систему по вспышкам, звуку, БПЛА или маршруту отхода и уничтожьте её.";
private _meta = createHashMapFromArray [["type", "ARTILLERY_HUNT"], ["object", _arty], ["critical", [_arty]], ["positions", _positions], ["siteId", _site get "id"]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.88, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_arty, _positions, _taskName, _marker] spawn DRO2026_fnc_artilleryLoop;
[_taskName, _arty, _site] spawn {
    params ["_task", "_arty", "_site"];
    waitUntil {sleep 2; !alive _arty || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {
        _site set ["status", "CANCELLED"];
        _site set ["physicalState", "DISABLED"];
        _site set ["disabledAt", time];
    };
    [_task, "ARTILLERY_DESTROYED", [["enemyArtilleryAmmo", -34], ["enemySupply", -8]]] call DRO2026_fnc_completeObjective;
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 8; ["ARTILLERY_TASK"] call DRO2026_fnc_hqVoice};
};
_taskName
