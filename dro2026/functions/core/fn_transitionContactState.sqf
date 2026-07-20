params [
    ["_contact",createHashMap,[createHashMap]],
    ["_newState","INVALID",[""]],
    ["_reason","UNSPECIFIED",[""]],
    ["_metadata",createHashMap,[createHashMap]]
];
if (count _contact == 0) exitWith {createHashMap};

private _state = toUpperANSI _newState;
private _terminalStates = ["LOST","DESTROYED","INVALID","EXPIRED"];
private _current = toUpperANSI (_contact getOrDefault ["state","ACTIVE"]);
if (_current in _terminalStates) exitWith {_contact};
if !(_state in ["ACTIVE","STALE","LOST","DESTROYED","INVALID","EXPIRED"]) exitWith {_contact};

private _object = _contact getOrDefault ["object",_contact getOrDefault ["subjectObject",objNull]];
private _lastPosition = _contact getOrDefault ["lastKnownPosition",_contact getOrDefault ["positionASL",[]]];
if (_object isEqualType objNull && {!isNull _object}) then {
    _lastPosition = getPosASL _object;
};
if (count _lastPosition == 2) then {_lastPosition pushBack (getTerrainHeightASL _lastPosition)};

_contact set ["state",_state];
_contact set ["terminalReason",if (_state in _terminalStates) then {_reason} else {""}];
_contact set ["lastKnownPosition",+_lastPosition];
_contact set ["positionASL",+_lastPosition];
_contact set ["position",+_lastPosition];
_contact set ["positionMean",+_lastPosition];
_contact set ["lastUpdatedAt",time];
if (_state == "ACTIVE") then {_contact set ["lastConfirmedAt",time]};
if (_state in _terminalStates) then {
    _contact set ["terminalAt",time];
    _contact set ["reservationId",""];
    _contact set ["engagedAt",-1];
    private _contactId = _contact getOrDefault ["contactId",_contact getOrDefault ["id",""]];
    private _activeIndex = DRO2026_contacts findIf {
        (_x getOrDefault ["id",""]) == _contactId &&
        {((_x getOrDefault ["state","ACTIVE"]) in ["ACTIVE","STALE"])}
    };
    if (_activeIndex >= 0) then {DRO2026_contacts set [_activeIndex,_contact]};
    {
        if (_x isEqualType createHashMap && {(_x getOrDefault ["contactId",""]) == _contactId}) then {
            _x set ["status","CANCELLED"];
            _x set ["terminalReason",format ["CONTACT_%1",_state]];
            _x set ["lastUpdatedAt",time];
        };
    } forEach DRO2026_actionIntents;
};
{
    _contact set [_x,_metadata get _x];
} forEach keys _metadata;

["CONTACT","STATE_TRANSITION",createHashMapFromArray [
    ["contactId",_contact getOrDefault ["id",""]],
    ["from",_current],["to",_state],["reason",_reason],
    ["position",+_lastPosition]
],_contact getOrDefault ["id","CONTACT"]] call DRO2026_fnc_logStructured;
_contact
