params [
    ["_vehicle", objNull, [objNull]],
    ["_newAuthority", "NONE", [""]],
    ["_reason", "UNSPECIFIED", [""]],
    ["_expectedAuthority", "", [""]]
];
if (!isServer || {isNull _vehicle}) exitWith {false};
private _allowed = ["ARMA_AI","DRONE_TWEAKS","FPV_TERMINAL","PLAYER","NONE"];
_newAuthority = toUpperANSI _newAuthority;
if !(_newAuthority in _allowed) exitWith {false};
private _current = _vehicle getVariable ["DRO2026_flightAuthority","NONE"];
if (_expectedAuthority != "" && {toUpperANSI _expectedAuthority != _current}) exitWith {false};
if (_current == _newAuthority) exitWith {true};
_vehicle setVariable ["DRO2026_flightAuthority",_newAuthority,true];
private _revision = (_vehicle getVariable ["DRO2026_flightAuthorityRevision",0]) + 1;
_vehicle setVariable ["DRO2026_flightAuthorityRevision",_revision,true];
["DRONE","FLIGHT_AUTHORITY_CHANGED",createHashMapFromArray [["vehicle",netId _vehicle],["from",_current],["to",_newAuthority],["reason",_reason],["revision",_revision]],netId _vehicle] call DRO2026_fnc_logStructured;
true
