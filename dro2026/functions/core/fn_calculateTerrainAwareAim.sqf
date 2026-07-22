/*
    Returns an ASL navigation point. The destination contract is PositionASL.
    Terrain probing uses 2D ATL coordinates only; altitude remains ASL.

    _allowLateralAvoidance=false is intended for committed terminal ingress. In
    that mode the controller climbs over terrain instead of choosing a new left
    or right detour every guidance tick.
*/
params [
    "_vehicle",
    "_destinationASL",
    ["_clearance", 25],
    ["_lookAhead", [80, 160, 260]],
    ["_terminalDistance", 260],
    ["_lateralNoise", 6],
    ["_allowLateralAvoidance", true]
];
if (isNull _vehicle || {count _destinationASL < 3}) exitWith {+_destinationASL};

private _currentASL = getPosASL _vehicle;
private _currentATL = ASLToATL _currentASL;
private _destinationATL = ASLToATL _destinationASL;
private _distance = _currentASL distance2D _destinationASL;
private _bearing = _currentATL getDir _destinationATL;
private _maxTerrainASL = getTerrainHeightASL _destinationATL;
private _steepestRise = 0;

{
    private _sampleATL = _currentATL getPos [_x min _distance, _bearing];
    private _terrainASL = getTerrainHeightASL _sampleATL;
    _maxTerrainASL = _maxTerrainASL max _terrainASL;
    _steepestRise = _steepestRise max (_terrainASL - (_currentASL select 2));
} forEach _lookAhead;

private _aimATL = +_destinationATL;
if (_allowLateralAvoidance && {_distance > _terminalDistance} && {_steepestRise > 35}) then {
    private _probeDistance = ((_lookAhead select ((count _lookAhead) - 1)) min (_distance * 0.55)) max 120;
    private _leftATL = _currentATL getPos [_probeDistance, _bearing - 38];
    private _rightATL = _currentATL getPos [_probeDistance, _bearing + 38];
    private _leftTerrainASL = getTerrainHeightASL _leftATL;
    private _rightTerrainASL = getTerrainHeightASL _rightATL;
    private _avoidanceSide = _vehicle getVariable ["DRO2026_terrainAvoidanceSide",0];
    if (_avoidanceSide == 0) then {
        _avoidanceSide = if (_leftTerrainASL <= _rightTerrainASL) then {-1} else {1};
        _vehicle setVariable ["DRO2026_terrainAvoidanceSide",_avoidanceSide];
    };
    _aimATL = if (_avoidanceSide < 0) then {_leftATL} else {_rightATL};
    _maxTerrainASL = _maxTerrainASL min ((if (_avoidanceSide < 0) then {_leftTerrainASL} else {_rightTerrainASL}) + 25);
} else {
    if (_distance <= _terminalDistance || {_steepestRise < 20}) then {_vehicle setVariable ["DRO2026_terrainAvoidanceSide",0]};
};

private _desiredAltitudeASL = if (_distance <= _terminalDistance) then {
    private _blend = linearConversion [0, _terminalDistance, _distance, 0, 1, true];
    ((_destinationASL select 2) + 1.5) max ((getTerrainHeightASL _aimATL) + ((_clearance * _blend) max 5))
} else {
    _maxTerrainASL + _clearance
};

private _aimASL = if (_lateralNoise > 0) then {
    private _seed = _vehicle getVariable ["DRO2026_noiseSeed", -1];
    if (_seed < 0) then {_seed = random 100; _vehicle setVariable ["DRO2026_noiseSeed", _seed]};
    private _noisePhase = (diag_tickTime * 1.7) + _seed;
    private _sideOffset = (sin (_noisePhase * 57.2958)) * _lateralNoise;
    if (abs _sideOffset > 0.01) then {
        private _noiseATL = _aimATL getPos [abs _sideOffset, _bearing + (if (_sideOffset >= 0) then {90} else {-90})];
        private _aimASL = ATLToASL _noiseATL;
        _aimASL
    } else {
        ATLToASL _aimATL
    }
} else {
    ATLToASL _aimATL
};
_aimASL set [2, _desiredAltitudeASL];
_aimASL
