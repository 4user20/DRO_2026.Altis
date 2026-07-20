if (!isServer) exitWith {createHashMap};
private _descriptors = createHashMap;
private _collect = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith {createHashMap};
    private _weapons = []; private _magazines = [];
    {private _name = configName _x; if (_name == "weapons") then {_weapons append getArray _x}; if (_name == "magazines") then {_magazines append getArray _x}} forEach (configProperties [_cfg,"isArray _x",true]);
    _weapons = (_weapons select {_x isEqualType "" && {_x != ""} && {isClass (configFile >> "CfgWeapons" >> _x)}}) arrayIntersect _weapons;
    _magazines = (_magazines select {_x isEqualType "" && {_x != ""} && {isClass (configFile >> "CfgMagazines" >> _x)}}) arrayIntersect _magazines;
    private _muzzles = []; private _ammo = []; private _airMuzzles = []; private _airAmmo = []; private _maxRange = 0;
    {
        private _weapon = _x; private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;
        private _weaponMuzzles = getArray (_weaponCfg >> "muzzles"); if (count _weaponMuzzles == 0) then {_weaponMuzzles = [_weapon]};
        {
            private _muzzle = _x; _muzzles pushBackUnique _muzzle;
            private _muzzleCfg = if (_muzzle == _weapon) then {_weaponCfg} else {_weaponCfg >> _muzzle};
            private _mags = getArray (_muzzleCfg >> "magazines"); if (count _mags == 0) then {_mags = getArray (_weaponCfg >> "magazines")};
            {
                if (isClass (configFile >> "CfgMagazines" >> _x)) then {
                    _magazines pushBackUnique _x;
                    private _ammoClass = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
                    if (_ammoClass != "" && {isClass (configFile >> "CfgAmmo" >> _ammoClass)}) then {
                        _ammo pushBackUnique _ammoClass; private _ammoCfg = configFile >> "CfgAmmo" >> _ammoClass;
                        private _airCapable = getNumber (_ammoCfg >> "airLock") > 0 || {getNumber (_ammoCfg >> "irLock") > 0} || {getNumber (_ammoCfg >> "laserLock") > 0} || {getNumber (_ammoCfg >> "weaponLockSystem") > 0};
                        if (_airCapable) then {_airMuzzles pushBackUnique _muzzle; _airAmmo pushBackUnique _ammoClass};
                        _maxRange = _maxRange max getNumber (_ammoCfg >> "maxControlRange") max getNumber (_ammoCfg >> "missileLockMaxDistance") max getNumber (_ammoCfg >> "maxRange");
                    };
                };
            } forEach _mags;
        } forEach _weaponMuzzles;
    } forEach _weapons;
    private _sensorRoot = _cfg >> "Components" >> "SensorsManagerComponent" >> "Components";
    private _sensorCount = if (isClass _sensorRoot) then {count _sensorRoot} else {0};
    private _capabilities = [];
    if (_class isKindOf "Air") then {_capabilities pushBack "FLIGHT"};
    if (getNumber (_cfg >> "isUav") > 0) then {_capabilities pushBack "UAV"};
    if (_sensorCount > 0) then {_capabilities append ["SENSOR","RECON"]};
    if (count _weapons > 0) then {_capabilities pushBack "WEAPON"};
    if (count _ammo > 0) then {_capabilities pushBack "KINETIC_EFFECT"};
    if (count _airMuzzles > 0) then {_capabilities pushBack "AIR_INTERCEPT"};
    createHashMapFromArray [
        ["schema",2],["vehicleClass",_class],["launcherClass",""] ,["weaponClass",if (count _weapons > 0) then {_weapons select 0} else {""}],["weaponClasses",_weapons],
        ["muzzleName",if (count _muzzles > 0) then {_muzzles select 0} else {""}],["muzzleNames",_muzzles],["airMuzzles",_airMuzzles],
        ["magazineClass",if (count _magazines > 0) then {_magazines select 0} else {""}],["magazineClasses",_magazines],
        ["ammoClass",if (count _ammo > 0) then {_ammo select 0} else {""}],["ammoClasses",_ammo],["airAmmoClasses",_airAmmo],
        ["roles",[]],["capabilities",_capabilities arrayIntersect _capabilities],["canEngageAir",count _airMuzzles > 0],["engagementRange",_maxRange max 2500],
        ["sideNumber",getNumber (_cfg >> "side")],["faction",getText (_cfg >> "faction")],["displayName",getText (_cfg >> "displayName")],["sensorCount",_sensorCount]
    ]
};
{
    private _role = _x;
    {
        private _descriptor = _descriptors getOrDefault [_x,createHashMap]; if (count _descriptor == 0) then {_descriptor = [_x] call _collect};
        if (count _descriptor > 0) then {private _roles = _descriptor getOrDefault ["roles",[]]; _roles pushBackUnique _role; _descriptor set ["roles",_roles]; if ((_role find "LAUNCHER_") == 0) then {_descriptor set ["launcherClass",_x]}; _descriptors set [_x,_descriptor]};
    } forEach (DRO2026_assetRegistry getOrDefault [_role,[]]);
} forEach keys DRO2026_assetRegistry;
private _vehicleRoot = configFile >> "CfgVehicles";
for "_i" from 0 to ((count _vehicleRoot)-1) do {
    private _cfg = _vehicleRoot select _i;
    if (isClass _cfg && {getNumber (_cfg >> "scope") >= 2}) then {
        private _class = configName _cfg; private _hay = toLowerANSI format ["%1 %2",_class,getText (_cfg >> "displayName")];
        if ((_hay find "p1sun") >= 0 || {(_hay find "p1-sun") >= 0} || {(_hay find "sting") >= 0}) then {
            private _descriptor = [_class] call _collect;
            if (_descriptor getOrDefault ["canEngageAir",false]) then {
                private _sideSuffix = switch getNumber (_cfg >> "side") do {case 1:{"WEST"}; case 2:{"GUER"}; default {"EAST"}};
                private _role = format ["INTERCEPTOR_%1",_sideSuffix]; private _pool = DRO2026_assetRegistry getOrDefault [_role,[]]; _pool pushBackUnique _class; DRO2026_assetRegistry set [_role,_pool];
                private _roles = _descriptor getOrDefault ["roles",[]]; _roles pushBackUnique _role; _descriptor set ["roles",_roles]; _descriptors set [_class,_descriptor];
            };
        };
    };
};
DRO2026_assetDescriptors = _descriptors; missionNamespace setVariable ["DRO2026_assetDescriptors",_descriptors];
["REGISTRY","DESCRIPTORS_BUILT",createHashMapFromArray [["count",count _descriptors]],"ASSET_REGISTRY"] call DRO2026_fnc_logStructured;
_descriptors
