params [
    "_owner",
    ["_target", objNull],
    ["_position", []],
    ["_confidence", 0.5],
    ["_kind", "UNKNOWN"],
    ["_id", ""]
];

if !(_owner isEqualType "") exitWith {createHashMap};
if !(_kind isEqualType "") then {_kind = "UNKNOWN"};
if (count _position < 2 && {!isNull _target}) then {_position = getPosATL _target};
if (count _position < 2) exitWith {createHashMap};

if (_id == "") then {
    if (!isNull _target) then {
        _id = _target getVariable ["DRO2026_contactId", ""];
        if (_id == "") then {
            _id = format ["C_%1_%2", floor diag_tickTime, floor random 1000000];
            _target setVariable ["DRO2026_contactId", _id, true];
        };
    } else {
        _id = format ["P_%1_%2_%3", round (_position select 0), round (_position select 1), _owner];
    };
};

createHashMapFromArray [
    ["schema", 1],
    ["id", _id],
    ["owner", _owner],
    ["target", _target],
    ["position", +_position],
    ["confidence", (_confidence max 0) min 1],
    ["lastSeen", time],
    ["createdAt", time],
    ["kind", _kind],
    ["marker", ""]
]