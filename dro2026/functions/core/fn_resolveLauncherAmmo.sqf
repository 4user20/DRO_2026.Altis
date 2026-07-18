params ["_launcherClass"];
if !(_launcherClass isEqualType "") exitWith {""};
private _cfgVehicle = configFile >> "CfgVehicles" >> _launcherClass;
if (!isClass _cfgVehicle) exitWith {""};

private _weapons = [];
{
    _weapons append (getArray _x);
} forEach (configProperties [_cfgVehicle, "isArray _x && {configName _x == 'weapons'}", true]);
_weapons = _weapons arrayIntersect _weapons;
private _resolved = "";
{
    private _weaponCfg = configFile >> "CfgWeapons" >> _x;
    if (isClass _weaponCfg) then {
        private _magazines = getArray (_weaponCfg >> "magazines");
        {
            private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
            if (_ammo != "" && {isClass (configFile >> "CfgAmmo" >> _ammo)}) exitWith {_resolved = _ammo};
        } forEach _magazines;
    };
    if (_resolved != "") exitWith {};
} forEach _weapons;
_resolved
