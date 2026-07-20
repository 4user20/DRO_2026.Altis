// Ambient civilian layer only. Hostage and hostile-civilian generation is intentionally disabled.
params [["_AOIndex",0,[0]]];
if (_AOIndex < 0 || {_AOIndex >= count AOLocations}) exitWith {};
private _ao = AOLocations select _AOIndex;
private _aoPos = _ao param [0,[0,0,0],[[]]];
private _aoMeta = _ao param [2,[],[[]]];
private _aoLocation = _ao param [5,locationNull];
private _classes = civClasses select {isClass (configFile >> "CfgVehicles" >> _x)};
if (count _classes == 0) exitWith {};
private _center = createCenter sideLogic;
private _logicGroup = createGroup _center;
private _safeSpots = [];
private _spawnPoints = [];
{
    if (_x isEqualType []) then {{if (_x isEqualType [] && {count _x > 1}) then {_spawnPoints pushBackUnique _x}} forEach _x};
} forEach [_aoMeta param [0,[]],_aoMeta param [2,[]],_aoMeta param [4,[]],_aoMeta param [7,[]]];
if (count _spawnPoints == 0) then {_spawnPoints pushBack _aoPos};
private _locationType = if (isNull _aoLocation) then {"NameLocal"} else {type _aoLocation};
private _limit = switch _locationType do {case "NameCityCapital":{14};case "NameCity":{11};case "NameVillage":{8};default{6}};
_limit = _limit min count _spawnPoints;
for "_index" from 0 to (_limit - 1) do {
    private _point = selectRandom _spawnPoints;
    private _module = _logicGroup createUnit ["ModuleCivilianPresenceUnit_F",_point,[],0,"FORM"];
    private _safe = _logicGroup createUnit ["ModuleCivilianPresenceSafeSpot_F",_point,[],0,"FORM"];
    _safe setVariable ["#useBuilding",true,true];
    _safe setVariable ["#type",1,true];
    _safe setVariable ["#terminal",false,true];
    _safe setVariable ["#capacity",3,true];
    _safe setVariable ["objectarea",[0.1,0.1,0,false,-1],true];
    _safeSpots pushBack _safe;
};
private _core = _logicGroup createUnit ["ModuleCivilianPresence_F",_aoPos,[],0,"FORM"];
_core setVariable ["#unitCount",_limit max 3,true];
_core setVariable ["#usePanicMode",true,true];
_core setVariable ["#useAgents",true,true];
_core setVariable ["#unitList",_classes,true];
_core setVariable ["#safeSpotModules",_safeSpots,true];
_core setVariable ["DRO2026_ambientCivilianLayer",true,true];

// A few road vehicles are physical, dynamically simulated and never weaponised.
if (count civCarClasses > 0) then {
    private _roadPoints = _aoMeta param [0,[]];
    for "_index" from 0 to ((2 min count _roadPoints) - 1) do {
        private _position = selectRandom _roadPoints;
        private _class = selectRandom (civCarClasses select {isClass (configFile >> "CfgVehicles" >> _x)});
        if (_class != "") then {
            private _empty = _position findEmptyPosition [0,30,_class];
            if (count _empty > 1) then {
                private _vehicle = createVehicle [_class,_empty,[],0,"NONE"];
                _vehicle enableDynamicSimulation true;
                private _road = [_empty,80] call BIS_fnc_nearestRoad;
                if (!isNull _road) then {_vehicle setDir (_road getDir ((roadsConnectedTo _road) param [0,_road]))};
            };
        };
    };
};
hostileCivsEnabled = false;
hostileCivilians = [];
publicVariable "hostileCivilians";
