private _launcherOrClass = _this param [0, ""];
private _launcher = objNull;
private _launcherClass = "";
if (_launcherOrClass isEqualType objNull) then {
    _launcher = _launcherOrClass;
    if (!isNull _launcher) then {_launcherClass = typeOf _launcher};
} else {
    if (_launcherOrClass isEqualType "") then {_launcherClass = _launcherOrClass};
};
private _cfgVehicle = configFile >> "CfgVehicles" >> _launcherClass;
if (_launcherClass == "" || {!isClass _cfgVehicle}) exitWith {""};

private _weapons = [];
{
    _weapons append (getArray _x);
} forEach (configProperties [_cfgVehicle, "isArray _x && {configName _x == 'weapons'}", true]);

private _runtimeMagazines = [];
if (!isNull _launcher) then {
    private _turretPaths = [[-1]] + (allTurrets [_launcher,true]);
    {
        _weapons append (_launcher weaponsTurret _x);
    } forEach _turretPaths;
    {
        private _magazine = _x param [0,"",[""]];
        private _turretPath = _x param [1,[],[[]]];
        private _ammoCount = _x param [2,0,[0]];
        if (_magazine != "" && {_ammoCount > 0}) then {
            _runtimeMagazines pushBackUnique [_magazine,_turretPath,_ammoCount];
        };
    } forEach (magazinesAllTurrets _launcher);
};
_weapons = _weapons arrayIntersect _weapons;

private _blockedTokens = [
    "smoke", "flare", "chaff", "countermeasure", "cmflare",
    "fake", "dummy", "horn", "safeweapon", "laserdesignator"
];
private _preferredTokens = ["missile", "rocket", "ballistic", "iskander", "scud", "cruise", "warhead", "fp1", "fp2", "fp5", "bm35", "bulava", "shahed", "geran", "9k720", "9k52", "ss21"];
private _candidates = [];
private _scoreMagazine = {
    params ["_magazine","_weapon",["_runtimeAmmoCount",0]];
    private _magazineCfg = configFile >> "CfgMagazines" >> _magazine;
    if (!isClass _magazineCfg) exitWith {};
    private _ammo = getText (_magazineCfg >> "ammo");
    private _ammoCfg = configFile >> "CfgAmmo" >> _ammo;
    if (_ammo == "" || {!isClass _ammoCfg}) exitWith {};
    private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;
    private _simulation = toLowerANSI getText (_ammoCfg >> "simulation");
    private _haystack = toLowerANSI format [
        "%1 %2 %3 %4 %5 %6",
        _launcherClass,
        _weapon,
        _magazine,
        _ammo,
        if (isClass _weaponCfg) then {getText (_weaponCfg >> "displayName")} else {""},
        _simulation
    ];
    private _blocked = (_blockedTokens findIf {(_haystack find _x) >= 0}) >= 0;
    private _preferredCount = {(_haystack find _x) >= 0} count _preferredTokens;
    private _strategicSimulation =
        (_simulation find "shotmissile") >= 0 ||
        {(_simulation find "shotrocket") >= 0} ||
        {(_simulation find "shotbomb") >= 0};
    private _strategicCandidate = _strategicSimulation || {_preferredCount > 0};
    if (_blocked || {!_strategicCandidate}) exitWith {};
    private _score = if (_runtimeAmmoCount > 0) then {1500 + ((_runtimeAmmoCount min 20) * 10)} else {0};
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
    _candidates pushBack [_score,_ammo,_magazine,_weapon,_runtimeAmmoCount];
};

// Runtime magazines are the strongest evidence: they prove that this concrete
// launcher instance currently carries the magazine and a positive ammo count.
{
    _x params ["_magazine","_turretPath","_ammoCount"];
    private _turretWeapons = if (isNull _launcher) then {[]} else {_launcher weaponsTurret _turretPath};
    private _weapon = if (count _turretWeapons > 0) then {_turretWeapons select 0} else {"RUNTIME_TURRET"};
    [_magazine,_weapon,_ammoCount] call _scoreMagazine;
} forEach _runtimeMagazines;

// Config traversal remains the fallback for catalog discovery before a physical
// launcher exists. compatibleMagazines is supplemental only; some missile and
// submunition launchers do not expose a complete answer through it.
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
        {[_x,_weapon,0] call _scoreMagazine} forEach _magazines;
    };
} forEach _weapons;

if (count _candidates == 0) exitWith {""};
_candidates = [_candidates, [], {-(_x select 0)}, "ASCEND"] call BIS_fnc_sortBy;
private _best = _candidates select 0;
if ((_best select 0) <= 0) exitWith {""};
_best select 1
