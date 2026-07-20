if (!isServer) exitWith {};
if (count DRO2026_friendlyPositions > 0) exitWith {};
[] call DRO2026_fnc_buildTheaterGraph;
private _sideColor = if (isNil "markerColorPlayers") then {"ColorBLUFOR"} else {markerColorPlayers};
private _safeClasses = [];
if (!isNil "pInfClasses") then {_safeClasses = pInfClasses select {[_x, playersSide] call DRO2026_fnc_isSafeInfantryClass}};
if (count _safeClasses == 0) then {
    _safeClasses = switch (playersSide) do {
        case west: {["B_Soldier_F", "B_Soldier_AR_F", "B_medic_F"]};
        case resistance: {["I_Soldier_F", "I_Soldier_AR_F", "I_medic_F"]};
        default {["O_Soldier_F", "O_Soldier_AR_F", "O_medic_F"]};
    };
};
private _positions = [["FRIENDLY_FORWARD"] call DRO2026_fnc_getTheaterNode, ["FRIENDLY_REAR"] call DRO2026_fnc_getTheaterNode];
{
    private _pos = _x;
    private _marker = format ["D26_FRIENDLY_%1", _forEachIndex + 1];
    createMarker [_marker, _pos];
    _marker setMarkerShape "ICON";
    _marker setMarkerType "b_hq";
    _marker setMarkerColor _sideColor;
    _marker setMarkerText (if (_forEachIndex == 0) then {" Союзная передовая позиция"} else {" Союзный тыловой пункт"});
    private _objects = [];
    {
        private _obj = createVehicle [_x select 0, _pos getPos [_x select 1, _x select 2], [], 0, "CAN_COLLIDE"];
        if (!isNull _obj) then {
            _obj setDir ((_x select 2) + 180);
            _objects pushBack _obj;
        };
    } forEach [["Land_Cargo_Patrol_V1_F", 8, 0], ["Land_HBarrier_5_F", 13, 90], ["Land_HBarrier_5_F", 13, 270], ["Land_Pallet_MilBoxes_F", 10, 180]];

    private _group = createGroup [playersSide, true];
    if (!isNull _group) then {
        for "_u" from 1 to 4 do {
            private _unit = _group createUnit [selectRandom _safeClasses, _pos, [], 7, "FORM"];
            if (!isNull _unit) then {_unit setUnitPos (selectRandom ["MIDDLE", "UP"])};
        };
        if (({alive _x} count units _group) > 0) then {
            [_group] call DRO2026_fnc_registerManagedGroup;
            _group setVariable ["DRO2026_static", true];
            [_group, _pos, 55] call BIS_fnc_taskDefend;
        } else {
            deleteGroup _group;
            _group = grpNull;
        };
    };

    private _record = createHashMapFromArray [["id", _forEachIndex + 1], ["position", _pos], ["marker", _marker], ["objects", _objects], ["group", _group], ["type", if (_forEachIndex == 0) then {"FORWARD"} else {"REAR"}]];
    DRO2026_friendlyPositions pushBack _record;
} forEach _positions;
[format ["Создано союзных позиций: %1; дистанция от AO: %2/%3 м", count DRO2026_friendlyPositions, round ((DRO2026_theaterNodes get "AO_CENTER") distance2D (_positions select 0)), round ((DRO2026_theaterNodes get "AO_CENTER") distance2D (_positions select 1))]] call DRO2026_fnc_log;
