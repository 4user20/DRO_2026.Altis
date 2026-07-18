params ["_AOIndex"];
private _aoCenter = (AOLocations select _AOIndex) select 0;
private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", random 360];
private _pos = [_aoCenter, 900, 1900, _axis, 100, false, 650] call DRO2026_fnc_findStrategicPosition;
private _taskName = format ["D26_ISR_%1", floor random 1000000];
private _marker = format ["D26_M_ISR_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
createMarker [_marker, _pos]; _marker setMarkerShape "ELLIPSE"; _marker setMarkerSize [420,420]; _marker setMarkerBrush "Border"; _marker setMarkerColor _color; _marker setMarkerAlpha 0.48; _marker setMarkerText " Сектор разведки";
private _observer = createVehicle ["Land_Camping_Light_F", _pos, [], 0, "CAN_COLLIDE"];
[_pos, 3, 5, 150] call DRO2026_fnc_spawnGuard;
private _title = "Уточнить обстановку в секторе";
private _desc = "Проведите наблюдение конкретного сектора с воздуха или с наземной позиции не менее 90 секунд. После подтверждения цели будут доступны автоматическому командиру союзных FPV и дальних ударных БПЛА. Одного приближения к маркеру недостаточно — требуется непрерывное наблюдение.";
private _meta = createHashMapFromArray [["type", "ISR_RECON"], ["position", _pos]];
[_taskName, _desc, _title, _marker, "scout", _pos, 0.98, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _pos, _observer] spawn {
    params ["_task", "_pos", "_observer"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1};
    private _observed = 0;
    while {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0} do {
        private _qualified = false;
        if ((player distance2D _pos) < 650) then {_qualified = ([player, "VIEW"] checkVisibility [eyePos player, AGLToASL (_pos vectorAdd [0,0,1.5])]) > 0.20};
        private _uav = getConnectedUAV player;
        if (!isNull _uav && {_uav distance2D _pos < 900}) then {_qualified = true};
        if (_qualified) then {_observed = _observed + 2} else {_observed = (_observed - 1) max 0};
        if (_observed >= 90) exitWith {
            DRO2026_intelQuality = (DRO2026_intelQuality + 0.32) min 1;
            {private _veh = _x; private _vehSide = side _veh; if (!isNull (driver _veh)) then {_vehSide = side (group (driver _veh))}; if (alive _veh && {_vehSide == enemySide} && {_veh distance2D _pos < 2200}) then {["PLAYER", _veh, getPosATL _veh, 0.86, "ISR_CONFIRMED"] call DRO2026_fnc_addContact}} forEach DRO2026_managedVehicles;
            [_task, "TASK_COMPLETE", []] call DRO2026_fnc_completeObjective;
        };
        sleep 2;
    };
    deleteVehicle _observer;
};
[] spawn {waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1}; sleep 7; ["NEW_TASK", "Штаб: Проведите длительную разведку указанного сектора."] call DRO2026_fnc_hqVoice};
_taskName
