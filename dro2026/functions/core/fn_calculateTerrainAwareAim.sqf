/*
    Returns an ASL navigation point which keeps an aircraft above terrain and,
    when a steep obstacle is directly ahead, biases the route toward the lower side.
*/
params [
    "_vehicle",
    "_destinationAGL",
    ["_clearance", 25],
    ["_lookAhead", [80, 160, 260]],
    ["_terminalDistance", 260],
    ["_lateralNoise", 6]
];
if (isNull _vehicle || {count _destinationAGL < 2}) exitWith {AGLToASL _destinationAGL};

private _currentASL = getPosASL _vehicle;
private _currentAGL = ASLToAGL _currentASL;
private _distance = _vehicle distance2D _destinationAGL;
private _bearing = _currentAGL getDir _destinationAGL;
private _maxTerrain = getTerrainHeightASL _destinationAGL;
private _steepestRise = 0;

{
    private _sample = _currentAGL getPos [_x min _distance, _bearing];
    private _terrain = getTerrainHeightASL _sample;
    _maxTerrain = _maxTerrain max _terrain;
    _steepestRise = _steepestRise max (_terrain - (_currentASL select 2));
} forEach _lookAhead;

private _aim2D = +_destinationAGL;
if (_distance > _terminalDistance && {_steepestRise > 35}) then {
    private _probeDistance = ((_lookAhead select ((count _lookAhead) - 1)) min (_distance * 0.55)) max 120;
    private _left = _currentAGL getPos [_probeDistance, _bearing - 38];
    private _right = _currentAGL getPos [_probeDistance, _bearing + 38];
    private _leftTerrain = getTerrainHeightASL _left;
    private _rightTerrain = getTerrainHeightASL _right;
    _aim2D = if (_leftTerrain <= _rightTerrain) then {_left} else {_right};
    _maxTerrain = _maxTerrain min ((_leftTerrain min _rightTerrain) + 25);
};

private _targetASL = AGLToASL _destinationAGL;
private _desiredAltitude = if (_distance <= _terminalDistance) then {
    private _blend = linearConversion [0, _terminalDistance, _distance, 0, 1, true];
    ((_targetASL select 2) + 1.5) max ((getTerrainHeightASL _aim2D) + ((_clearance * _blend) max 5))
} else {
    _maxTerrain + _clearance
};

private _seed = _vehicle getVariable ["DRO2026_noiseSeed", -1];
if (_seed < 0) then {_seed = random 100; _vehicle setVariable ["DRO2026_noiseSeed", _seed]};
private _noisePhase = (diag_tickTime * 1.7) + _seed;
private _sideOffset = (sin (_noisePhase * 57.2958)) * _lateralNoise;
private _noisePoint = _aim2D getPos [abs _sideOffset, _bearing + (if (_sideOffset >= 0) then {90} else {-90})];
private _aimASL = AGLToASL _noisePoint;
_aimASL set [2, _desiredAltitude];
_aimASL
