/* Reference integration. Server-owned. Requires INIDBI2 to expose OO_INIDBI. */
if (!isServer) exitWith {false};
if (missionNamespace getVariable ["DRO2026_aiTransportInitialized", false]) exitWith {missionNamespace getVariable ["DRO2026_aiTransportReady", false]};
missionNamespace setVariable ["DRO2026_aiTransportInitialized", true];

private _mode = toUpperANSI (missionNamespace getVariable ["DRO2026_AI_MODE", "OBSERVE"]);
if !(_mode in ["OFF", "OBSERVE", "HYBRID"]) then {_mode = "OBSERVE"};
missionNamespace setVariable ["DRO2026_AI_MODE", _mode, true];

private _missionId = format ["DRO_%1_%2_%3", worldName, floor serverTime, floor random 1000000];
missionNamespace setVariable ["DRO2026_aiMissionId", _missionId, true];
missionNamespace setVariable ["DRO2026_aiSequence", 0];
missionNamespace setVariable ["DRO2026_aiPendingSequence", -1];
missionNamespace setVariable ["DRO2026_aiPendingCandidates", []];
missionNamespace setVariable ["DRO2026_aiPendingAt", -1];
missionNamespace setVariable ["DRO2026_aiPendingStrategicSequence", -1];
missionNamespace setVariable ["DRO2026_aiPendingStrategicAt", -1];
missionNamespace setVariable ["DRO2026_aiLatestDecision", []];
missionNamespace setVariable ["DRO2026_aiBridgeOnline", false, true];
missionNamespace setVariable ["DRO2026_aiLastBridgeSeen", -1];
missionNamespace setVariable ["DRO2026_aiHoldUntil", -1];
missionNamespace setVariable ["DRO2026_aiRequestCount", 0];
missionNamespace setVariable ["DRO2026_aiPolicy", createHashMapFromArray [
    ["desiredTempo", 0.5], ["reconPressure", 0.5], ["strikePressure", 0.5],
    ["reserveCommitment", 0.45], ["logisticsPriority", 0.5], ["recoveryBias", 0.5],
    ["pauseAfterMajorAttack", 60], ["expiresAt", -1]
]];

if (_mode == "OFF") exitWith {
    missionNamespace setVariable ["DRO2026_aiTransportReady", false];
    ["AI transport disabled: OFF mode"] call DRO2026_fnc_log;
    false
};
if (isNil "OO_INIDBI") exitWith {
    missionNamespace setVariable ["DRO2026_aiTransportReady", false];
    ["AI transport unavailable: INIDBI2/OO_INIDBI not loaded; deterministic fallback remains active"] call DRO2026_fnc_log;
    false
};

{
    private _fileName = _x;
    private _db = ["new", _fileName] call OO_INIDBI;
    private _keys = ["getKeys", _fileName] call _db;
    if (!isNil "_keys") then {{["deleteKey", [_fileName, _x]] call _db} forEach _keys};
    ["write", [_fileName, "init", ["init", _missionId]]] call _db;
    ["deleteKey", [_fileName, "init"]] call _db;
} forEach ["DROAI_in", "DROAI_out"];

missionNamespace setVariable ["DRO2026_aiTransportReady", true];
["AI INIDBI2 transport initialized"] call DRO2026_fnc_log;
true
