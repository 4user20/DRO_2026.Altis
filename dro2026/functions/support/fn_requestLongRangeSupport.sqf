params ["_position", ["_requestedType", "AUTO"], ["_decoy", false], ["_quantity", 1], ["_requester", objNull]];

if (!isServer) exitWith {
    [player, "LONG_RANGE", [_position, _requestedType, _decoy, _quantity]] remoteExecCall ["DRO2026_fnc_serverRequestSupport", 2, false];
};

[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {
    ["Штаб: дальняя поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage;
};
private _requestSide = if (!isNull _requester) then {side (group _requester)} else {playersSide};
private _requestUpper = toUpperANSI _requestedType;
private _exactClass = if ((_requestUpper find "CLASS:") == 0) then {_requestedType select [6]} else {""};
_quantity = ((round _quantity) max 1) min DRO2026_MAX_DRONES_PER_SALVO;
if (_requestUpper == "FP5") then {_quantity = 1};

private _sideSuffix = switch (_requestSide) do {
    case west: {"WEST"};
    case resistance: {"GUER"};
    default {"EAST"};
};
private _longRole = format ["LONG_RANGE_%1", _sideSuffix];
private _launcherRole = {
    params ["_system"];
    format ["LAUNCHER_%1_%2", _system, _sideSuffix]
};
private _roleHasToken = {
    params ["_role", "_tokens"];
    ((DRO2026_assetRegistry getOrDefault [_role, []]) findIf {
        private _name = toLowerANSI _x;
        (_tokens findIf {(_name find _x) >= 0}) >= 0
    }) >= 0
};
private _launcherHasAmmo = {
    params ["_role", ["_fallbackAmmoRole", ""]];
    private _launchers = DRO2026_assetRegistry getOrDefault [_role, []];
    private _ok = (_launchers findIf {([_x] call DRO2026_fnc_resolveLauncherAmmo) != ""}) >= 0;
    if (!_ok && {_fallbackAmmoRole != ""}) then {
        _ok = count (DRO2026_ammoRegistry getOrDefault [_fallbackAmmoRole, []]) > 0;
    };
    _ok
};
private _fp1LauncherRole = ["FP1"] call _launcherRole;
private _fp2LauncherRole = ["FP2"] call _launcherRole;
private _bm35LauncherRole = ["BM35"] call _launcherRole;
private _bulavaLauncherRole = ["BULAVA"] call _launcherRole;

private _available = if (_exactClass != "") then {
    private _mode = format ["STRIKE_CLASS:%1", _exactClass];
    (_exactClass in (DRO2026_assetRegistry getOrDefault [_longRole, []])) &&
    {isClass (configFile >> "CfgVehicles" >> _exactClass)} &&
    {_exactClass isKindOf "Air"} &&
    {((missionNamespace getVariable ["DRO2026_supportCatalog", []]) findIf {(_x param [1, ""]) == _mode}) >= 0}
} else {
    switch _requestUpper do {
        case "FP1": {[_fp1LauncherRole, "STRIKE_AMMO_FP1"] call _launcherHasAmmo};
        case "FP2": {([_longRole, ["fp2"]] call _roleHasToken) || {[_fp2LauncherRole, "STRIKE_AMMO_FP2"] call _launcherHasAmmo}};
        case "BM35": {([_longRole, ["bm35"]] call _roleHasToken) || {[_bm35LauncherRole, "STRIKE_AMMO_BM35"] call _launcherHasAmmo}};
        case "BULAVA": {[_bulavaLauncherRole, ""] call _launcherHasAmmo};
        case "FP5": {_requestSide == west && {["LAUNCHER_FP5_WEST", "STRIKE_AMMO_FP5"] call _launcherHasAmmo}};
        case "SHAHED": {([_longRole, ["shahed", "geran"]] call _roleHasToken) || {count (DRO2026_ammoRegistry getOrDefault ["STRIKE_AMMO_SHAHED", []]) > 0}};
        default {count (DRO2026_assetRegistry getOrDefault [_longRole, []]) > 0};
    }
};
if (!_available) exitWith {
    [format ["Штаб: профиль %1 недоступен выбранной стороне или отсутствует в опубликованном каталоге. Ресурс не списан.", _requestedType], _requester] call DRO2026_fnc_supportMessage;
};

if ((time - DRO2026_lastLongSupportRequest) < DRO2026_LONG_SUPPORT_COOLDOWN) exitWith {
    [format ["Штаб: Канал дальнего удара занят. Ожидайте %1 сек.", ceil (DRO2026_LONG_SUPPORT_COOLDOWN - (time - DRO2026_lastLongSupportRequest))], _requester] call DRO2026_fnc_supportMessage;
};
private _costPool = if (_decoy) then {"friendlyDecoyStock"} else {"friendlyLongRangeStock"};
if (_requestUpper == "FP5" && {(DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) <= 0}) exitWith {
    ["Штаб: FP-5 для этой миссии больше недоступен.", _requester] call DRO2026_fnc_supportMessage;
};
private _stock = DRO2026_resources getOrDefault [_costPool, 0];
private _physicalSlots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
private _launchCount = (_quantity min _stock) min _physicalSlots;
if (_launchCount <= 0) exitWith {
    ["Штаб: Нет свободных аппаратов или достигнут лимит активных БПЛА.", _requester] call DRO2026_fnc_supportMessage;
};

private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
if (count _sites == 0) exitWith {
    ["Штаб: Дальний расчёт БПЛА не отвечает.", _requester] call DRO2026_fnc_supportMessage;
};
private _site = _sites select 0;
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];

private _baseContact = ["PLAYER", objNull, _position, 0.76, "НАЗНАЧЕННАЯ_ТОЧКА"] call DRO2026_fnc_createContactRecord;
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.45} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 360} &&
    {((_x getOrDefault ["positionMean", _x getOrDefault ["position", [0,0,0]]]) distance2D _position) < 550}
};
if (count _contacts > 0) then {_baseContact = _contacts select 0};
private _siteContacts = DRO2026_sites select {
    private _sitePosition = _x getOrDefault ["position", []];
    count _sitePosition > 1 &&
    {_sitePosition distance2D _position < 650} &&
    {(_x getOrDefault ["type", ""]) in [
        "ENEMY_HQ", "STRATEGIC_DRONE_SITE", "FPV_TEAM", "ARTILLERY_SITE", "EW_SITE",
        "AIR_DEFENCE_SITE", "ENEMY_LAYERED_AA", "CONVOY", "LOGISTICS_RUN", "LOGISTICS_HUB"
    ]}
};
if (count _siteContacts > 0) then {
    private _record = _siteContacts select 0;
    _baseContact = [
        "PLAYER", _record getOrDefault ["object", objNull], _record getOrDefault ["position", _position],
        0.92, _record getOrDefault ["type", "ЦЕЛЬ"], "PLAYER_DESIGNATION", 90,
        _record getOrDefault ["networkNodeId", ""]
    ] call DRO2026_fnc_createContactRecord;
};

