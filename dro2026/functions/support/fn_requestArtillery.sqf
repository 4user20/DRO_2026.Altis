params ["_position", "_class", ["_rounds", 3], ["_requester", objNull]];

if (!isServer) exitWith {
    [createHashMapFromArray [["channel","ARTILLERY"],["assetClass",_class],["count",_rounds],["targetMode","MAP_POINT"],["targetPositionASL",AGLToASL _position],["sourceMode","AUTO"],["controlMode","AUTO"]]] call DRO2026_fnc_submitSupportRequest
};
[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: артиллерийская поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};

private _lowerClass = toLowerANSI _class;
if ((_lowerClass find "pook_tos1a") >= 0) exitWith {
    ["Штаб: TOS-1A скрыт из поддержки: текущая версия аддона вызвала продолжительный Fired-handler spam в RPT.", _requester] call DRO2026_fnc_supportMessage;
};
if !([format ["ARTY:%1", _class], _class] call DRO2026_fnc_supportCatalogContains) exitWith {
    [format ["Штаб: артсистема %1 отсутствует в опубликованном installed-assets catalog.", _class], _requester] call DRO2026_fnc_supportMessage;
};
if (!isClass (configFile >> "CfgVehicles" >> _class)) exitWith {
    [format ["Штаб: артсистема %1 недоступна.", _class], _requester] call DRO2026_fnc_supportMessage;
};
if (time < DRO2026_supportFireLockUntil || {DRO2026_activeHeavySupport >= DRO2026_MAX_CONCURRENT_HEAVY_SUPPORT}) exitWith {
    [format ["Штаб: тяжёлый огневой канал занят. Ожидайте %1 сек.", ceil ((DRO2026_supportFireLockUntil - time) max 1)], _requester] call DRO2026_fnc_supportMessage;
};

private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.62} &&
    {(_x getOrDefault ["uncertaintyRadius", 9999]) <= DRO2026_MAX_CONTACT_UNCERTAINTY_FOR_ARTY} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 240} &&
    {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])} &&
    {(_x getOrDefault ["positionMean", _x getOrDefault ["position", [0,0,0]]]) distance2D _position < 550}
};
if (count _contacts == 0) exitWith {
    ["Штаб: для огневой задачи нужен свежий подтверждённый контакт в выбранном районе.", _requester] call DRO2026_fnc_supportMessage;
};
_contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 2000))}, "ASCEND"] call BIS_fnc_sortBy;
private _contact = _contacts select 0;
private _targetPosition = +(_contact getOrDefault ["positionMean", _position]);
private _uncertainty = _contact getOrDefault ["uncertaintyRadius", 80];
_targetPosition = _targetPosition getPos [random (_uncertainty min 220), random 360];

private _friendlyRisk = allUnits findIf {
    alive _x && {!(_x isKindOf "VirtualMan_F")} && {side (group _x) == playersSide} && {_x distance2D _targetPosition < 220}
};
private _civilianRisk = allUnits findIf {
    alive _x && {!(_x isKindOf "VirtualMan_F")} && {side (group _x) == civilian} && {_x distance2D _targetPosition < 320}
};
if (_friendlyRisk >= 0) exitWith {["Штаб: огонь запрещён — свои силы слишком близко к зоне поражения.", _requester] call DRO2026_fnc_supportMessage};
if (_civilianRisk >= 0) exitWith {["Штаб: огонь запрещён — подтверждено присутствие гражданских.", _requester] call DRO2026_fnc_supportMessage};

_rounds = ((round _rounds) max 1) min 10;
private _stock = DRO2026_resources getOrDefault ["friendlyArtilleryStock", 0];
if (_stock < _rounds) exitWith {
    [format ["Штаб: доступно только %1 артиллерийских выстрелов.", _stock], _requester] call DRO2026_fnc_supportMessage;
};

