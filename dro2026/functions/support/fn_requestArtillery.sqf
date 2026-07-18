params ["_position", "_class", ["_rounds", 3]];
[] call DRO2026_fnc_initState;
if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {systemChat format ["Штаб: артсистема %1 недоступна.", _class]};
_rounds = ((round _rounds) max 1) min 10;
private _stock = DRO2026_resources getOrDefault ["friendlyArtilleryStock", 0];
if (_stock < _rounds) exitWith {systemChat format ["Штаб: доступно только %1 артиллерийских выстрелов.", _stock]};

private _key = format ["ARTY_%1", _class];
private _arty = DRO2026_supportAssets getOrDefault [_key, objNull];
if (isNull _arty || {!alive _arty}) then {
    private _cfgName = toLowerANSI _class;
    private _node = if ((_cfgName find "mortar") >= 0) then {"FRIENDLY_FORWARD"} else {"FRIENDLY_REAR"};
    private _anchor = [_node] call DRO2026_fnc_getTheaterNode;
    private _bearing = _position getDir _anchor;
    private _distance = if ((_cfgName find "mortar") >= 0) then {2300} else {if ((_cfgName find "mlrs") >= 0 || {(_cfgName find "mrl") >= 0}) then {7000} else {4800}};
    private _candidate = _position getPos [_distance, _bearing];
    private _safe = [_candidate, 0, 450, 8, 0, 0.25, 0, [], [_candidate, _candidate]] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
    _arty = createVehicle [_class, _candidate, [], 0, "NONE"];
    if (isNull _arty) exitWith {systemChat "Штаб: не удалось развернуть артиллерийскую систему."};
    private _grp = playersSide createVehicleCrew _arty;
    if (!isNull _grp) then {
        _grp setBehaviourStrong "COMBAT";
        _grp setCombatMode "RED";
        _grp setVariable ["DRO2026_supportGroup", true];
    };
    _arty enableDynamicSimulation false;
    DRO2026_supportAssets set [_key, _arty];
    DRO2026_managedVehicles pushBackUnique _arty;
};

private _ammoPool = getArtilleryAmmo [_arty];
private _solutions = _ammoPool select {_position inRangeOfArtillery [[_arty], _x]};
if (count _solutions == 0) exitWith {
    systemChat format ["Штаб: %1 не имеет огневого решения по указанной точке.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")];
};
private _ammo = selectRandom _solutions;
DRO2026_resources set ["friendlyArtilleryStock", (_stock - _rounds) max 0];
_arty doArtilleryFire [_position, _ammo, _rounds];
["ACK", format ["Штаб: огневая задача принята. %1, %2 выстрелов.", getText (configFile >> "CfgVehicles" >> _class >> "displayName"), _rounds]] call DRO2026_fnc_hqVoice;
[_arty] spawn {
    params ["_arty"];
    sleep 90;
    if (!isNull _arty && {alive _arty}) then {_arty enableDynamicSimulation true};
};
