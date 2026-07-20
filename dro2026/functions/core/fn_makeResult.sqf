params [
    ["_ok", false, [true]],
    ["_code", "UNKNOWN", [""]],
    ["_message", "", [""]],
    ["_requestId", "", [""]],
    ["_data", createHashMap, [createHashMap]]
];
createHashMapFromArray [
    ["ok", _ok], ["code", _code], ["message", _message],
    ["requestId", _requestId], ["data", _data]
]
