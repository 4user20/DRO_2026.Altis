params ["_position", ["_requestedType", "AUTO"], ["_decoy", false], ["_quantity", 1], ["_requester", objNull], ["_requestId", ""]];

if (!isServer) exitWith {
    private _assetClass = if ((toUpperANSI _requestedType find "CLASS:") == 0) then {_requestedType select [6]} else {""};
    [createHashMapFromArray [["channel","LONG_RANGE_STRIKE"],["assetId",if (_decoy) then {"DECOY"} else {if (_assetClass == "") then {_requestedType} else {""}}],["assetClass",_assetClass],["count",_quantity],["targetMode","MAP_POINT"],["targetPositionASL",AGLToASL _position],["sourceMode","AUTO"],["controlMode","AUTO"]]] call DRO2026_fnc_submitSupportRequest
};

[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (_requestId == "") then {_requestId = format ["LR_%1_%2",floor (diag_tickTime * 1000),floor random 100000]};
private _fail = {
    params ["_code","_message"];
    if (!isNull _requester) then {[_message,_requester] call DRO2026_fnc_supportMessage};
    ["LONG_RANGE_REQUEST_REJECTED",createHashMapFromArray [["requestId",_requestId],["code",_code],["message",_message],["type",_requestedType]],_requestId] call DRO2026_fnc_emitEvent;
    [false,_code,_message,_requestId,createHashMap] call DRO2026_fnc_makeResult
};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {["REQUESTER_SIDE_DENIED","Штаб: дальняя поддержка недоступна для этой стороны."] call _fail};
if !(_requestedType isEqualType "" && {_decoy isEqualType true} && {_quantity isEqualType 0}) exitWith {["REQUEST_INVALID","Штаб: некорректный профиль дальнего удара."] call _fail};

private _requestSide = if (!isNull _requester) then {side (group _requester)} else {playersSide};
private _requestUpper = toUpperANSI _requestedType;
private _exactClass = if ((_requestUpper find "CLASS:") == 0) then {_requestedType select [6]} else {""};
private _knownTypes = ["AUTO", "FP1", "FP2", "BM35", "BULAVA", "FP5", "SHAHED"];
if (_exactClass == "" && {!(_requestUpper in _knownTypes)}) exitWith {["PROFILE_UNKNOWN",format ["Штаб: неизвестный профиль дальнего удара %1.",_requestedType]] call _fail};
if (_decoy && {_requestUpper != "AUTO"}) exitWith {["DECOY_PROFILE_INVALID","Штаб: режим обманки разрешён только для автоматического профиля."] call _fail};

_quantity = ((round _quantity) max 1) min DRO2026_MAX_DRONES_PER_SALVO;
if (_requestUpper == "FP5") then {_quantity = 1};
private _sideSuffix = [_requestSide] call DRO2026_fnc_getSideSuffix;
private _sideNumber = [_requestSide] call DRO2026_fnc_getSideNumber;
private _longRole = format ["LONG_RANGE_%1", _sideSuffix];
private _launcherRole = {params ["_system"]; format ["LAUNCHER_%1_%2", _system, _sideSuffix]};
private _roleHasToken = {
    params ["_role", "_tokens"];
    ((DRO2026_assetRegistry getOrDefault [_role, []]) findIf {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        private _name = toLowerANSI _x;
        isClass _cfg && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}} && {(_tokens findIf {(_name find _x) >= 0}) >= 0}
    }) >= 0
};
private _launcherHasAmmo = {
    params ["_role", ["_fallbackAmmoRole", ""]];
    private _launchers = DRO2026_assetRegistry getOrDefault [_role, []];
    private _ok = (_launchers findIf {([_x] call DRO2026_fnc_resolveLauncherAmmo) != ""}) >= 0;
    if (!_ok && {_fallbackAmmoRole != ""}) then {_ok = count (DRO2026_ammoRegistry getOrDefault [_fallbackAmmoRole, []]) > 0};
    _ok
};
private _fp1LauncherRole = ["FP1"] call _launcherRole;
private _fp2LauncherRole = ["FP2"] call _launcherRole;
private _bm35LauncherRole = ["BM35"] call _launcherRole;
private _bulavaLauncherRole = ["BULAVA"] call _launcherRole;

