params [["_contact", createHashMap, [createHashMap]]];
if (count _contact == 0) exitWith {false};
private _resolution = [_contact] call DRO2026_fnc_resolveContactSubject;
_resolution params ["_live", "_object", "_reason", "_terminalState"];
if (_live) exitWith {
    if (!isNull _object) then {_contact set ["subjectObject", _object]; _contact set ["target", _object]};
    true
};
if (_reason in ["CONTACT_EMPTY","SUBJECT_ID_EMPTY","SUBJECT_UNRESOLVED"]) exitWith {[_contact, _reason] call DRO2026_fnc_quarantineContact};
if (_terminalState in ["DESTROYED","EXPIRED"]) then {
    _contact set ["state", _terminalState];
    _contact set ["bdaState", if (_terminalState == "DESTROYED") then {"CONFIRMED_DESTROYED"} else {"EXPIRED"}];
    _contact set ["lastUpdatedAt", time];
};
false
