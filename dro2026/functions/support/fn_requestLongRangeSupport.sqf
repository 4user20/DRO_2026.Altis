params ["_position", ["_requestedType", "AUTO"], ["_decoy", false], ["_quantity", 1]];
[] call DRO2026_fnc_initState;
_requestedType = toUpperANSI _requestedType;
_quantity = ((round _quantity) max 1) min DRO2026_MAX_DRONES_PER_SALVO;
if (_requestedType == "FP5") then {_quantity = 1};

private _roleHasToken = {
    params ["_role", "_tokens"];
    ((DRO2026_assetRegistry getOrDefault [_role, []]) findIf {
        private _n = toLowerANSI _x;
        (_tokens findIf {(_n find _x) >= 0}) >= 0
    }) >= 0
};
private _launcherHasAmmo = {
    params ["_role", ["_fallbackAmmoRole", ""]];
    private _launchers = DRO2026_assetRegistry getOrDefault [_role, []];
    private _ok = (_launchers findIf {([_x] call DRO2026_fnc_resolveLauncherAmmo) != ""}) >= 0;
    if (!_ok && {_fallbackAmmoRole != ""}) then {_ok = count (DRO2026_ammoRegistry getOrDefault [_fallbackAmmoRole, []]) > 0};
    _ok
};
private _available = switch _requestedType do {
    case "FP1": {["LAUNCHER_FP1_WEST", "STRIKE_AMMO_FP1"] call _launcherHasAmmo};
    case "FP2": {["LONG_RANGE_WEST", ["fp2"]] call _roleHasToken || {["LAUNCHER_FP2_WEST", "STRIKE_AMMO_FP2"] call _launcherHasAmmo}};
    case "BM35": {["LONG_RANGE_WEST", ["bm35"]] call _roleHasToken || {["LAUNCHER_BM35_WEST", "STRIKE_AMMO_BM35"] call _launcherHasAmmo}};
    case "BULAVA": {["LAUNCHER_BULAVA_WEST", ""] call _launcherHasAmmo};
    case "FP5": {["LAUNCHER_FP5_WEST", "STRIKE_AMMO_FP5"] call _launcherHasAmmo};
    case "SHAHED": {["LONG_RANGE_WEST", ["shahed", "geran"]] call _roleHasToken || {count (DRO2026_ammoRegistry getOrDefault ["STRIKE_AMMO_SHAHED", []]) > 0}};
    default {count (DRO2026_assetRegistry getOrDefault ["LONG_RANGE_WEST", []]) > 0};
};
if (!_available) exitWith {systemChat format ["Штаб: профиль %1 присутствует в интерфейсе, но его летающий класс/боеприпас не найден. Ресурс не списан.", _requestedType]};

if ((time - DRO2026_lastLongSupportRequest) < DRO2026_LONG_SUPPORT_COOLDOWN) exitWith {
    systemChat format ["Штаб: Канал дальнего удара занят. Ожидайте %1 сек.", ceil (DRO2026_LONG_SUPPORT_COOLDOWN - (time - DRO2026_lastLongSupportRequest))];
};
private _costPool = if (_decoy) then {"friendlyDecoyStock"} else {"friendlyLongRangeStock"};
if (_requestedType == "FP5" && {(DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) <= 0}) exitWith {systemChat "Штаб: FP-5 для этой миссии больше недоступен."};
private _stock = DRO2026_resources getOrDefault [_costPool, 0];
private _physicalSlots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
private _launchCount = (_quantity min _stock) min _physicalSlots;
if (_launchCount <= 0) exitWith {systemChat "Штаб: Нет свободных аппаратов или достигнут лимит активных БПЛА."};

private _sites = DRO2026_sites select {
    (_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {
        private _operator = _x getOrDefault ["operator", objNull];
        !isNull _operator && {alive _operator}
    }
};
if (count _sites == 0) exitWith {systemChat "Штаб: Дальний расчёт БПЛА не отвечает."};
private _site = _sites select 0;
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];

private _baseContact = createHashMapFromArray [["owner", "PLAYER"], ["target", objNull], ["position", _position], ["confidence", 0.76], ["kind", "НАЗНАЧЕННАЯ_ТОЧКА"], ["lastSeen", time]];
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.45} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 360} &&
    {((_x getOrDefault ["position", [0,0,0]]) distance2D _position) < 550}
};
if (count _contacts > 0) then {_baseContact = _contacts select 0};
private _siteContacts = DRO2026_sites select {
    private _p = _x getOrDefault ["position", []];
    count _p > 1 && {_p distance2D _position < 650} && {(_x getOrDefault ["type", ""]) in ["ENEMY_HQ", "STRATEGIC_DRONE_SITE", "FPV_TEAM", "ARTILLERY_SITE", "AIR_DEFENCE_SITE", "ENEMY_LAYERED_AA", "CONVOY", "LOGISTICS_RUN"]}
};
if (count _siteContacts > 0) then {
    private _rec = _siteContacts select 0;
    _baseContact = createHashMapFromArray [["owner", "PLAYER"], ["target", _rec getOrDefault ["object", objNull]], ["position", _rec getOrDefault ["position", _position]], ["confidence", 0.92], ["kind", _rec getOrDefault ["type", "ЦЕЛЬ"]], ["lastSeen", time]];
};

DRO2026_lastLongSupportRequest = time;
DRO2026_resources set [_costPool, (_stock - _launchCount) max 0];
if (_requestedType == "FP5") then {
    DRO2026_resources set ["friendlyFP5Stock", ((DRO2026_resources getOrDefault ["friendlyFP5Stock", 0]) - 1) max 0];
    DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
};

[_origin, _baseContact, _operator, _requestedType, _decoy, _launchCount] spawn {
    params ["_origin", "_baseContact", "_operator", "_type", "_decoy", "_count"];
    for "_i" from 0 to (_count - 1) do {
        private _contact = +_baseContact;
        private _basePos = _baseContact getOrDefault ["position", [0,0,0]];
        if (_count > 1 && {isNull (_baseContact getOrDefault ["target", objNull])}) then {
            _contact set ["position", _basePos getPos [40 + random 260, random 360]];
        };
        [_origin, _contact, playersSide, _type == "FP5", _operator, _type, _decoy, _i, _count, true] spawn DRO2026_fnc_launchLongRangeStrike;
        sleep (2.5 + random 3.5);
    };
};
["ACK", format ["Штаб: Подтверждаю запуск: %1, количество %2.", if (_decoy) then {"БПЛА-обманка"} else {_requestedType}, _launchCount]] call DRO2026_fnc_hqVoice;
