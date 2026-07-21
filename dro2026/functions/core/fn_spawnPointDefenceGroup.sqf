params [
    ["_nodeId","",[""]],
    ["_side",enemySide,[east]],
    ["_bearing",0,[0]]
];
if (!isServer || {_nodeId == ""}) exitWith {objNull};
private _existing = DRO2026_sites select {(_x getOrDefault ["type",""]) == "POINT_DEFENCE" && {(_x getOrDefault ["networkNodeId",""]) == _nodeId} && {!((_x getOrDefault ["status","ACTIVE"]) in ["DESTROYED","CANCELLED"])}};
if (count _existing > 0) exitWith {(_existing select 0) getOrDefault ["object",objNull]};
private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
private _position = _node getOrDefault ["position",[]];
if (count _position < 2) exitWith {objNull};
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _pool = DRO2026_assetRegistry getOrDefault [format ["SHORAD_%1",_suffix],[]];
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
_pool = _pool select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
};
private _gunPool = _pool select {
    private _name = toLowerANSI _x;
    (_name find "kamaz") >= 0 || {(_name find "ural") >= 0} || {(_name find "gaz66") >= 0} || {(_name find "zu23") >= 0} || {(_name find "zsu") >= 0}
};
if (count _gunPool == 0) then {_gunPool = _pool};
if (count _gunPool == 0) exitWith {objNull};
private _class = _gunPool select (floor ([count _gunPool,format ["POINT_DEFENCE_%1",_nodeId],0] call DRO2026_fnc_seededRandom));
private _spawn = _position getPos [180 + ([160,format ["POINT_DEFENCE_DISTANCE_%1",_nodeId],0] call DRO2026_fnc_seededRandom),_bearing + ([120,format ["POINT_DEFENCE_BEARING_%1",_nodeId],-60] call DRO2026_fnc_seededRandom)];
private _empty = _spawn findEmptyPosition [0,35,_class];
if (count _empty >= 2) then {_spawn = _empty};
private _vehicle = createVehicle [_class,_spawn,[],0,"NONE"];
if (isNull _vehicle) exitWith {objNull};
_vehicle setDir (_spawn getDir _position);
_vehicle setVehiclePosition [_spawn,[],0,"NONE"];
if !([_vehicle,_side] call DRO2026_fnc_crewManagedVehicle) exitWith {objNull};
_vehicle setVariable ["DRO2026_networkNodeId",_nodeId,true];
_vehicle setVariable ["DRO2026_pointDefence",true,true];
_vehicle setVariable ["DRO2026_pointDefenceRounds",0];
_vehicle addEventHandler ["Fired",{
    params ["_unit","_weapon","_muzzle","_mode","_ammo"];
    if (!isServer) exitWith {};
    private _cfg = configFile >> "CfgAmmo" >> _ammo;
    private _simulation = toLowerANSI getText (_cfg >> "simulation");
    if !(_simulation in ["shotbullet","shotshell","shotmissile","shotrocket"]) exitWith {};
    private _rounds = (_unit getVariable ["DRO2026_pointDefenceRounds",0]) + 1;
    private _batch = if (_simulation in ["shotmissile","shotrocket"]) then {1} else {25};
    if (_rounds >= _batch) then {
        _rounds = 0;
        private _nodeId = _unit getVariable ["DRO2026_networkNodeId",""];
        if (_nodeId != "") then {[_nodeId,"POINT_DEFENCE_AMMO",-1,"POINT_DEFENCE_FIRE"] call DRO2026_fnc_changeNetworkNodeStock};
    };
    _unit setVariable ["DRO2026_pointDefenceRounds",_rounds];
}];
private _components = createHashMapFromArray [["crew",crew _vehicle],["guards",[]],["launchers",[_vehicle]],["antennas",[]],["terminals",[]],["generators",[]],["stocks",[]],["transports",[_vehicle]],["camouflage",[]],["staticProps",[]]];
private _extra = createHashMapFromArray [["networkNodeId",_nodeId],["side",_side],["components",_components],["role","ANTI_DRONE_GUN"]];
private _site = ["POINT_DEFENCE",_spawn,_vehicle,[_vehicle],_extra] call DRO2026_fnc_createSiteRecord;
DRO2026_sites pushBack _site;
private _refs = _node getOrDefault ["physicalRefs",[]];
_refs pushBackUnique _vehicle;
_node set ["physicalRefs",_refs];
private _stocks = _node getOrDefault ["stocks",createHashMap];
_stocks set ["POINT_DEFENCE_AMMO",(_stocks getOrDefault ["POINT_DEFENCE_AMMO",8]) max 8];
_node set ["stocks",_stocks];
DRO2026_networkNodes set [_nodeId,_node];
DRO2026_managedVehicles pushBackUnique _vehicle;
["POINT_DEFENCE_DEPLOYED",createHashMapFromArray [["nodeId",_nodeId],["class",_class],["position",_spawn]],_nodeId] call DRO2026_fnc_emitEvent;
_vehicle