DRO2026_lastLongSupportRequest = time;
DRO2026_resources set [_costPool, (_stock - _launchCount) max 0];
if (_requestUpper == "FP5") then {
    DRO2026_resources set ["friendlyFP5Stock", ((DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) - 1) max 0];
    DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
};

[_origin, _baseContact, _operator, _requestedType, _decoy, _launchCount, _requestSide] spawn {
    params ["_origin", "_baseContact", "_operator", "_type", "_decoy", "_count", "_requestSide"];
    for "_index" from 0 to (_count - 1) do {
        private _contact = createHashMap;
        {_contact set [_x, _baseContact get _x]} forEach keys _baseContact;
        private _basePosition = _baseContact getOrDefault ["positionMean", _baseContact getOrDefault ["position", [0,0,0]]];
        if (_count > 1 && {isNull (_baseContact getOrDefault ["target", objNull])}) then {
            _contact set ["position", _basePosition getPos [40 + random 260, random 360]];
            _contact set ["positionMean", _contact get "position"];
        };
        [_origin, _contact, _requestSide, _type == "FP5", _operator, _type, _decoy, _index, _count, true] spawn DRO2026_fnc_launchLongRangeStrike;
        sleep (2.5 + random 3.5);
    };
};
[
    "ACK",
    format ["Штаб: Подтверждаю запуск: %1, количество %2.", if (_decoy) then {"БПЛА-обманка"} else {if (_exactClass != "") then {_exactClass} else {_requestedType}}, _launchCount],
    if (!isNull _requester) then {_requester} else {-2}
] call DRO2026_fnc_hqVoice;
