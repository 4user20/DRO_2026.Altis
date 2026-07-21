if (!isServer) exitWith {};

private _deferEnd = false;
if (missionNamespace getVariable ["DRO2026_initialized",false] && {missionNamespace getVariable ["DRO2026_networkBuilt",false]}) then {
    private _gate = [] call DRO2026_fnc_evaluateEndgame;
    if !(_gate getOrDefault ["ready",false]) then {
        missionNamespace setVariable ["DRO2026_missionEnding",false,true];
        ["OBJECTIVE","END_REQUEST_DEFERRED",createHashMapFromArray [
            ["reason",_gate getOrDefault ["reason","STRATEGIC_OPERATION_ACTIVE"]],
            ["elapsed",_gate getOrDefault ["elapsed",0]],
            ["minimumDuration",_gate getOrDefault ["minimumDuration",3600]],
            ["strategicCount",_gate getOrDefault ["strategicCount",0]]
        ],"OPERATION"] call DRO2026_fnc_logStructured;
        ["ALERT"] call DRO2026_fnc_hqVoice;
        [["Операция продолжается: стратегические условия завершения ещё не выполнены.","PLAIN DOWN",1]] remoteExec ["cutText",0];
        _deferEnd = true;
    };
};
if (_deferEnd) exitWith {};

missionNamespace setVariable ["DRO2026_missionEnding",true,true];

if (["taskStealth"] call BIS_fnc_taskExists) then {
    if !((["taskStealth"] call BIS_fnc_taskState) isEqualTo "FAILED") then {
        ["taskStealth","SUCCEEDED",true] call BIS_fnc_taskSetState;
        sleep 3;
    };
};
["taskExtract","SUCCEEDED",true] call BIS_fnc_taskSetState;

sleep 5;
[["", "BLACK OUT", 5]] remoteExec ["cutText", 0];
[5, 0] remoteExec ["fadeSound", 0];
[5, 0] remoteExec ["fadeSpeech", 0];
sleep 5;

diag_log "DRO: Ending MP mission";
private _successCount = 0;
private _failCount = 0;
{
    private _state = [_x] call BIS_fnc_taskState;
    diag_log format ["DRO: At end of mission task %1 is %2", _x, _state];
    switch (_state) do {
        case "SUCCEEDED": {_successCount = _successCount + 1};
        case "CANCELED": {_failCount = _failCount + 1};
        case "FAILED": {_failCount = _failCount + 1};
    };
} forEach taskIDs;

diag_log format ["DRO: At end of mission _successCount is %1", _successCount];
diag_log format ["DRO: At end of mission _failCount is %1", _failCount];
diag_log format ["DRO: At end of mission civDeathCounter is %1", civDeathCounter];

private _strategicOutcome = (missionNamespace getVariable ["DRO2026_endgameState",createHashMap]) getOrDefault ["outcome","PARTIAL_SUCCESS"];
if (civDeathCounter > 1) then {
    if (civDeathCounter == 2) then {
        if (isMultiplayer) then {"DROEnd_FailCiv1" call BIS_fnc_endMissionServer} else {"DROEnd_FailCiv1" call BIS_fnc_endMission};
    } else {
        if (isMultiplayer) then {"DROEnd_FailCiv2" call BIS_fnc_endMissionServer} else {"DROEnd_FailCiv2" call BIS_fnc_endMission};
    };
} else {
    if (_strategicOutcome == "FULL_SUCCESS" && {_successCount == count taskIDs}) then {
        if (isMultiplayer) then {"DROEnd_Full" call BIS_fnc_endMissionServer} else {"DROEnd_Full" call BIS_fnc_endMission};
    } else {
        if (_failCount == count taskIDs) then {
            if (isMultiplayer) then {"DROEnd_Fail" call BIS_fnc_endMissionServer} else {"DROEnd_Fail" call BIS_fnc_endMission};
        } else {
            if (isMultiplayer) then {"DROEnd_Partial" call BIS_fnc_endMissionServer} else {"DROEnd_Partial" call BIS_fnc_endMission};
        };
    };
};
