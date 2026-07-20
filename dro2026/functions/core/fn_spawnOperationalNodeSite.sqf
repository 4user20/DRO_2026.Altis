params [
    ["_nodeId","",[""]],
    ["_siteType","OPERATIONAL_SITE",[""]],
    ["_side",enemySide,[east]],
    ["_primaryRole","",[""]],
    ["_direction",0,[0]]
];
if (!isServer || {_nodeId == ""}) exitWith {[]};
private _existing = DRO2026_sites select {(_x getOrDefault ["networkNodeId",""]) == _nodeId && {!((_x getOrDefault ["status","ACTIVE"]) in ["DESTROYED","CANCELLED"])} };
if (count _existing > 0) exitWith {_existing};
private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
if (count _node == 0) exitWith {[]};
private _position = +(_node getOrDefault ["position",[]]);
if (count _position < 2) exitWith {[]};
private _template = [_siteType,_position,_side,_direction] call DRO2026_fnc_createSiteComponents;
private _objects = +(_template getOrDefault ["objects",[]]);
private _components = _template getOrDefault ["components",createHashMap];
private _primary = objNull;
if (_primaryRole != "") then {
    private _pool = DRO2026_assetRegistry getOrDefault [_primaryRole,[]];
    private _sideNumber = [_side] call DRO2026_fnc_getSideNumber;
    _pool = _pool select {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        isClass _cfg && {getNumber (_cfg >> "scope") >= 1} && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}
    };
    if (count _pool > 0) then {
        private _class = _pool select 0;
        private _spawn = _position getPos [18,_direction + 35];
        private _empty = _spawn findEmptyPosition [0,22,_class];
        if (count _empty >= 2) then {_spawn = _empty};
        _primary = createVehicle [_class,_spawn,[],0,"NONE"];
        if (!isNull _primary) then {
            _primary setDir _direction;
            _primary setVehiclePosition [_spawn,[],0,"NONE"];
            _primary setVariable ["DRO2026_networkNodeId",_nodeId,true];
            if (_primary isKindOf "AllVehicles") then {
                [_primary,_side] call DRO2026_fnc_crewManagedVehicle;
                DRO2026_managedVehicles pushBackUnique _primary;
            };
            _objects pushBackUnique _primary;
            private _launchers = _components getOrDefault ["launchers",[]];
            _launchers pushBackUnique _primary;
            _components set ["launchers",_launchers];
        };
    };
};
if (isNull _primary) then {
    private _priority = [];
    { _priority append (_components getOrDefault [_x,[]]) } forEach ["terminals","stocks","antennas","staticProps"];
    _priority = _priority select {!isNull _x};
    if (count _priority > 0) then {_primary = _priority select 0};
};
if (isNull _primary) exitWith {{if (!isNull _x && {local _x}) then {deleteVehicle _x}} forEach _objects; []};
private _extra = createHashMapFromArray [
    ["networkNodeId",_nodeId],["side",_side],["components",_components],
    ["virtual",false],["operationSeed",missionNamespace getVariable ["DRO2026_operationSeed",1]]
];
private _site = [_siteType,_position,_primary,_objects,_extra] call DRO2026_fnc_createSiteRecord;
if !([_site,true] call DRO2026_fnc_validateSiteRecord) exitWith {{if (!isNull _x && {local _x}) then {deleteVehicleCrew _x; deleteVehicle _x}} forEach _objects; []};
DRO2026_sites pushBack _site;
_node set ["physicalRefs",+_objects];
_node set ["physicalState","ACTIVE"];
_node set ["lastUpdatedAt",time];
DRO2026_networkNodes set [_nodeId,_node];
["OPERATIONAL_SITE_MATERIALIZED",createHashMapFromArray [
    ["nodeId",_nodeId],["siteType",_siteType],["objects",count _objects],["primary",typeOf _primary]
],_nodeId] call DRO2026_fnc_emitEvent;
[_site]