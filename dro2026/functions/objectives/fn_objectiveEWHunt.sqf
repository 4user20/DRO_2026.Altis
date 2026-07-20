params ["_AOIndex"];
private _pos = ["ENEMY_EW"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_EW_%1", floor random 1000000];
private _marker = format ["D26_M_EW_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerSize [360,360];
_marker setMarkerBrush "Border";
_marker setMarkerColor _color;
_marker setMarkerAlpha 0.58;
_marker setMarkerText " Район работы РЭБ";

private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _fallback = switch (enemySide) do {case west: {"B_Truck_01_box_F"}; case resistance: {"I_Truck_02_box_F"}; default {"O_Truck_03_device_F"}};
private _class = [format ["EW_%1", _suffix], _fallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _vehicle = if (_class == "") then {objNull} else {createVehicle [_class, _pos, [], 0, "NONE"]};
if (isNull _vehicle || {!([_vehicle, enemySide] call DRO2026_fnc_crewManagedVehicle)}) exitWith {
    deleteMarker _marker;
    [_AOIndex] call DRO2026_fnc_objectiveUAVTeam
};
private _vehicleGroup = if (isNull (driver _vehicle)) then {grpNull} else {group (driver _vehicle)};
private _antenna = createVehicle ["Land_SatelliteAntenna_01_F", _pos getPos [45, random 360], [], 0, "NONE"];
private _generator = createVehicle ["Land_PortableGenerator_01_F", _pos getPos [20, random 360], [], 0, "CAN_COLLIDE"];
private _critical = [_vehicle, _antenna, _generator] select {!isNull _x};
private _guardGroup = [_pos, 3, 5, 110] call DRO2026_fnc_spawnGuard;
private _extra = createHashMapFromArray [["group", _vehicleGroup], ["guardGroup", _guardGroup], ["background", false]];
private _site = ["EW_SITE", _pos, _vehicle, _critical, _extra] call DRO2026_fnc_createSiteRecord;
if !([_site, true] call DRO2026_fnc_validateSiteRecord) exitWith {
    if (!isNull _vehicle) then {deleteVehicleCrew _vehicle};
    {if (!isNull _x) then {deleteVehicle _x}} forEach _critical;
    {
        if (!isNull _x) then {
            {if (!isNull _x) then {deleteVehicle _x}} forEach units _x;
            deleteGroup _x;
        };
    } forEach [_vehicleGroup, _guardGroup];
    deleteMarker _marker;
    [_AOIndex] call DRO2026_fnc_objectiveUAVTeam
};
DRO2026_sites pushBack _site;

private _title = "Подавить мобильный комплекс РЭБ";
private _desc = "Комплекс РЭБ работает из конкретного тылового района и снижает достоверность разведконтактов, задерживает союзные автоматические удары и повышает вероятность потери управления БПЛА. Уничтожьте машину, антенну и источник питания.";
private _meta = createHashMapFromArray [["type", "EW_HUNT"], ["critical", _critical], ["siteId", _site get "id"]];
[_taskName, _desc, _title, _marker, "destroy", _pos, 0.88, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _critical, _site] spawn {
    params ["_task", "_critical", "_site"];
    waitUntil {
        sleep 3;
        ({!isNull _x && {alive _x}} count _critical) == 0 ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) exitWith {
        _site set ["status", "CANCELLED"];
        _site set ["physicalState", "DISABLED"];
        _site set ["disabledAt", time];
    };
    DRO2026_resources set ["enemyEW", 0];
    [_task, "TARGET_DESTROYED", [["enemyEW", -65]]] call DRO2026_fnc_completeObjective;
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 8; ["EW_TASK"] call DRO2026_fnc_hqVoice};
};
_taskName
