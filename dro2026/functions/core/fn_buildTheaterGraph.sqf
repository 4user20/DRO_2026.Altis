if (missionNamespace getVariable ["DRO2026_theaterBuilt", false]) exitWith {DRO2026_theaterLayout};
private _aoCenter = if (count AOLocations > 0) then {(AOLocations select 0) select 0} else {centerPos};
private _preferredAxes = [90,75,105,60,120,45,135,30,150];
private _axis = 90;
private _foundAxis = false;
{
    private _candidateAxis = _x;
    private _enemyTest = _aoCenter getPos [7800,_candidateAxis];
    private _friendlyTest = _aoCenter getPos [7600,(_candidateAxis + 180) mod 360];
    private _world = worldSize;
    private _valid = !surfaceIsWater _enemyTest && {!surfaceIsWater _friendlyTest} && {
        (_enemyTest select 0) > 600 && {(_enemyTest select 1) > 600} &&
        {(_enemyTest select 0) < (_world - 600)} && {(_enemyTest select 1) < (_world - 600)}
    } && {
        (_friendlyTest select 0) > 600 && {(_friendlyTest select 1) > 600} &&
        {(_friendlyTest select 0) < (_world - 600)} && {(_friendlyTest select 1) < (_world - 600)}
    };
    if (_valid) exitWith {_axis = _candidateAxis; _foundAxis = true};
} forEach _preferredAxes;
if (!_foundAxis) then {
    for "_i" from 0 to 23 do {
        private _candidateAxis = (90 + (_i * 15)) mod 360;
        private _enemyTest = _aoCenter getPos [7600,_candidateAxis];
        private _friendlyTest = _aoCenter getPos [7000,(_candidateAxis + 180) mod 360];
        private _world = worldSize;
        private _valid = !surfaceIsWater _enemyTest && {!surfaceIsWater _friendlyTest} && {
            (_enemyTest select 0) > 500 && {(_enemyTest select 1) > 500} &&
            {(_enemyTest select 0) < (_world - 500)} && {(_enemyTest select 1) < (_world - 500)}
        } && {
            (_friendlyTest select 0) > 500 && {(_friendlyTest select 1) > 500} &&
            {(_friendlyTest select 0) < (_world - 500)} && {(_friendlyTest select 1) < (_world - 500)}
        };
        if (_valid) exitWith {_axis = _candidateAxis; _foundAxis = true};
    };
};
if (!_foundAxis) then {_axis = 90};

private _setLayoutNode = {
    params ["_key","_position"];
    if (_position isEqualType [] && {count _position >= 2}) then {
        private _position3D = [_position param [0,0,[0]],_position param [1,0,[0]],_position param [2,0,[0]]];
        DRO2026_theaterLayout set [_key,+_position3D];
        DRO2026_theaterNodes set [_key,+_position3D];
    };
};
private _makeLayoutNode = {
    params ["_key","_min","_max","_bearing","_spread","_road"];
    if (!isNil {DRO2026_theaterLayout get _key}) exitWith {DRO2026_theaterLayout get _key};
    private _pos = [_aoCenter,_min,_max,_bearing,_spread,_road,1200] call DRO2026_fnc_findStrategicPosition;
    DRO2026_reservedObjectivePositions pushBackUnique _pos;
    [_key,_pos] call _setLayoutNode;
    _pos
};
private _planPosition = {
    params ["_type",["_index",0]];
    private _matches = (missionNamespace getVariable ["DRO2026_strategicPlan",[]]) select {
        (_x getOrDefault ["type",""]) == _type && {_x getOrDefault ["selected",false]}
    };
    if (_index >= count _matches) exitWith {[]};
    +((_matches select _index) getOrDefault ["positionATL",[]])
};

DRO2026_theaterLayout set ["AO_CENTER",+_aoCenter];
DRO2026_theaterLayout set ["AXIS",_axis];
DRO2026_theaterNodes set ["AO_CENTER",+_aoCenter];
DRO2026_theaterNodes set ["AXIS",_axis];

