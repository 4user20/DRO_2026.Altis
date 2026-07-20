params [["_group", grpNull]];
if (!isServer || {isNull _group}) exitWith {false};
if !(missionNamespace getVariable ["DRO2026_droneAdapterReady", false]) exitWith {false};
if !(missionNamespace getVariable ["ddtReady", false]) exitWith {false};
if (_group getVariable ["DRO2026_droneLoadoutAssigned", false]) exitWith {false};
if (_group getVariable ["ddtExclude", false]) exitWith {false};
if ((side _group) != enemySide) exitWith {false};
if ((units _group) findIf {isPlayer _x} >= 0) exitWith {false};
if ((units _group) findIf {alive _x} < 0) exitWith {false};

private _assignedGroups = {
    !isNull _x && {_x getVariable ["DRO2026_droneLoadoutAssigned", false]}
} count DRO2026_managedGroups;
if (_assignedGroups >= (missionNamespace getVariable ["DRO2026_MAX_DDT_EQUIPPED_GROUPS", 6])) exitWith {false};

private _players = allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}};
private _nearestPlayer = 1e10;
{
    _nearestPlayer = _nearestPlayer min ((leader _group) distance2D _x);
} forEach _players;
if (_nearestPlayer > (missionNamespace getVariable ["DRO2026_DRONE_ASSIGNMENT_DISTANCE", 3200]) && {DRO2026_alertLevel < 0.70}) exitWith {false};

private _classNames = (units _group) apply {toLowerANSI typeOf _x};
private _advanced = (_classNames findIf {
    (_x find "recon") >= 0 || {(_x find "spotter") >= 0} || {(_x find "operator") >= 0} ||
    {(_x find "special") >= 0} || {(_x find "officer") >= 0} || {(_x find "commander") >= 0}
}) >= 0;
private _militia = (_classNames findIf {(_x find "militia") >= 0 || {(_x find "insurgent") >= 0}}) >= 0;
if (_militia && {!(missionNamespace getVariable ["DRO2026_ALLOW_MILITIA_DRONES", false])}) exitWith {false};

private _sideKey = switch (side _group) do {case west: {"WEST"}; case resistance: {"GUER"}; default {"EAST"}};
private _units = (units _group) select {alive _x && {!isPlayer _x} && {vehicle _x == _x}};
if (count _units == 0) exitWith {false};
private _ordered = [];
private _leader = leader _group;
if (_leader in _units) then {_ordered pushBack _leader};
{
    private _name = toLowerANSI typeOf _x;
    if ((_name find "uav") >= 0 || {(_name find "operator") >= 0} || {(_name find "spotter") >= 0} || {(_name find "recon") >= 0}) then {
        _ordered pushBackUnique _x;
    };
} forEach _units;
{_ordered pushBackUnique _x} forEach _units;

private _known = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "ENEMY" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.58} &&
    {(time - (_x getOrDefault ["lastSeen", -999])) < 240}
};
private _knownArmor = (_known findIf {
    private _target = _x getOrDefault ["target", objNull];
    !isNull _target && {alive _target} && {
        _target isKindOf "Tank" || {_target isKindOf "Wheeled_APC_F"} || {_target isKindOf "Tracked_APC_F"} || {_target isKindOf "StaticWeapon"}
    }
}) >= 0;

private _used = [];
private _assigned = [];
private _giveCategory = {
    params ["_categories"];
    private _descriptors = [];
    {
        _descriptors append (DRO2026_droneRegistry getOrDefault [format ["%1_%2", _x, _sideKey], []]);
        _descriptors append (DRO2026_droneRegistry getOrDefault [format ["%1_ANY", _x], []]);
    } forEach _categories;
    private _done = false;
    {
        private _unit = _x;
        if (!(_unit in _used) && {!_done}) then {
            {
                private _descriptor = _x;
                private _class = _descriptor getOrDefault ["class", ""];
                private _carrier = _descriptor getOrDefault ["carrier", ""];
                private _assembled = _descriptor getOrDefault ["assembleTo", ""];
                private _knownMappedItem = _class in [
                    "ItemMavic3T", "Item_Mavic3T", "ItemMavic3", "Item_Mavic",
                    "Item_KVN_AP", "Item_KVN_AP_TI", "Item_KVN_AT", "Item_KVN_AT_TI",
                    "Item_Crocus_AP", "Item_Crocus_AP_TI", "Item_Crocus_AT", "Item_Crocus_AT_TI",
                    "sps_black_hornet_01_Static_F", "1Rnd_RC40_shell_RF", "1Rnd_RC40_HE_shell_RF"
                ];
                private _canUse = _class != "" && {
                    (_carrier == "BACKPACK" && {_assembled != ""}) ||
                    {_carrier in ["ITEM", "MAGAZINE"] && {_knownMappedItem}}
                };
                if (_carrier == "BACKPACK") then {_canUse = _canUse && {backpack _unit == ""}};
                if (_carrier in ["ITEM", "MAGAZINE"]) then {_canUse = _canUse && {_unit canAdd _class}};
                if (_canUse && {!_done}) then {
                    switch (_carrier) do {
                        case "BACKPACK": {_unit addBackpackGlobal _class};
                        case "ITEM": {_unit addItem _class};
                        case "MAGAZINE": {_unit addMagazine _class};
                    };
                    _used pushBack _unit;
                    _assigned pushBack _class;
                    _done = true;
                };
            } forEach _descriptors;
        };
    } forEach _ordered;
    _done
};

private _reconChance = missionNamespace getVariable ["DRO2026_RECON_DRONE_CHANCE", 0.58];
if (_advanced) then {_reconChance = (_reconChance + 0.25) min 0.95};
if (random 1 < _reconChance) then {[ ["RECON"] ] call _giveCategory};

if (DRO2026_alertLevel >= 0.35 && {count _known > 0}) then {
    private _apChance = missionNamespace getVariable ["DRO2026_FPV_AP_CHANCE", 0.34];
    if (_advanced) then {_apChance = (_apChance + 0.20) min 0.85};
    if (random 1 < _apChance) then {[ ["FPV_AP_TI", "FPV_AP"] ] call _giveCategory};
    private _atChance = missionNamespace getVariable ["DRO2026_FPV_AT_CHANCE", 0.20];
    if (_knownArmor) then {_atChance = (_atChance + 0.30) min 0.80};
    if (random 1 < _atChance) then {[ ["FPV_AT_TI", "FPV_AT"] ] call _giveCategory};
    if (_advanced && {random 1 < (missionNamespace getVariable ["DRO2026_BOMBER_DRONE_CHANCE", 0.10])}) then {
        [["BOMBER"]] call _giveCategory;
    };
};

if (count _assigned == 0) exitWith {false};
_group setVariable ["DRO2026_droneLoadoutAssigned", true];
_group setVariable ["DRO2026_assignedDroneClasses", _assigned];
[format ["DDT loadout assigned to %1: %2", _group, _assigned]] call DRO2026_fnc_log;
true
