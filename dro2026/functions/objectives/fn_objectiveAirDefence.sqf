params ["_AOIndex"];
[] call DRO2026_fnc_buildTheaterGraph;
private _longPos = ["ENEMY_AA_LONG"] call DRO2026_fnc_getTheaterNode;
private _shortPos = ["ENEMY_AA_SHORAD"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_AA_%1", floor random 1000000];
private _marker = format ["D26_M_AA_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _longPos]; _marker setMarkerShape "ELLIPSE"; _marker setMarkerSize [750,750]; _marker setMarkerBrush "Border"; _marker setMarkerColor _color; _marker setMarkerAlpha 0.58; _marker setMarkerText " Эшелонированный район ПВО";

private _longRole = if (enemySide == west) then {"LONG_RANGE_AA_WEST"} else {"LONG_RANGE_AA_EAST"};
private _radarRole = if (enemySide == west) then {"RADAR_WEST"} else {"RADAR_EAST"};
private _shortRole = if (enemySide == west) then {"SHORAD_WEST"} else {"SHORAD_EAST"};
private _lrFallback = if (enemySide == west) then {"B_SAM_System_03_F"} else {"S300_F_UCG"};
private _radarFallback = if (enemySide == west) then {"B_Radar_System_01_F"} else {"Land_Radar_F"};
private _shortFallback = if (enemySide == west) then {"B_APC_Tracked_01_AA_F"} else {"O_APC_Tracked_02_AA_F"};

private _lr = createVehicle [[_longRole, _lrFallback] call DRO2026_fnc_getRoleClass, _longPos, [], 0, "NONE"];
private _radar = createVehicle [[_radarRole, _radarFallback] call DRO2026_fnc_getRoleClass, _longPos getPos [90, random 360], [], 0, "NONE"];
private _sr = createVehicle [[_shortRole, _shortFallback] call DRO2026_fnc_getRoleClass, _shortPos, [], 0, "NONE"];
private _critical = [];
{
    if (!isNull _x) then {
        _critical pushBack _x;
        if ((typeOf _x) isKindOf "AllVehicles") then {
            private _grp = enemySide createVehicleCrew _x;
            if (!isNull _grp) then {[_grp, false] call DRO2026_fnc_registerManagedGroup};
            DRO2026_managedVehicles pushBackUnique _x;
        };
    };
} forEach [_lr, _radar, _sr];
if (count _critical == 0) exitWith {[_AOIndex] call DRO2026_fnc_objectiveEWHunt};
[_longPos, 4, 6, 120] call DRO2026_fnc_spawnGuard;
[_shortPos, 3, 4, 80] call DRO2026_fnc_spawnGuard;
DRO2026_sites pushBack createHashMapFromArray [["type", "AIR_DEFENCE_SITE"], ["position", _longPos], ["object", _lr], ["objects", _critical]];
private _title = "Подавить эшелонированный район ПВО";
private _desc = format ["В глубоком тылу противника развёрнут эшелонированный район ПВО: дальнобойный комплекс, радиолокационный пост и ближнее прикрытие. Район закрывает дальние БПЛА и авиацию. Дальность до центра района — около %1 км. Уничтожьте минимум дальнюю пусковую, радар и ближний компонент прикрытия.", (((AOLocations select _AOIndex) select 0 distance2D _longPos) / 1000) toFixed 1];
private _meta = createHashMapFromArray [["type", "AIR_DEFENCE"], ["critical", _critical]];
[_taskName, _desc, _title, _marker, "destroy", _longPos, 0.9, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _critical] spawn {params ["_task", "_critical"]; waitUntil {sleep 3; ({alive _x} count _critical) == 0}; [_task, "AA_DESTROYED", [["enemyAirDefence", -58]]] call DRO2026_fnc_completeObjective};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 8; ["NEW_TASK", "Штаб: В тылу противника эшелонированный район ПВО. Подавите дальнюю и ближнюю компоненты."] call DRO2026_fnc_hqVoice};
_taskName
