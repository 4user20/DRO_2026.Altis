params [
    ["_object", objNull, [objNull]],
    ["_positionBucket", 500, [0]],
    ["_includeExactPosition", false, [true]]
];
if (isNull _object) exitWith {createHashMap};
_positionBucket = (_positionBucket max 25) min 2000;
private _positionASL = getPosASL _object;
private _bucketASL = [
    floor ((_positionASL select 0) / _positionBucket) * _positionBucket,
    floor ((_positionASL select 1) / _positionBucket) * _positionBucket,
    floor ((_positionASL select 2) / 50) * 50
];
private _isVehicle = _object isKindOf "AllVehicles";
private _crew = if (_isVehicle) then {crew _object} else {[]};
private _driver = if (_isVehicle) then {driver _object} else {objNull};
private _group = if (!isNull _driver) then {group _driver} else {grpNull};
private _snapshot = createHashMapFromArray [
    ["class", typeOf _object], ["netId", netId _object],
    ["alive", alive _object], ["local", local _object], ["owner", owner _object],
    ["damage", round ((damage _object) * 20) / 20],
    ["fuel", if (_isVehicle) then {round ((fuel _object) * 20) / 20} else {-1}],
    ["canMove", if (_isVehicle) then {canMove _object} else {false}], ["canFire", if (_isVehicle) then {canFire _object} else {false}],
    ["speed", round (speed _object / 5) * 5],
    ["crew", count _crew], ["driver", if (isNull _driver) then {""} else {netId _driver}],
    ["groupId", if (isNull _group) then {""} else {_group getVariable ["DRO2026_telemetryId", ""]}],
    ["flightAuthority", _object getVariable ["DRO2026_flightAuthority", ""]],
    ["siteId", _object getVariable ["DRO2026_siteId", ""]],
    ["networkNodeId", _object getVariable ["DRO2026_networkNodeId", ""]],
    ["positionBucketASL", _bucketASL]
];
if (_includeExactPosition) then {
    _snapshot set ["positionASL", [
        round ((_positionASL select 0) / 10) * 10,
        round ((_positionASL select 1) / 10) * 10,
        round ((_positionASL select 2) / 5) * 5
    ]];
    _snapshot set ["vectorDir", (vectorDir _object) apply {round (_x * 100) / 100}];
    _snapshot set ["velocity", (velocity _object) apply {round (_x * 10) / 10}];
};
_snapshot
