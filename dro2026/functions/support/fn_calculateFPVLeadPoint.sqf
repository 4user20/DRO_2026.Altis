/* Returns an ATL aim point for the assigned contact only. No global target search. */
params ["_drone", "_target", "_contact", "_fallbackPosition", ["_desiredSpeed", 36], ["_channelQuality", 1]];
if (isNull _drone || {count _fallbackPosition < 2}) exitWith {+_fallbackPosition};
private _targetPosition = +_fallbackPosition;
private _velocity = _contact getOrDefault ["velocityEstimate", [0,0,0]];
if (!isNull _target && {alive _target}) then {
    _targetPosition = getPosATL _target;
    _velocity = velocity _target;
};
private _distance = _drone distance2D _targetPosition;
private _leadTime = ((_distance / (_desiredSpeed max 12)) max 0) min 2.5;
private _confidence = ((_contact getOrDefault ["confidence", 0.5]) max 0) min 1;
private _uncertainty = (_contact getOrDefault ["uncertaintyRadius", 120]) max 0;
private _uncertaintyFactor = linearConversion [30, 500, _uncertainty, 1, 0.15, true];
private _leadFactor = ((_confidence * _uncertaintyFactor * ((_channelQuality max 0) min 1)) max 0) min 1;
_targetPosition vectorAdd (_velocity vectorMultiply (_leadTime * _leadFactor))
