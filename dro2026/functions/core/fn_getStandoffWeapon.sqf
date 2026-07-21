params [["_vehicle",objNull,[objNull]]];
if (isNull _vehicle) exitWith {createHashMap};
private _turrets = [[-1]] + (allTurrets [_vehicle,true]);
private _solutions = [];
{
    private _turretPath = _x;
    {
        private _weapon = _x;
        private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;
        if (isClass _weaponCfg) then {
            private _muzzles = getArray (_weaponCfg >> "muzzles");
            if (count _muzzles == 0 || {_muzzles isEqualTo ["this"]}) then {_muzzles = [_weapon]};
            {
                private _muzzle = _x;
                private _muzzleCfg = if (_muzzle == _weapon) then {_weaponCfg} else {_weaponCfg >> _muzzle};
                private _magazines = getArray (_muzzleCfg >> "magazines");
                if (count _magazines == 0) then {_magazines = getArray (_weaponCfg >> "magazines")};
                {
                    private _magCfg = configFile >> "CfgMagazines" >> _x;
                    private _ammo = getText (_magCfg >> "ammo");
                    private _ammoCfg = configFile >> "CfgAmmo" >> _ammo;
                    if (isClass _ammoCfg) then {
                        private _simulation = toLowerANSI getText (_ammoCfg >> "simulation");
                        private _hit = getNumber (_ammoCfg >> "hit");
                        private _airLock = getNumber (_ammoCfg >> "airLock");
                        private _range = getNumber (_ammoCfg >> "maxControlRange") max getNumber (_ammoCfg >> "missileLockMaxDistance") max getNumber (_ammoCfg >> "maxRange");
                        private _guidedGround = getNumber (_ammoCfg >> "irLock") > 0 || {getNumber (_ammoCfg >> "laserLock") > 0} || {getNumber (_ammoCfg >> "nvLock") > 0} || {getNumber (_ammoCfg >> "manualControl") > 0};
                        if (_simulation in ["shotmissile","shotrocket"] && {_hit >= 80} && {_airLock <= 0} && {_range >= 1600} && {_guidedGround}) then {
                            _solutions pushBack createHashMapFromArray [
                                ["weapon",_weapon],["muzzle",_muzzle],["magazine",_x],["ammo",_ammo],
                                ["turretPath",+_turretPath],["range",_range],["hit",_hit]
                            ];
                        };
                    };
                } forEach _magazines;
            } forEach _muzzles;
        };
    } forEach (weaponsTurret [_vehicle,_turretPath]);
} forEach _turrets;
if (count _solutions == 0) exitWith {createHashMapFromArray [["ok",false],["code","NO_STANDOFF_WEAPON"]]};
_solutions = [_solutions,[],{-((_x getOrDefault ["range",0]) + ((_x getOrDefault ["hit",0]) * 3))},"ASCEND"] call BIS_fnc_sortBy;
private _best = _solutions select 0;
_best set ["ok",true];
_best