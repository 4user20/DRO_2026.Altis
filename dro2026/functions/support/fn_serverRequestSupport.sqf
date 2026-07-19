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

_kind = toUpperANSI _kind;
switch _kind do {
    case "FPV": {
        _payload params ["_position", ["_manual", false], ["_quantity", 1], ["_class", ""]];
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка FPV.", _requester] call DRO2026_fnc_supportMessage};
        [_position, _manual, _quantity, _requester, _class] call DRO2026_fnc_requestFPV;
    };
    case "ISR": {
        _payload params ["_position", ["_type", "AUTO"]];
        if !([_position] call _validPosition) exitWith {["Штаб: некорректный сектор разведки.", _requester] call DRO2026_fnc_supportMessage};
        [_position, _type, _requester] call DRO2026_fnc_requestISR;
    };
    case "LONG_RANGE": {
        _payload params ["_position", ["_type", "AUTO"], ["_decoy", false], ["_quantity", 1]];
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка дальнего удара.", _requester] call DRO2026_fnc_supportMessage};
        [_position, _type, _decoy, _quantity, _requester] call DRO2026_fnc_requestLongRangeSupport;
    };
    case "ARTILLERY": {
        _payload params ["_position", "_class", ["_rounds", 3]];
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка артиллерии.", _requester] call DRO2026_fnc_supportMessage};
        [_position, _class, _rounds, _requester] call DRO2026_fnc_requestArtillery;
    };
    case "AIR": {
        _payload params ["_position", "_class", ["_quantity", 1]];
        if !([_position] call _validPosition) exitWith {["Штаб: некорректная точка авиационной поддержки.", _requester] call DRO2026_fnc_supportMessage};
        [_position, _class, _quantity, _requester] call DRO2026_fnc_requestAirSupport;
    };
    default {
        [format ["Штаб: неизвестный тип поддержки %1.", _kind], _requester] call DRO2026_fnc_supportMessage;
    };
};
