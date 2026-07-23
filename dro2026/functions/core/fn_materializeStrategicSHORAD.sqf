params [["_side",enemySide,[east]],["_maxSites",3,[0]]];
if (!isServer) exitWith {[]};
private _limit = (_maxSites max 0) min 4;
if (_limit <= 0) exitWith {
    ["AIR_DEFENCE","SHORAD_MATERIALIZATION_SKIPPED",createHashMapFromArray [["reason","LIMIT_ZERO"]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
    []
};
private _plan = missionNamespace getVariable ["DRO2026_strategicPlan",[]];
private _entries = _plan select {(_x getOrDefault ["type",""]) == "SHORAD_SITE" && {!(_x getOrDefault ["activated",false])}};
if (count _entries == 0) exitWith {[]};
private _suffix = [_side] call DRO2026_fnc_getSideSuffix;
private _blocked = missionNamespace getVariable ["DRO2026_runtimeBlockedVehicleClasses",[]];
private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
private _dangerousTokens = ["spawner","module","logic","dummy","placeholder","_root","site_","samsite","sam_site","azncontrol","unit_scanner"];
private _pool = +(DRO2026_assetRegistry getOrDefault [format ["SHORAD_%1",_suffix],[]]);
_pool = _pool select {
    private _class = _x;
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _lower = toLowerANSI _class;
    private _role = [_class] call DRO2026_fnc_getAssetPrimaryRole;
    isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {getNumber (_cfg >> "isBackpack") == 0} &&
    {getText (_cfg >> "model") != ""} && {!(_class in _blocked)} &&
    {(_dangerousTokens findIf {(_lower find _x) >= 0}) < 0} &&
    {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}} &&
    {_role in ["SHORAD","SAM_SHORT_RANGE","SAM_MEDIUM_RANGE"]}
};
private _shortPool = _pool select {([_x] call DRO2026_fnc_getAssetPrimaryRole) in ["SHORAD","SAM_SHORT_RANGE"]};
private _degraded = count _shortPool == 0;
private _primaryPool = if (_degraded) then {_pool} else {_shortPool};
if (count _primaryPool == 0) exitWith {
    ["AIR_DEFENCE","SHORAD_MATERIALIZATION_REJECTED",createHashMapFromArray [["reason","NO_VALID_CONCRETE_CLASS"],["planned",count _entries]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
    []
};
private _missilePool = _primaryPool select {
    private _n = toLowerANSI _x;
    (_n find "96k6") >= 0 || {(_n find "pantsir") >= 0} || {(_n find "9k332") >= 0} || {(_n find "tor") >= 0} || {(_n find "tungus") >= 0} || {(_n find "_aa_f") >= 0}
};
private _gunPool = _primaryPool select {
    private _n = toLowerANSI _x;
    (_n find "zu23") >= 0 || {(_n find "zsu") >= 0} || {(_n find "shilka") >= 0} || {(_n find "tungus") >= 0} || {(_n find "2s6") >= 0}
};
private _cleanupObjects = {
    params ["_objects"];
    private _groups = [];
    {
        if (!isNull _x) then {
            {if (!isNull _x) then {_groups pushBackUnique (group _x)}} forEach crew _x;
        };
    } forEach _objects;
    DRO2026_managedGroups = DRO2026_managedGroups select {!isNull _x && {!(_x in _groups)}};
    DRO2026_managedVehicles = DRO2026_managedVehicles select {!isNull _x && {!(_x in _objects)}};
    {
        if (!isNull _x && {local _x}) then {deleteVehicleCrew _x; deleteVehicle _x};
    } forEach _objects;
    {if (!isNull _x) then {deleteGroup _x}} forEach _groups;
};
private _spawned = [];
for "_siteIndex" from 0 to (((count _entries) min _limit) - 1) do {
    private _entry = _entries select _siteIndex;
    private _anchor = +(_entry getOrDefault ["positionATL",[]]);
    if (count _anchor >= 2) then {
        if (count _anchor == 2) then {_anchor pushBack 0};
        _anchor set [2,0];
        private _selectionPool = if (count _missilePool > 0) then {_missilePool} else {_primaryPool};
        private _primaryClass = _selectionPool select (floor ([count _selectionPool,format ["SHORAD_PRIMARY_%1",_siteIndex],0] call DRO2026_fnc_seededRandom));
        private _classes = [_primaryClass];
        if (count _gunPool > 0 && {_siteIndex < 2}) then {
            private _gunClass = _gunPool select (floor ([count _gunPool,format ["SHORAD_GUN_%1",_siteIndex],0] call DRO2026_fnc_seededRandom));
            if (_gunClass != _primaryClass) then {_classes pushBack _gunClass};
        };
        private _objects = [];
        {
            private _class = _x;
            private _pos = _anchor getPos [35 + (_forEachIndex * 65),(_entry getOrDefault ["heading",0]) + 90 + (_forEachIndex * 150)];
            private _safe = [_pos,0,35,10,0,0.35,0,[],[_pos,_pos]] call BIS_fnc_findSafePos;
            if (count _safe >= 2) then {_pos = +_safe};
            if (count _pos == 2) then {_pos pushBack 0};
            _pos set [2,0];
            private _empty = _pos findEmptyPosition [0,20,_class];
            if (count _empty >= 2) then {_pos = _empty};
            private _vehicle = createVehicle [_class,_pos,[],0,"NONE"];
            if (!isNull _vehicle) then {
                _vehicle enableDynamicSimulation true;
                _vehicle setDir (_pos getDir _anchor);
                _vehicle setVehiclePosition [_pos,[],0,"NONE"];
                if ([_vehicle,_side] call DRO2026_fnc_crewManagedVehicle) then {
                    private _crewGroup = if (count crew _vehicle > 0) then {group (crew _vehicle select 0)} else {grpNull};
                    if (!isNull _crewGroup) then {_crewGroup enableDynamicSimulation true};
                    _vehicle setVariable ["DRO2026_networkNodeId","NODE_AA_SHORAD_01",true];
                    _vehicle setVariable ["DRO2026_shoradLayer",_siteIndex,true];
                    _objects pushBack _vehicle;
                };
            };
        } forEach _classes;
        if (count _objects > 0) then {
            private _siteCrew = [];
            {{_siteCrew pushBackUnique _x} forEach crew _x} forEach _objects;
            private _components = createHashMapFromArray [["crew",_siteCrew],["guards",[]],["launchers",_objects],["antennas",[]],["terminals",[]],["generators",[]],["stocks",[]],["transports",_objects],["camouflage",[]],["staticProps",[]]];
            private _planId = _entry getOrDefault ["id",format ["PLAN_SHORAD_%1",_siteIndex]];
            private _extra = createHashMapFromArray [["networkNodeId","NODE_AA_SHORAD_01"],["side",_side],["components",_components],["planId",_planId],["layerIndex",_siteIndex],["degradedMediumRange",_degraded]];
            private _site = ["SHORAD_SITE",_anchor,_objects select 0,_objects,_extra] call DRO2026_fnc_createSiteRecord;
            if (count _site > 0 && {[_site,true] call DRO2026_fnc_validateSiteRecord}) then {
                DRO2026_sites pushBack _site;
                private _node = DRO2026_networkNodes getOrDefault ["NODE_AA_SHORAD_01",createHashMap];
                if (count _node > 0) then {
                    private _refs = _node getOrDefault ["physicalRefs",[]];
                    {_refs pushBackUnique _x} forEach _objects;
                    _node set ["physicalRefs",_refs];
                    DRO2026_networkNodes set ["NODE_AA_SHORAD_01",_node];
                };
                _entry set ["activated",true];
                _entry set ["state","ACTIVE"];
                _entry set ["physicalState","ACTIVE"];
                _entry set ["objects",_objects];
                _spawned append _objects;
                ["SHORAD_FORMATION_MATERIALIZED",createHashMapFromArray [["planId",_planId],["layerIndex",_siteIndex],["classes",_classes],["objects",count _objects],["position",_anchor],["degradedMediumRange",_degraded]],_planId] call DRO2026_fnc_emitEvent;
            } else {
                [_objects] call _cleanupObjects;
                ["AIR_DEFENCE","SHORAD_MATERIALIZATION_REJECTED",createHashMapFromArray [["planId",_planId],["reason","SITE_VALIDATION_FAILED"],["classes",_classes]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
            };
        } else {
            ["AIR_DEFENCE","SHORAD_MATERIALIZATION_REJECTED",createHashMapFromArray [["planId",_entry getOrDefault ["id",""]],["reason","CREW_OR_CREATE_FAILED"],["classes",_classes]],"SHORAD_PLAN"] call DRO2026_fnc_logStructured;
        };
    };
};
missionNamespace setVariable ["DRO2026_strategicPlan",_plan,true];
_spawned
