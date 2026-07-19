params ["_id", ["_position", []], ["_confidence", 0], ["_kind", "UNKNOWN"], ["_deleted", false]];
if (!hasInterface) exitWith {};
if !(_id isEqualType "") exitWith {};

private _marker = format ["D26_CONTACT_%1", _id];
if (_deleted) exitWith {
    if (markerType _marker != "") then {deleteMarkerLocal _marker};
};
if (count _position < 2) exitWith {};

if (markerType _marker == "") then {
    createMarkerLocal [_marker, _position];
    _marker setMarkerShapeLocal "ICON";
    _marker setMarkerTypeLocal "mil_unknown";
    _marker setMarkerColorLocal "ColorOPFOR";
};
private _safeConfidence = (_confidence max 0) min 1;
_marker setMarkerPosLocal _position;
_marker setMarkerAlphaLocal (linearConversion [0.3, 1, _safeConfidence, 0.35, 0.95, true]);
_marker setMarkerSizeLocal [0.7 + _safeConfidence, 0.7 + _safeConfidence];
_marker setMarkerTextLocal format [" Контакт: %1 (%2%%)", _kind, round (_safeConfidence * 100)];