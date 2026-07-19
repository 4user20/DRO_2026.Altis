params ["_owner", ["_target", objNull], ["_position", []], ["_confidence", 0.5], ["_kind", "UNKNOWN"]];
if (count _position == 0 && {!isNull _target}) then {_position = getPosATL _target};
if (count _position == 0) exitWith {createHashMap};

private _prototype = [_owner, _target, _position, _confidence, _kind] call DRO2026_fnc_createContactRecord;
if (count _prototype == 0) exitWith {createHashMap};
private _id = _prototype getOrDefault ["id", ""];
private _index = DRO2026_contacts findIf {
    (_x getOrDefault ["id", ""]) == _id && {(_x getOrDefault ["owner", ""]) == _owner}
};
private _contact = createHashMap;

if (_index >= 0) then {
    _contact = DRO2026_contacts select _index;
    _contact set ["position", +_position];
    _contact set ["confidence", ((_contact getOrDefault ["confidence", 0]) max _confidence) min 1];
    _contact set ["lastSeen", time];
    _contact set ["target", _target];
    _contact set ["kind", _kind];
} else {
    _contact = _prototype;
    DRO2026_contacts pushBack _contact;
};

if (_owner == "PLAYER") then {
    private _confidenceNow = _contact getOrDefault ["confidence", 0.5];
    if (hasInterface) then {
        [_id, _position, _confidenceNow, _kind, false] call DRO2026_fnc_syncContactMarker;
    };
    if (isServer) then {
        [_id, _position, _confidenceNow, _kind, false] remoteExecCall ["DRO2026_fnc_syncContactMarker", -2, false];
    };
};
_contact