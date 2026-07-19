if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["DRO2026_aiTransportReady", false]) exitWith {false};
private _db = ["new", "DROAI_in"] call OO_INIDBI;
private _keys = ["getKeys", "DROAI_in"] call _db;
if (isNil "_keys") exitWith {false};
{
    private _key = _x;
    private _value = ["read", ["DROAI_in", _key]] call _db;
    ["deleteKey", ["DROAI_in", _key]] call _db;
    if (_value isEqualType [] && {count _value >= 2}) then {
        private _type = _value param [0, "", [""]];
        private _data = _value param [1, [], [[]]];
        missionNamespace setVariable ["DRO2026_aiLastBridgeSeen", diag_tickTime];
        switch (_type) do {
            case "bridge-config": {
                missionNamespace setVariable ["DRO2026_aiBridgeOnline", true, true];
                missionNamespace setVariable ["DRO2026_aiBridgeMode", _data param [0, "UNKNOWN", [""]], true];
            };
            case "ping": {
                ["pong", [missionNamespace getVariable ["DRO2026_aiMissionId", ""], DRO2026_VERSION, diag_tickTime]] call DRO2026_fnc_writeAIRequest;
            };
            case "ack-out": {
                private _out = ["new", "DROAI_out"] call OO_INIDBI;
                {["deleteKey", ["DROAI_out", _x]] call _out} forEach _data;
            };
            case "decision": {
                missionNamespace setVariable ["DRO2026_aiLatestDecision", +_data];
                private _eventType = if ((toUpperANSI (missionNamespace getVariable ["DRO2026_AI_MODE","OFF"])) == "OBSERVE") then {"AI_DECISION_OBSERVED"} else {"AI_DECISION_RECEIVED"};
                [_eventType, createHashMapFromArray [["sequence", _data param [1, -1]], ["decision", _data param [4, ""]], ["candidateId", _data param [3, ""]]], "AI"] call DRO2026_fnc_emitEvent;
            };
            case "strategic-policy": {
                [_data] call DRO2026_fnc_applyStrategicPolicy;
            };
            case "decision-error": {
                ["AI_DECISION_REJECTED", createHashMapFromArray [["jobType", _data param [0, ""]], ["sequence", _data param [1, -1]], ["reason", _data param [2, "UNKNOWN"]]], "AI"] call DRO2026_fnc_emitEvent;
            };
        };
    };
} forEach _keys;
private _lastSeen = missionNamespace getVariable ["DRO2026_aiLastBridgeSeen", -1];
missionNamespace setVariable ["DRO2026_aiBridgeOnline", _lastSeen >= 0 && {(diag_tickTime - _lastSeen) < 30}, true];
true
