params [["_needle","P1SUN",[""]]];
if (!isServer) exitWith {[]};
private _token = toLowerANSI _needle; private _matches = []; private _root = configFile >> "CfgVehicles";
for "_index" from 0 to ((count _root)-1) do {
    private _cfg = _root select _index;
    if (isClass _cfg) then {
        private _class = configName _cfg; private _display = getText (_cfg >> "displayName");
        if (_token != "" && {(toLowerANSI format ["%1 %2",_class,_display] find _token) >= 0}) then {
            private _descriptor = DRO2026_assetDescriptors getOrDefault [_class,createHashMap];
            _matches pushBack createHashMapFromArray [["vehicleClass",_class],["displayName",_display],["side",getNumber (_cfg >> "side")],["faction",getText (_cfg >> "faction")],["weapons",_descriptor getOrDefault ["weaponClasses",[]]],["muzzles",_descriptor getOrDefault ["muzzleNames",[]]],["airMuzzles",_descriptor getOrDefault ["airMuzzles",[]]],["magazines",_descriptor getOrDefault ["magazineClasses",[]]],["ammo",_descriptor getOrDefault ["ammoClasses",[]]],["sensorComponents",_descriptor getOrDefault ["sensorCount",0]],["isUav",getNumber (_cfg >> "isUav")],["scope",getNumber (_cfg >> "scope")]];
        };
    };
};
missionNamespace setVariable [format ["DRO2026_assetDump_%1",toUpperANSI _needle],_matches];
["REGISTRY","CLASS_DUMP",createHashMapFromArray [["needle",_needle],["matches",count _matches],["records",_matches]],toUpperANSI _needle] call DRO2026_fnc_logStructured;
_matches
