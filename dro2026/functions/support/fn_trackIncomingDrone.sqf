params ["_drone", ["_label", "FPV"], ["_side", east]];
if (!hasInterface || {isNull _drone}) exitWith {};
private _isEnemy = _side != playersSide;
private _marker = format ["D26_INCOMING_%1_%2", floor diag_tickTime, floor random 1000000];
private _announced = false;
while {alive _drone} do {
    private _distance = player distance2D _drone;
    private _visible = (player knowsAbout _drone) > 1 || {_distance < 900};
    if (_isEnemy && {_visible}) then {
        if (!_announced) then {
            _announced = true;
            createMarkerLocal [_marker, getPosATL _drone];
            _marker setMarkerShapeLocal "ICON";
            _marker setMarkerTypeLocal "mil_triangle";
            _marker setMarkerColorLocal "ColorOPFOR";
            _marker setMarkerTextLocal format [" Входящий %1", _label];
            systemChat format ["Штаб: Внимание, входящий %1!", _label];
        };
        if (_announced) then {_marker setMarkerPosLocal getPosATL _drone};
    };
    uiSleep 0.45;
};
if (_announced) then {deleteMarkerLocal _marker};
