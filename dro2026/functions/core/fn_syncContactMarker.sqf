params [
    "_id",
    ["_position", []],
    ["_confidence", 0],
    ["_classification", "UNKNOWN"],
    ["_deleted", false],
    ["_uncertaintyRadius", 80],
    ["_bdaState", "DETECTED"]
];
if (!hasInterface) exitWith {};
if !(_id isEqualType "") exitWith {};

private _marker = format ["D26_CONTACT_%1", _id];
private _areaMarker = format ["D26_CONTACT_AREA_%1", _id];
if (_deleted) exitWith {
    if (markerType _marker != "") then {deleteMarkerLocal _marker};
    if (markerShape _areaMarker != "") then {deleteMarkerLocal _areaMarker};
};
if (count _position < 2) exitWith {};

if (markerType _marker == "") then {
    createMarkerLocal [_marker, _position];
    _marker setMarkerShapeLocal "ICON";
    _marker setMarkerColorLocal "ColorOPFOR";
};
if (markerShape _areaMarker == "") then {
    createMarkerLocal [_areaMarker, _position];
    _areaMarker setMarkerShapeLocal "ELLIPSE";
    _areaMarker setMarkerBrushLocal "Border";
    _areaMarker setMarkerColorLocal "ColorOPFOR";
};

private _safeConfidence = (_confidence max 0) min 1;
private _destroyed = _bdaState in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"];
_marker setMarkerTypeLocal (if (_destroyed) then {"mil_destroy"} else {"mil_unknown"});
_marker setMarkerPosLocal _position;
_marker setMarkerAlphaLocal (linearConversion [0.15, 1, _safeConfidence, 0.22, 0.95, true]);
_marker setMarkerSizeLocal [0.7 + _safeConfidence, 0.7 + _safeConfidence];
_marker setMarkerTextLocal format [" %1 · %2 · %3%%", _classification, _bdaState, round (_safeConfidence * 100)];

private _radius = (_uncertaintyRadius max 12) min 1800;
_areaMarker setMarkerPosLocal _position;
_areaMarker setMarkerSizeLocal [_radius, _radius];
_areaMarker setMarkerAlphaLocal (linearConversion [0, 1, _safeConfidence, 0.42, 0.12, true]);