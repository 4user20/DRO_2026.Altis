params ["_position", ["_affectedSide", playersSide]];
if !(_position isEqualType []) exitWith {0};
if (count _position < 2) exitWith {0};
if !(missionNamespace getVariable ["DRO2026_networkBuilt", false]) exitWith {
    linearConversion [0, 100, DRO2026_resources getOrDefault ["enemyEW", 0], 0, 0.75, true]
};

private _best = 0;
{
    private _node = DRO2026_networkNodes get _x;
    if ((_node getOrDefault ["type", ""]) == "EW_SITE" && {
        (_node getOrDefault ["side", sideUnknown]) != _affectedSide
    } && {
        !((_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED"])
    }) then {
        private _mode = _node getOrDefault ["emissionState", "PASSIVE"];
        private _modeFactor = switch _mode do {
            case "OFF": {0};
            case "PASSIVE": {0.18};
            case "ACTIVE": {0.78};
            case "BURST": {1};
            case "RELOCATING": {0.08};
            default {0.35};
        };
        private _nodePos = _node getOrDefault ["position", _position];
        private _radius = _node getOrDefault ["jammingRadius", 5200];
        private _distance = _nodePos distance2D _position;
        if (_distance < _radius && {_modeFactor > 0}) then {
            private _distanceFactor = linearConversion [0, _radius, _distance, 1, 0, true];
            private _fromASL = AGLToASL (_nodePos vectorAdd [0,0,7]);
            private _toASL = AGLToASL (_position vectorAdd [0,0,20]);
            private _terrainFactor = if (terrainIntersectASL [_fromASL, _toASL]) then {0.52} else {1};
            private _components = _node getOrDefault ["components", createHashMap];
            private _power = (_components getOrDefault ["jammer", 1]) min 1;
            _best = _best max ((_modeFactor * _distanceFactor * _terrainFactor * _power) min 1);
        };
    };
} forEach keys DRO2026_networkNodes;
_best
