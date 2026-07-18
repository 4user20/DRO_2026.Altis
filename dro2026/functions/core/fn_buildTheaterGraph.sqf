if (missionNamespace getVariable ["DRO2026_theaterBuilt", false]) exitWith {DRO2026_theaterNodes};
private _aoCenter = if (count AOLocations > 0) then {(AOLocations select 0) select 0} else {centerPos};
private _preferredAxes = [90, 75, 105, 60, 120, 45, 135, 30, 150];
private _axis = 90;
private _foundAxis = false;
{
    private _candidateAxis = _x;
    private _enemyTest = _aoCenter getPos [7800, _candidateAxis];
    private _friendlyTest = _aoCenter getPos [7600, (_candidateAxis + 180) mod 360];
    private _world = worldSize;
    private _valid = !surfaceIsWater _enemyTest && {!surfaceIsWater _friendlyTest} && {
        (_enemyTest select 0) > 600 && {(_enemyTest select 1) > 600} && {(_enemyTest select 0) < (_world - 600)} && {(_enemyTest select 1) < (_world - 600)}
    } && {
        (_friendlyTest select 0) > 600 && {(_friendlyTest select 1) > 600} && {(_friendlyTest select 0) < (_world - 600)} && {(_friendlyTest select 1) < (_world - 600)}
    };
    if (_valid) exitWith {_axis = _candidateAxis; _foundAxis = true};
} forEach _preferredAxes;
if (!_foundAxis) then {
    for "_i" from 0 to 23 do {
        private _candidateAxis = (90 + (_i * 15)) mod 360;
        private _enemyTest = _aoCenter getPos [7600, _candidateAxis];
        private _friendlyTest = _aoCenter getPos [7000, (_candidateAxis + 180) mod 360];
        private _world = worldSize;
        private _valid = !surfaceIsWater _enemyTest && {!surfaceIsWater _friendlyTest} && {
            (_enemyTest select 0) > 500 && {(_enemyTest select 1) > 500} && {(_enemyTest select 0) < (_world - 500)} && {(_enemyTest select 1) < (_world - 500)}
        } && {
            (_friendlyTest select 0) > 500 && {(_friendlyTest select 1) > 500} && {(_friendlyTest select 0) < (_world - 500)} && {(_friendlyTest select 1) < (_world - 500)}
        };
        if (_valid) exitWith {_axis = _candidateAxis; _foundAxis = true};
    };
};
if (!_foundAxis) then {_axis = 90};

private _makeNode = {
    params ["_key", "_min", "_max", "_bearing", "_spread", "_road"];
    private _pos = [_aoCenter, _min, _max, _bearing, _spread, _road, 1200] call DRO2026_fnc_findStrategicPosition;
    DRO2026_reservedObjectivePositions pushBack _pos;
    DRO2026_theaterNodes set [_key, _pos];
    _pos
};

DRO2026_theaterNodes set ["AO_CENTER", _aoCenter];
DRO2026_theaterNodes set ["AXIS", _axis];

// Enemy east / friendly west by design when geometry permits.
["ENEMY_TACTICAL_REAR", 2600, 4300, _axis, 45, true] call _makeNode;
["ENEMY_ARTILLERY", 4200, 6800, _axis + 10, 55, false] call _makeNode;
["ENEMY_AA_SHORAD", 4300, 6900, _axis - 18, 50, false] call _makeNode;
["ENEMY_AA_LONG", 8200, 11800, _axis, 28, false] call _makeNode;
["ENEMY_DRONE_FORWARD", 2500, 4700, _axis - 30, 55, false] call _makeNode;
["ENEMY_DRONE_REAR", 6500, 9800, _axis + 25, 45, false] call _makeNode;
["ENEMY_LOGISTICS", 7600, 11800, _axis + 8, 40, true] call _makeNode;
["ENEMY_EW", 4500, 7200, _axis + 45, 50, false] call _makeNode;
["ENEMY_HQ", 9200, 12800, _axis - 10, 28, false] call _makeNode;

["FRIENDLY_FORWARD", 2600, 4300, _axis + 180, 45, true] call _makeNode;
["FRIENDLY_REAR", 6500, 10400, _axis + 180, 45, true] call _makeNode;
["FRIENDLY_AA_SHORAD", 4200, 6800, _axis + 198, 50, false] call _makeNode;
["FRIENDLY_AA_LONG", 8100, 11600, _axis + 180, 28, false] call _makeNode;
["FRIENDLY_DRONE_FORWARD", 2400, 4200, _axis + 200, 50, false] call _makeNode;
["FRIENDLY_DRONE_REAR", 6200, 9400, _axis + 160, 45, false] call _makeNode;
["FRIENDLY_LOGISTICS", 7200, 10400, _axis + 170, 40, true] call _makeNode;
["FRIENDLY_HQ", 9200, 12600, _axis + 188, 28, false] call _makeNode;

DRO2026_theaterNodes set ["FRIENDLY_DRONE_SITE", DRO2026_theaterNodes get "FRIENDLY_DRONE_REAR"];
missionNamespace setVariable ["DRO2026_theaterBuilt", true];
[format ["Театральный граф RC3 создан. Ось %1° (красные восточнее, синие западнее), узлов %2", round _axis, count DRO2026_theaterNodes]] call DRO2026_fnc_log;
DRO2026_theaterNodes