private _available = if (_exactClass != "") then {
    private _cfg = configFile >> "CfgVehicles" >> _exactClass;
    private _mode = format ["STRIKE_CLASS:%1", _exactClass];
    (_exactClass in (DRO2026_assetRegistry getOrDefault [_longRole, []])) && {isClass _cfg} && {_exactClass isKindOf "Air"} && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}} && {[_mode,_exactClass] call DRO2026_fnc_supportCatalogContains}
} else {
    switch _requestUpper do {
        case "FP1": {[_fp1LauncherRole, "STRIKE_AMMO_FP1"] call _launcherHasAmmo};
        case "FP2": {([_longRole, ["fp2"]] call _roleHasToken) || {[_fp2LauncherRole, "STRIKE_AMMO_FP2"] call _launcherHasAmmo}};
        case "BM35": {([_longRole, ["bm35"]] call _roleHasToken) || {[_bm35LauncherRole, "STRIKE_AMMO_BM35"] call _launcherHasAmmo}};
        case "BULAVA": {[_bulavaLauncherRole, ""] call _launcherHasAmmo};
        case "FP5": {[format ["LAUNCHER_FP5_%1", _sideSuffix], "STRIKE_AMMO_FP5"] call _launcherHasAmmo};
        case "SHAHED": {([_longRole, ["shahed", "geran"]] call _roleHasToken) || {count (DRO2026_ammoRegistry getOrDefault ["STRIKE_AMMO_SHAHED", []]) > 0}};
        case "AUTO": {((DRO2026_assetRegistry getOrDefault [_longRole, []]) findIf {private _cfg = configFile >> "CfgVehicles" >> _x; isClass _cfg && {_x isKindOf "Air"} && {_sideNumber < 0 || {getNumber (_cfg >> "side") == _sideNumber}}}) >= 0};
        default {false};
    }
};
if (!_available) exitWith {["PROFILE_UNAVAILABLE",format ["Штаб: профиль %1 недоступен выбранной стороне или отсутствует в опубликованном каталоге. Ресурс не списан.",_requestedType]] call _fail};
if ((time - DRO2026_lastLongSupportRequest) < DRO2026_LONG_SUPPORT_COOLDOWN) exitWith {["CHANNEL_COOLDOWN",format ["Штаб: канал дальнего удара занят. Ожидайте %1 сек.",ceil (DRO2026_LONG_SUPPORT_COOLDOWN - (time - DRO2026_lastLongSupportRequest))]] call _fail};
if (_requestUpper == "FP5" && {DRO2026_friendlyFP5Used >= 2}) exitWith {["FP5_LIMIT","Штаб: лимит успешных запусков FP-5 для этой миссии исчерпан."] call _fail};

private _costPool = if (_decoy) then {"friendlyDecoyStock"} else {if (_requestUpper == "FP5") then {"friendlyFP5Stock"} else {"friendlyLongRangeStock"}};
private _stock = DRO2026_resources getOrDefault [_costPool, 0];
private _physicalSlots = (DRO2026_PHYSICAL_DRONE_LIMIT - count DRO2026_activeDrones) max 0;
private _launchCount = (_quantity min _stock) min _physicalSlots;
if (_launchCount <= 0) exitWith {["NO_CAPACITY","Штаб: нет свободных аппаратов или достигнут лимит активных БПЛА."] call _fail};

private _sites = DRO2026_sites select {(_x getOrDefault ["type", ""]) == "FRIENDLY_DRONE_SITE" && {private _siteId = _x getOrDefault ["id", ""]; _siteId != "" && {[_siteId] call DRO2026_fnc_isSiteOperational}}};
if (count _sites == 0) exitWith {["NO_LAUNCH_SITE","Штаб: дальний расчёт БПЛА не отвечает или площадка недоступна."] call _fail};
private _site = _sites select 0;
private _siteId = _site getOrDefault ["id", ""];
private _operator = _site getOrDefault ["operator", objNull];
private _origin = _site getOrDefault ["position", ["FRIENDLY_DRONE_REAR"] call DRO2026_fnc_getTheaterNode];

