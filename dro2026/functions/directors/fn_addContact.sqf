params ["_owner", ["_target", objNull], ["_position", []], ["_confidence", 0.5], ["_kind", "UNKNOWN"]];
if (count _position == 0 && {!isNull _target}) then {_position = getPosATL _target};
if (count _position == 0) exitWith {createHashMap};

private _id = if (!isNull _target) then {
    private _stored = _target getVariable ["DRO2026_contactId", ""];
    if (_stored == "") then {
        _stored = format ["C_%1_%2", floor diag_tickTime, floor random 1000000];
        _target setVariable ["DRO2026_contactId", _stored];
    };
    _stored
} else {
    format ["P_%1_%2_%3", round (_position select 0), round (_position select 1), _owner]
};

private _index = DRO2026_contacts findIf {
    (_x getOrDefault ["id", ""]) == _id && {(_x getOrDefault ["owner", ""]) == _owner}
};
private _contact = createHashMap;

if (_index >= 0) then {
    _contact = DRO2026_contacts select _index;
    _contact set ["position", _position];
    _contact set ["confidence", ((_contact getOrDefault ["confidence", 0]) max _confidence) min 1];
    _contact set ["lastSeen", time];
    _contact set ["target", _target];
    _contact set ["kind", _kind];
} else {
    _contact = createHashMapFromArray [
        ["id", _id],
        ["owner", _owner],
        ["target", _target],
        ["position", _position],
        ["confidence", _confidence min 1],
        ["lastSeen", time],
        ["kind", _kind],
        ["marker", ""]
    ];
    DRO2026_contacts pushBack _contact;
};

if (_owner == "PLAYER" && {hasInterface}) then {
    private _marker = _contact getOrDefault ["marker", ""];
    if (_marker == "") then {
        _marker = format ["D26_CONTACT_%1", _id];
        createMarkerLocal [_marker, _position];
        _marker setMarkerShapeLocal "ICON";
        _marker setMarkerTypeLocal "mil_unknown";
        _marker setMarkerColorLocal "ColorOPFOR";
        _contact set ["marker", _marker];
    };
    private _c = _contact getOrDefault ["confidence", 0.5];
    _marker setMarkerPosLocal _position;
    _marker setMarkerAlphaLocal (linearConversion [0.3, 1, _c, 0.35, 0.95, true]);
    _marker setMarkerSizeLocal [0.7 + _c, 0.7 + _c];
    _marker setMarkerTextLocal format [" Контакт: %1 (%2%%)", _kind, round (_c * 100)];
};
_contact
