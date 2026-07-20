params ["_AOIndex"];
[] call DRO2026_fnc_buildTheaterGraph;
private _longPos = ["ENEMY_AA_LONG"] call DRO2026_fnc_getTheaterNode;
private _shortPos = ["ENEMY_AA_SHORAD"] call DRO2026_fnc_getTheaterNode;
private _taskName = format ["D26_AA_%1", floor random 1000000];
private _marker = format ["D26_M_AA_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _longPos];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerSize [750, 750];
_marker setMarkerBrush "Border";
_marker setMarkerColor _color;
_marker setMarkerAlpha 0.58;
_marker setMarkerText " Эшелонированный район ПВО";

private _critical = ["AIR_DEFENCE_SITE", enemySide, "ENEMY_AA_LONG", "ENEMY_AA_SHORAD", true] call DRO2026_fnc_spawnLayeredAA;
if (count _critical == 0) exitWith {
    deleteMarker _marker;
    [_AOIndex] call DRO2026_fnc_objectiveEWHunt
};
[_longPos, 2, 3, 120] call DRO2026_fnc_spawnGuard;
[_shortPos, 2, 3, 80] call DRO2026_fnc_spawnGuard;
private _title = "Подавить эшелонированный район ПВО";
private _desc = format [
    "В глубоком тылу противника развёрнут эшелонированный район ПВО: дальнобойный комплекс, радиолокационный пост и ближнее прикрытие. Район закрывает дальние БПЛА и авиацию. Дальность до центра района — около %1 км. Уничтожьте все материализованные компоненты.",
    (((AOLocations select _AOIndex) select 0 distance2D _longPos) / 1000) toFixed 1
];
private _meta = createHashMapFromArray [["type", "AIR_DEFENCE"], ["critical", _critical]];
[_taskName, _desc, _title, _marker, "destroy", _longPos, 0.9, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _critical] spawn {
    params ["_task", "_critical"];
    waitUntil {
        sleep 3;
        ({!isNull _x && {alive _x}} count _critical) == 0 ||
        {missionNamespace getVariable ["DRO2026_missionEnding", false]}
    };
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {
        [_task, "AA_DESTROYED", [["enemyAirDefence", -58]]] call DRO2026_fnc_completeObjective;
    };
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {
        sleep 8;
        ["NEW_TASK", "Штаб: В тылу противника эшелонированный район ПВО. Подавите дальнюю и ближнюю компоненты."] call DRO2026_fnc_hqVoice;
    };
};
_taskName