[] call DRO2026_fnc_registerStrategicAssets;
[] call DRO2026_fnc_buildStrategicPlan;

private _strategicMappings = [
    ["ENEMY_AA_LONG","S300_BATTERY"],
    ["ENEMY_AA_SHORAD","SHORAD_SITE"],
    ["ENEMY_ARTILLERY","ARTILLERY_SITE"],
    ["ENEMY_DRONE_REAR","BM35_LAUNCH_SITE"],
    ["ENEMY_LOGISTICS","INDUSTRIAL_LOGISTICS"],
    ["ENEMY_EW","EARLY_WARNING_RADAR"],
    ["ENEMY_HQ","COMMAND_LOGISTICS_COMPOUND"],
    ["ENEMY_DRONE_FORWARD","SPECIAL_FORCES"],
    ["ENEMY_TACTICAL_REAR","BALLISTIC_MISSILE_SITE"]
];
{
    _x params ["_layoutKey","_planType"];
    private _position = [_planType] call _planPosition;
    if (count _position >= 2) then {[_layoutKey,_position] call _setLayoutNode};
} forEach _strategicMappings;

["ENEMY_TACTICAL_REAR",2600,4300,_axis,45,true] call _makeLayoutNode;
["ENEMY_ARTILLERY",4200,6800,_axis + 10,55,false] call _makeLayoutNode;
["ENEMY_AA_SHORAD",4300,6900,_axis - 18,50,false] call _makeLayoutNode;
["ENEMY_AA_LONG",8200,11800,_axis,28,false] call _makeLayoutNode;
["ENEMY_DRONE_FORWARD",2500,4700,_axis - 30,55,false] call _makeLayoutNode;
["ENEMY_DRONE_REAR",6500,9800,_axis + 25,45,false] call _makeLayoutNode;
["ENEMY_LOGISTICS",7600,11800,_axis + 8,40,true] call _makeLayoutNode;
["ENEMY_EW",4500,7200,_axis + 45,50,false] call _makeLayoutNode;
["ENEMY_HQ",9200,12800,_axis - 10,28,false] call _makeLayoutNode;

["FRIENDLY_FORWARD",2600,4300,_axis + 180,45,true] call _makeLayoutNode;
["FRIENDLY_REAR",6500,10400,_axis + 180,45,true] call _makeLayoutNode;
["FRIENDLY_AA_SHORAD",4200,6800,_axis + 198,50,false] call _makeLayoutNode;
["FRIENDLY_AA_LONG",8100,11600,_axis + 180,28,false] call _makeLayoutNode;
["FRIENDLY_DRONE_FORWARD",2400,4200,_axis + 200,50,false] call _makeLayoutNode;
["FRIENDLY_DRONE_REAR",6200,9400,_axis + 160,45,false] call _makeLayoutNode;
["FRIENDLY_LOGISTICS",7200,10400,_axis + 170,40,true] call _makeLayoutNode;
["FRIENDLY_HQ",9200,12600,_axis + 188,28,false] call _makeLayoutNode;

["FRIENDLY_DRONE_SITE",DRO2026_theaterLayout get "FRIENDLY_DRONE_REAR"] call _setLayoutNode;
missionNamespace setVariable ["DRO2026_theaterBuilt",true];
["THEATER_LAYOUT_BUILT",createHashMapFromArray [
    ["axis",_axis],["positions",count DRO2026_theaterLayout],
    ["seed",missionNamespace getVariable ["DRO2026_operationSeed",1]],
    ["strategicPlanEntries",count (missionNamespace getVariable ["DRO2026_strategicPlan",[]])]
],"SYSTEM"] call DRO2026_fnc_emitEvent;
if (isServer) then {[] call DRO2026_fnc_buildCapabilityNetwork};
[format ["Театральная раскладка создана. Ось %1°, позиций %2, seed %3",round _axis,count DRO2026_theaterLayout,missionNamespace getVariable ["DRO2026_operationSeed",1]]] call DRO2026_fnc_log;
DRO2026_theaterLayout
