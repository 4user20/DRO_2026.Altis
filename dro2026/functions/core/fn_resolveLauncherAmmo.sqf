params [["_launcherClass", "", [""]]];
private _cfgVehicle = configFile >> "CfgVehicles" >> _launcherClass;
if (_launcherClass == "" || {!isClass _cfgVehicle}) exitWith {""};

private _weapons = [];
{
    _weapons append (getArray _x);
} forEach (configProperties [_cfgVehicle, "isArray _x && {configName _x == 'weapons'}", true]);
_weapons = _weapons arrayIntersect _weapons;

private _blockedTokens = [
    "smoke", "flare", "chaff", "countermeasure", "cmflare",
    "fake", "dummy", "horn", "safeweapon", "laserdesignator"
];
private _preferredTokens = ["missile", "rocket", "ballistic", "iskander", "scud", "cruise", "warhead", "fp1", "fp2", "fp5", "bm35", "bulava", "shahed", "geran"];
private _candidates = [];

{
    private _weapon = _x;
    private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;
    if (isClass _weaponCfg) then {
        private _muzzles = getArray (_weaponCfg >> "muzzles");
        if (count _muzzles == 0) then {_muzzles = ["this"]};

        private _magazines = +(getArray (_weaponCfg >> "magazines"));
        {
            _magazines append (getArray _x);
        } forEach (configProperties [_weaponCfg, "isArray _x && {configName _x == 'magazines'}", true]);

        _magazines append (compatibleMagazines _weapon);
        {
            _magazines append (compatibleMagazines [_weapon, _x]);
        } forEach _muzzles;
        _magazines = _magazines arrayIntersect _magazines;

        {
            private _magazine = _x;
            private _magazineCfg = configFile >> "CfgMagazines" >> _magazine;
            if (isClass _magazineCfg) then {
                private _ammo = getText (_magazineCfg >> "ammo");
                private _ammoCfg = configFile >> "CfgAmmo" >> _ammo;
                if (_ammo != "" && {isClass _ammoCfg}) then {
                    private _simulation = toLowerANSI getText (_ammoCfg >> "simulation");
                    private _haystack = toLowerANSI format [
                        "%1 %2 %3 %4 %5",
                        _weapon,
                        _magazine,
                        _ammo,
                        getText (_weaponCfg >> "displayName"),
                        _simulation
                    ];
                    private _blocked = (_blockedTokens findIf {(_haystack find _x) >= 0}) >= 0;
                    private _preferredCount = {(_haystack find _x) >= 0} count _preferredTokens;
                    private _strategicSimulation =
                        (_simulation find "shotmissile") >= 0 ||
                        {(_simulation find "shotrocket") >= 0} ||
                        {(_simulation find "shotbomb") >= 0};
                    private _strategicCandidate = _strategicSimulation || {_preferredCount > 0};
                    private _score = if (_blocked || {!_strategicCandidate}) then {-100000} else {0};

                    if (!_blocked && {_strategicCandidate}) then {
                        if ((_simulation find "shotmissile") >= 0) then {_score = _score + 900};
                        if ((_simulation find "shotrocket") >= 0) then {_score = _score + 700};
                        if ((_simulation find "shotbomb") >= 0) then {_score = _score + 500};
                        _score = _score + (250 * _preferredCount);
                        _score = _score + (((getNumber (_ammoCfg >> "hit")) min 1000) * 0.35);
                        _score = _score + (((getNumber (_ammoCfg >> "indirectHit")) min 500) * 0.20);
                        _score = _score + (((getNumber (_ammoCfg >> "indirectHitRange")) min 100) * 1.5);
                        _score = _score + (((getNumber (_ammoCfg >> "maxSpeed")) min 2500) * 0.05);
                        _score = _score + (((getNumber (_ammoCfg >> "timeToLive")) min 600) * 0.5);
                        _score = _score + ((getNumber (_ammoCfg >> "explosive")) * 80);
                        _score = _score + ((getNumber (_ammoCfg >> "irLock")) * 20);
                        _score = _score + ((getNumber (_ammoCfg >> "laserLock")) * 20);
                        _score = _score + ((getNumber (_ammoCfg >> "nvLock")) * 10);
                    };

                    _candidates pushBack [_score, _ammo, _magazine, _weapon];
                };
            };
        } forEach _magazines;
    };
} forEach _weapons;

if (count _candidates == 0) exitWith {""};
_candidates = [_candidates, [], {-(_x select 0)}, "ASCEND"] call BIS_fnc_sortBy;
private _best = _candidates select 0;
if ((_best select 0) <= 0) exitWith {""};
_best select 1
