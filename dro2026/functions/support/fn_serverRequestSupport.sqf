if (!isServer) exitWith {};
params ["_requester", "_kind", ["_payload", []]];

if (isNull _requester || {!isPlayer _requester}) exitWith {};
if !(_kind isEqualType "") exitWith {};
if !(_payload isEqualType []) exitWith {
    ["Штаб: отклонён некорректный запрос поддержки.", _requester] call DRO2026_fnc_supportMessage;
};

private _requestOwner = owner _requester;
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != _requestOwner}) exitWith {
    [format ["Отклонён spoofed support request: remote=%1 owner=%2 uid=%3", remoteExecutedOwner, _requestOwner, getPlayerUID _requester]] call DRO2026_fnc_log;
};

private _rateKey = format ["DRO2026_supportRequest_%1", getPlayerUID _requester];
private _lastRequest = missionNamespace getVariable [_rateKey, -10];
if ((diag_tickTime - _lastRequest) < 0.35) exitWith {
    ["Штаб: запрос уже обрабатывается.", _requester] call DRO2026_fnc_supportMessage;
};
missionNamespace setVariable [_rateKey, diag_tickTime];

private _validPosition = {
    params ["_position"];
    _position isEqualType [] &&
    {count _position >= 2} &&
    {(_position select 0) isEqualType 0} &&
    {(_position select 1) isEqualType 0} &&
    {(_position select 0) >= 0} &&
    {(_position select 1) >= 0} &&
    {(_position select 0) <= worldSize} &&
    {(_position select 1) <= worldSize}
};
private _catalogContains = {
    params ["_mode", ["_class", ""]];
    private _catalog = missionNamespace getVariable ["DRO2026_supportCatalog", []];
    if !(_catalog isEqualType []) exitWith {false};
    (_catalog findIf {
        (_x isEqualType []) &&
        {(_x param [1, ""]) == _mode} &&
        {_class == "" || {(_x param [2, ""]) == _class}}
    }) >= 0
};
private _rejectMalformed = {
    ["Штаб: отклонён некорректно сформированный запрос поддержки.", _requester] call DRO2026_fnc_supportMessage;
};

_kind = toUpperANSI _kind;
switch _kind do {
    case "FPV": {
        private _position = _payload param [0, []];
        private _manual = _payload param [1, false];
        private _quantity = _payload param [2, 1];
        private _class = _payload param [3, ""];
        if !(_manual isEqualType true && {_quantity isEqualType 0} && {_class isEqualType ""}) exitWith {call _rejectMalformed};
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка FPV.", _requester] call DRO2026_fnc_supportMessage};
        private _classPublished = true;
        if (_class != "") then {
            private _modeTemplate = if (_manual) then {"FPV_CLASS_MANUAL:%1"} else {"FPV_CLASS_AUTO:%1"};
            private _mode = format [_modeTemplate, _class];
            _classPublished = [_mode, _class] call _catalogContains;
        };
        if (!_classPublished) exitWith {
            [format ["Штаб: FPV-класс %1 не опубликован для выбранной стороны.", _class], _requester] call DRO2026_fnc_supportMessage;
        };
        [_position, _manual, _quantity, _requester, _class] call DRO2026_fnc_requestFPV;
    };
    case "ISR": {
        private _position = _payload param [0, []];
        private _type = _payload param [1, "AUTO"];
        if !(_type isEqualType "") exitWith {call _rejectMalformed};
        if !([_position] call _validPosition) exitWith {["Штаб: некорректный сектор разведки.", _requester] call DRO2026_fnc_supportMessage};
        private _upperType = toUpperANSI _type;
        private _classPublished = true;
        private _class = "";
        if ((_upperType find "CLASS:") == 0) then {
            _class = _type select [6];
            private _mode = format ["ISR_CLASS:%1", _class];
            _classPublished = _class != "" && {[_mode, _class] call _catalogContains};
        };
        if (!_classPublished) exitWith {
            [format ["Штаб: разведывательный БПЛА %1 не опубликован для выбранной стороны.", _class], _requester] call DRO2026_fnc_supportMessage;
        };
        [_position, _type, _requester] call DRO2026_fnc_requestISR;
    };
    case "LONG_RANGE": {
        private _position = _payload param [0, []];
        private _type = _payload param [1, "AUTO"];
        private _decoy = _payload param [2, false];
        private _quantity = _payload param [3, 1];
        if !(_type isEqualType "" && {_decoy isEqualType true} && {_quantity isEqualType 0}) exitWith {call _rejectMalformed};
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка дальнего удара.", _requester] call DRO2026_fnc_supportMessage};
        private _upperType = toUpperANSI _type;
        if (_decoy && {_upperType != "AUTO"}) exitWith {call _rejectMalformed};
        private _catalogClass = if ((_upperType find "CLASS:") == 0) then {_type select [6]} else {""};
        if (_catalogClass == "" && {(_upperType find "CLASS:") == 0}) exitWith {call _rejectMalformed};
        private _catalogMode = if (_catalogClass != "") then {
            format ["STRIKE_CLASS:%1", _catalogClass]
        } else {
            if (_decoy) then {"STRIKE_DECOY"} else {format ["STRIKE_%1", _upperType]}
        };
        if !([_catalogMode, _catalogClass] call _catalogContains) exitWith {
            [format ["Штаб: профиль дальнего удара %1 не опубликован для выбранной стороны.", _type], _requester] call DRO2026_fnc_supportMessage;
        };
        [_position, _type, _decoy, _quantity, _requester] call DRO2026_fnc_requestLongRangeSupport;
    };
    case "ARTILLERY": {
        private _position = _payload param [0, []];
        private _class = _payload param [1, ""];
        private _rounds = _payload param [2, 3];
        if !(_class isEqualType "" && {_rounds isEqualType 0}) exitWith {call _rejectMalformed};
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка артиллерии.", _requester] call DRO2026_fnc_supportMessage};
        if (_class == "" || {!([format ["ARTY:%1", _class], _class] call _catalogContains)}) exitWith {
            [format ["Штаб: артсистема %1 не опубликована для выбранной стороны.", _class], _requester] call DRO2026_fnc_supportMessage;
        };
        [_position, _class, _rounds, _requester] call DRO2026_fnc_requestArtillery;
    };
    case "AIR": {
        private _position = _payload param [0, []];
        private _class = _payload param [1, ""];
        private _quantity = _payload param [2, 1];
        if !(_class isEqualType "" && {_quantity isEqualType 0}) exitWith {call _rejectMalformed};
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка авиационной поддержки.", _requester] call DRO2026_fnc_supportMessage};
        if (_class == "" || {!([format ["AIR:%1", _class], _class] call _catalogContains)}) exitWith {
            [format ["Штаб: авиационный класс %1 не опубликован для выбранной стороны.", _class], _requester] call DRO2026_fnc_supportMessage;
        };
        [_position, _class, _quantity, _requester] call DRO2026_fnc_requestAirSupport;
    };
    default {
        [format ["Штаб: неизвестный тип поддержки %1.", _kind], _requester] call DRO2026_fnc_supportMessage;
    };
};