private _baseContact = ["PLAYER",objNull,_position,0.86,"НАЗНАЧЕННАЯ_ТОЧКА","","PLAYER_DESIGNATION",24,"",0,2,createHashMapFromArray [["positionSpace","ASL"],["subjectMode","POSITION_ONLY"],["positionTtl",420],["requestId",_requestId]]] call DRO2026_fnc_createContactRecord;
if (count _baseContact == 0) exitWith {["TARGET_RECORD_FAILED","Штаб: не удалось сформировать запись назначенной цели. Ресурс не списан."] call _fail};
private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" && {(_x getOrDefault ["confidence", 0]) >= 0.45} && {(time - (_x getOrDefault ["lastSeen", 0])) < 360} &&
    {!((toUpperANSI (_x getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"])} &&
    {!((_x getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])} &&
    {((_x getOrDefault ["positionASL",_x getOrDefault ["positionMean", [0,0,0]]]) distance2D _position) < 550} &&
    {[_x] call DRO2026_fnc_isLiveContactSubject}
};
if (count _contacts > 0) then {_contacts = [_contacts, [], {-((_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 3000))}, "ASCEND"] call BIS_fnc_sortBy; _baseContact = _contacts select 0};
private _siteContacts = DRO2026_sites select {
    private _sitePosition = _x getOrDefault ["position", []];
    private _status = toUpperANSI (_x getOrDefault ["status", "ACTIVE"]);
    count _sitePosition > 1 && {_sitePosition distance2D _position < 650} && {!(_status in ["DESTROYED", "DISABLED", "CANCELED", "CANCELLED", "COMPLETED", "RELOCATING"])} &&
    {(_x getOrDefault ["type", ""]) in ["ENEMY_HQ", "STRATEGIC_DRONE_SITE", "FPV_TEAM", "ARTILLERY_SITE", "EW_SITE", "AIR_DEFENCE_SITE", "ENEMY_LAYERED_AA", "CONVOY", "LOGISTICS_RUN", "LOGISTICS_HUB", "BALLISTIC_MISSILE_SITE", "FARP"]}
};
if (count _siteContacts > 0) then {
    private _record = _siteContacts select 0;
    private _subjectId = _record getOrDefault ["networkNodeId", _record getOrDefault ["id", ""]];
    _baseContact = ["PLAYER",_record getOrDefault ["object",objNull],_record getOrDefault ["position",_position],0.92,_record getOrDefault ["type","ЦЕЛЬ"],"","PLAYER_DESIGNATION",90,"",0,-1,createHashMapFromArray [["positionSpace","ATL"],["stableSubjectId",_subjectId],["subjectMode","SITE"]]] call DRO2026_fnc_createContactRecord;
};
if (count _baseContact == 0) exitWith {["TARGET_INVALID","Штаб: цель не прошла проверку контактной модели. Ресурс не списан."] call _fail};

DRO2026_lastLongSupportRequest = time;
DRO2026_resources set [_costPool, (_stock - _launchCount) max 0];
["DRONE_LAUNCH_RESERVED", createHashMapFromArray [["role", "LONG_RANGE"], ["type", _requestedType], ["count", _launchCount], ["decoy", _decoy], ["siteId", _siteId], ["contactId", _baseContact getOrDefault ["id", ""]], ["subjectMode",_baseContact getOrDefault ["subjectMode","RESOLVABLE"]], ["requestId",_requestId]], _siteId] call DRO2026_fnc_emitEvent;

[_origin, _baseContact, _operator, _requestedType, _decoy, _launchCount, _requestSide, _costPool, _siteId, _requestId] spawn {
    params ["_origin", "_baseContact", "_operator", "_type", "_decoy", "_count", "_requestSide", "_costPool", "_siteId", "_requestId"];
    for "_index" from 0 to (_count - 1) do {
        private _target = _baseContact getOrDefault ["target", objNull];
        private _contactInvalid = (toUpperANSI (_baseContact getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"] || {(_baseContact getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]} || {!isNull _target && {!alive _target}} || {!([_baseContact] call DRO2026_fnc_isLiveContactSubject)};
        private _abort = (missionNamespace getVariable ["DRO2026_missionEnding", false]) || {!isNull _operator && {!alive _operator}} || {!([_siteId] call DRO2026_fnc_isSiteOperational)} || {_contactInvalid};
        if (_abort) exitWith {
            private _unlaunched = _count - _index;
            DRO2026_resources set [_costPool, (DRO2026_resources getOrDefault [_costPool, 0]) + _unlaunched];
            ["LONG_RANGE_LAUNCH_ABORTED",createHashMapFromArray [["requestId",_requestId],["type",_type],["unlaunched",_unlaunched],["siteId",_siteId],["reason","SOURCE_OR_TARGET_INVALIDATED"]],_requestId] call DRO2026_fnc_emitEvent;
        };
        private _contact = createHashMap;
        {_contact set [_x, _baseContact get _x]} forEach keys _baseContact;
        private _basePositionASL = _baseContact getOrDefault ["positionASL",_baseContact getOrDefault ["positionMean",[0,0,0]]];
        if (_count > 1 && {isNull (_baseContact getOrDefault ["target", objNull])}) then {
            private _salvoPositionASL = _basePositionASL getPos [40 + random 260, random 360];
            _contact set ["positionSpace","ASL"]; _contact set ["positionASL",_salvoPositionASL]; _contact set ["position",_salvoPositionASL]; _contact set ["positionMean",_salvoPositionASL]; _contact set ["lastKnownPosition",_salvoPositionASL];
        };
        if (toUpperANSI _type == "FP5") then {
            private _strategicTarget = createHashMapFromArray [
                ["ok",true],["nodeId",_contact getOrDefault ["subjectId",""]],["side",enemySide],
                ["positionASL",+(_contact getOrDefault ["positionASL",_contact getOrDefault ["positionMean",[]]])],
                ["object",_contact getOrDefault ["target",objNull]],["serious",true],["subjectMode",_contact getOrDefault ["subjectMode","RESOLVABLE"]]
            ];
            private _munition = [_origin,_strategicTarget,_requestSide,"FP5","",1.35,0.52] call DRO2026_fnc_launchStrategicMunition;
            if (count _munition > 0) then {
                DRO2026_friendlyFP5Used = DRO2026_friendlyFP5Used + 1;
                private _object = _munition getOrDefault ["object",objNull];
                if (!isNull _object) then {[_object,"FP-5 Flamingo",_requestSide] spawn DRO2026_fnc_trackIncomingDrone};
            } else {
                DRO2026_resources set [_costPool,(DRO2026_resources getOrDefault [_costPool,0]) + 1];
            };
        } else {
            [_origin, _contact, _requestSide, false, _operator, _type, _decoy, _index, _count, true, "", _siteId] spawn DRO2026_fnc_launchLongRangeStrike;
        };
        sleep (2.5 + random 3.5);
    };
};
private _launchLabel = if (_decoy) then {"БПЛА-обманка"} else {if (_exactClass != "") then {_exactClass} else {_requestedType}};
["ACK",format ["Штаб: запрос на %1 принят; зарезервировано аппаратов %2. Фактический запуск подтверждается после materialization.", _launchLabel, _launchCount],if (!isNull _requester) then {_requester} else {-2}] call DRO2026_fnc_hqVoice;
[true,"RESERVED","Long-range package reserved and launch sequence started",_requestId,createHashMapFromArray [["count",_launchCount],["siteId",_siteId],["contactId",_baseContact getOrDefault ["id",""]],["subjectMode",_baseContact getOrDefault ["subjectMode","RESOLVABLE"]]]] call DRO2026_fnc_makeResult