private _key = format ["ARTY_%1", _class];
private _arty = DRO2026_supportAssets getOrDefault [_key, objNull];
private _createdNow = false;
if (isNull _arty || {!alive _arty}) then {
    private _node = if ((_lowerClass find "mortar") >= 0) then {"FRIENDLY_FORWARD"} else {"FRIENDLY_REAR"};
    private _anchor = [_node] call DRO2026_fnc_getTheaterNode;
    private _bearing = _targetPosition getDir _anchor;
    private _distance = if ((_lowerClass find "mortar") >= 0) then {2300} else {if ((_lowerClass find "mlrs") >= 0 || {(_lowerClass find "mrl") >= 0}) then {7000} else {4800}};
    private _candidate = _targetPosition getPos [_distance, _bearing];
    private _safe = [_candidate, 0, 450, 8, 0, 0.25, 0, [], [_candidate, _candidate]] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) then {_candidate = _safe};
    _arty = createVehicle [_class, _candidate, [], 0, "NONE"];
    if (isNull _arty) exitWith {["Штаб: не удалось развернуть артиллерийскую систему.", _requester] call DRO2026_fnc_supportMessage};
    _createdNow = true;
    private _group = playersSide createVehicleCrew _arty;
    if (isNull _group || {isNull (gunner _arty)}) exitWith {
        deleteVehicleCrew _arty;
        deleteVehicle _arty;
        if (!isNull _group) then {deleteGroup _group};
        _arty = objNull;
        ["Штаб: артсистема не получила совместимый экипаж.", _requester] call DRO2026_fnc_supportMessage;
    };
    _group setBehaviourStrong "COMBAT";
    _group setCombatMode "RED";
    _group setVariable ["DRO2026_supportGroup", true];
    _arty setVariable ["DRO2026_supportGroup", _group];
    _arty addEventHandler ["Killed", {
        params ["_vehicle"];
        private _group = _vehicle getVariable ["DRO2026_supportGroup", grpNull];
        [_group] spawn {params ["_group"]; sleep 1; if (!isNull _group) then {deleteGroup _group}};
    }];
    _arty enableDynamicSimulation false;
    DRO2026_supportAssets set [_key, _arty];
    DRO2026_managedVehicles pushBackUnique _arty;
};
if (isNull _arty) exitWith {};

private _ammoPool = getArtilleryAmmo [_arty];
if (count _ammoPool == 0) exitWith {
    if (_createdNow) then {
        DRO2026_supportAssets deleteAt _key;
        private _group = _arty getVariable ["DRO2026_supportGroup", grpNull];
        deleteVehicleCrew _arty;
        deleteVehicle _arty;
        if (!isNull _group) then {deleteGroup _group};
    };
    ["Штаб: выбранная система не предоставляет штатных артиллерийских боеприпасов.", _requester] call DRO2026_fnc_supportMessage;
};
private _solutions = _ammoPool select {_targetPosition inRangeOfArtillery [[_arty], _x]};
if (count _solutions == 0) exitWith {
    [format ["Штаб: %1 не имеет огневого решения по зоне контакта.", getText (configFile >> "CfgVehicles" >> _class >> "displayName")], _requester] call DRO2026_fnc_supportMessage;
};
private _ammo = selectRandom _solutions;
private _missionId = format ["FRIENDLY_FIRE_%1_%2", floor diag_tickTime, floor random 1000000];
DRO2026_resources set ["friendlyArtilleryStock", (_stock - _rounds) max 0];
DRO2026_supportFireLockUntil = time + DRO2026_SUPPORT_HEAVY_FIRE_SPACING;
DRO2026_activeHeavySupport = DRO2026_activeHeavySupport + 1;
_arty doArtilleryFire [_targetPosition, _ammo, _rounds];
["FIRE_MISSION_EXECUTED", createHashMapFromArray [
    ["missionId", _missionId], ["side", "PLAYER"], ["observerContact", _contact getOrDefault ["id", ""]],
    ["targetArea", _targetPosition], ["uncertainty", _uncertainty], ["ammoType", _ammo], ["rounds", _rounds]
], _missionId] call DRO2026_fnc_emitEvent;
[
    "ACK",
    format ["Штаб: огневая задача принята по контакту %1. %2 выстрелов.", _contact getOrDefault ["classification", "ЦЕЛЬ"], _rounds],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;
[_arty] spawn {
    params ["_arty"];
    sleep 75;
    DRO2026_activeHeavySupport = (DRO2026_activeHeavySupport - 1) max 0;
    if (!isNull _arty && {alive _arty}) then {_arty enableDynamicSimulation true};
};
