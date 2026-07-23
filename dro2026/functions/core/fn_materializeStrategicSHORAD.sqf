params [["_side",enemySide,[east]],["_maxSites",3,[0]]];
if (!isServer) exitWith {[]};
private _plan = missionNamespace getVariable ["DRO2026_strategicPlan",[]];
private _entries = _plan select {(_x getOrDefault ["type",""]) == "SHORAD_SITE" && {!(_x getOrDefault ["activated",false])}};
if (count _entries == 0) exitWith {[]};
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _blocked = missionNamespace getVariable ["DRO2026_runtimeBlockedVehicleClasses",[]];
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
private _pool = +(DRO2026_assetRegistry getOrDefault [format ["SHORAD_%1",_suffix],[]]);
_pool = _pool select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {!(_x in _blocked)} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}} &&
    {([_x] call DRO2026_fnc_getAssetPrimaryRole) in ["SHORAD","SAM_SHORT_RANGE","SAM_MEDIUM_RANGE"]}
};
if (count _pool == 0) exitWith {
    ["AIR_DEFENCE","SHORAD_MATERIALIZATION_REJECTED",createHashMapFromArray [["reason","NO_VALID_CLASS"],["planned",count _entries]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
    []
};
private _missilePool = _pool select {
    private _n = toLowerANSI _x;
    (_n find "96k6") >= 0 || {(_n find "pantsir") >= 0} || {(_n find "9k332") >= 0} || {(_n find "tor") >= 0} || {(_n find "tungus") >= 0}
};
private _gunPool = _pool select {
    private _n = toLowerANSI _x;
    (_n find "zu23") >= 0 || {(_n find "zsu") >= 0} || {(_n find "shilka") >= 0} || {(_n find "kamaz") >= 0} || {(_n find "gaz66") >= 0}
};
private _spawned = [];
private _limit = (_maxSites max 1) min 4;
for "_siteIndex" from 0 to (((count _entries) min _limit) - 1) do {
    private _entry = _entries select _siteIndex;
    private _anchor = +(_entry getOrDefault ["positionATL",[]]);
    if (count _anchor >= 2) then {
        if (count _anchor == 2) then {_anchor pushBack 0};
        private _primaryPool = if (count _missilePool > 0) then {_missilePool} else {_pool};
        private _primaryClass = _primaryPool select (floor ([count _primaryPool,format ["SHORAD_PRIMARY_%1",_siteIndex],0] call DRO2026_fnc_seededRandom));
        private _classes = [_primaryClass];
        if (count _gunPool > 0 && {_siteIndex < 2}) then {
            private _gunClass = _gunPool select (floor ([count _gunPool,format ["SHORAD_GUN_%1",_siteIndex],0] call DRO2026_fnc_seededRandom));
            if (_gunClass != _primaryClass) then {_classes pushBack _gunClass};
        };
        private _objects = [];
        {
            private _pos = _anchor getPos [35 + (_forEachIndex * 65),(_entry getOrDefault ["heading",0]) + 90 + (_forEachIndex * 150)];
            private _safe = [_pos,0,35,10,0,0.35,0,[],[_pos,_pos]] call BIS_fnc_findSafePos;
            if !(_safe isEqualTo [0,0,0]) then {_pos = _safe};
            private _empty = _pos findEmptyPosition [0,20,_x];
            if (count _empty >= 2) then {_pos = _empty};
            private _vehicle = createVehicle [_x,_pos,[],0,"NONE"];
            if (!isNull _vehicle && {[_vehicle,_side] call DRO2026_fnc_crewManagedVehicle}) then {
                _vehicle setDir (_vehicle getDir _anchor);
                _vehicle setVariable ["DRO2026_networkNodeId","NODE_AA_SHORAD_01",true];
                _vehicle setVariable ["DRO2026_shoradLayer",_siteIndex,true];
                _vehicle enableDynamicSimulation true;
                DRO2026_managedVehicles pushBackUnique _vehicle;
                _objects pushBack _vehicle;
            } else {
                if (!isNull _vehicle) then {deleteVehicleCrew _vehicle; deleteVehicle _vehicle};
            };
        } forEach _classes;
        if (count _objects > 0) then {
            private _siteCrew = [];
            {_siteCrew append (crew _x)} forEach _objects;
            private _components = createHashMapFromArray [["crew",_siteCrew],["guards",[]],["launchers",_objects],["antennas",[]],["terminals",[]],["generators",[]],["stocks",[]],["transports",_objects],["camouflage",[]],["staticProps",[]]];
            private _siteId = _entry getOrDefault ["id",format ["PLAN_SHORAD_%1",_siteIndex]];
            private _extra = createHashMapFromArray [["networkNodeId","NODE_AA_SHORAD_01"],["side",_side],["components",_components],["planId",_siteId],["layerIndex",_siteIndex]];
            private _site = ["SHORAD_SITE",_anchor,_objects select 0,_objects,_extra] call DRO2026_fnc_createSiteRecord;
            DRO2026_sites pushBack _site;
            _entry set ["activated",true];
            _entry set ["state","ACTIVE"];
            _entry set ["physicalState","ACTIVE"];
            _entry set ["objects",_objects];
            _spawned append _objects;
            ["SHORAD_FORMATION_MATERIALIZED",createHashMapFromArray [["planId",_siteId],["layerIndex",_siteIndex],["classes",_classes],["objects",count _objects],["position",_anchor]],_siteId] call DRO2026_fnc_emitEvent;
        } else {
            ["AIR_DEFENCE","SHORAD_MATERIALIZATION_REJECTED",createHashMapFromArray [["planId",_entry getOrDefault ["id",""]],["reason","CREW_OR_CREATE_FAILED"],["classes",_classes]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
        };
    };
};
missionNamespace setVariable ["DRO2026_strategicPlan",_plan,true];
_spawned
