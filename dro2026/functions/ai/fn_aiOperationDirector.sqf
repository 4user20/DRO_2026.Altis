/* Replace the old operationDirector spawn with this function. Do not run both. */
if (!isServer) exitWith {};
private _lastIntentAt = -999;
private _lastSyncAt = -999;
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    if ((time-_lastSyncAt)>6) then {[] call DRO2026_fnc_syncNetworkState; [] call DRO2026_fnc_evaluateOperationPhase; _lastSyncAt=time};
    private _current = missionNamespace getVariable ["DRO2026_currentIntent",createHashMap];
    private _status = _current getOrDefault ["status",""];
    if (count _current > 0 && {_status in ["EXECUTED","CANCELLED"] || {time > (_current getOrDefault ["expiresAt",-1])}}) then {
        missionNamespace setVariable ["DRO2026_currentIntent",createHashMap]; _current=createHashMap;
    };

    if (count _current == 0) then {
        private _pendingSequence = missionNamespace getVariable ["DRO2026_aiPendingSequence",-1];
        if (_pendingSequence >= 0) then {
            private _pendingCandidates = missionNamespace getVariable ["DRO2026_aiPendingCandidates",[]];
            private _latest = missionNamespace getVariable ["DRO2026_aiLatestDecision",[]];
            private _resolved = false;
            if (_latest isEqualType [] && {count _latest >= 2} && {(_latest param [1,-2]) == _pendingSequence}) then {
                private _validated = [_latest,_pendingSequence,_pendingCandidates] call DRO2026_fnc_validateAIDecision;
                if (_validated getOrDefault ["valid",false]) then {
                    private _decision = _validated getOrDefault ["decision","USE_DETERMINISTIC"];
                    if (_decision == "EXECUTE") then {
                        [_validated get "candidate",_validated,"LLM"] call DRO2026_fnc_commitIntent;
                    } else {
                        if (_decision == "HOLD") then {
                            missionNamespace setVariable ["DRO2026_aiHoldUntil",time+(_validated getOrDefault ["holdSeconds",30])];
                            ["AI_HOLD_APPLIED",createHashMapFromArray [["seconds",_validated getOrDefault ["holdSeconds",30]],["reasonCode",_validated getOrDefault ["reasonCode",""]]],"AI"] call DRO2026_fnc_emitEvent;
                        } else {
                            if (count _pendingCandidates > 0) then {
                                private _ranked=[_pendingCandidates,[],{-(_x getOrDefault ["utility",0])},"ASCEND"] call BIS_fnc_sortBy;
                                [_ranked select 0,createHashMap,"DETERMINISTIC_LLM_REQUEST"] call DRO2026_fnc_commitIntent;
                            };
                        };
                    };
                } else {
                    if (count _pendingCandidates > 0) then {
                        private _ranked=[_pendingCandidates,[],{-(_x getOrDefault ["utility",0])},"ASCEND"] call BIS_fnc_sortBy;
                        [_ranked select 0,createHashMap,"DETERMINISTIC_INVALID_AI"] call DRO2026_fnc_commitIntent;
                    };
                };
                _resolved=true;
            };
            private _requestedAt = missionNamespace getVariable ["DRO2026_aiPendingAt",time];
            if (!_resolved && {(time-_requestedAt)>(missionNamespace getVariable ["DRO2026_AI_TACTICAL_TIMEOUT",18])}) then {
                if (count _pendingCandidates > 0) then {
                    private _ranked=[_pendingCandidates,[],{-(_x getOrDefault ["utility",0])},"ASCEND"] call BIS_fnc_sortBy;
                    [_ranked select 0,createHashMap,"DETERMINISTIC_AI_TIMEOUT"] call DRO2026_fnc_commitIntent;
                };
                ["AI_TIMEOUT",createHashMapFromArray [["sequence",_pendingSequence]],"AI"] call DRO2026_fnc_emitEvent;
                _resolved=true;
            };
            if (_resolved) then {
                missionNamespace setVariable ["DRO2026_aiPendingSequence",-1];
                missionNamespace setVariable ["DRO2026_aiPendingCandidates",[]];
                missionNamespace setVariable ["DRO2026_aiLatestDecision",[]];
                _lastIntentAt=time;
            };
        };

        private _pendingNow = missionNamespace getVariable ["DRO2026_aiPendingSequence",-1];
        private _holdUntil = missionNamespace getVariable ["DRO2026_aiHoldUntil",-1];
        if (_pendingNow < 0 && {time >= _holdUntil} && {(time-_lastIntentAt)>18}) then {
            private _sequence=(missionNamespace getVariable ["DRO2026_aiSequence",0])+1;
            missionNamespace setVariable ["DRO2026_aiSequence",_sequence];
            private _candidates=[_sequence] call DRO2026_fnc_buildIntentCandidates;
            if (count _candidates > 0) then {
                private _ranked=[_candidates,[],{-(_x getOrDefault ["utility",0])},"ASCEND"] call BIS_fnc_sortBy;
                private _mode=toUpperANSI (missionNamespace getVariable ["DRO2026_AI_MODE","OFF"]);
                private _ready=missionNamespace getVariable ["DRO2026_aiTransportReady",false];
                private _online=missionNamespace getVariable ["DRO2026_aiBridgeOnline",false];
                if (_mode == "OBSERVE") then {
                    if (_ready) then {["snapshot",["TACTICAL_INTENT",_sequence,_candidates] call DRO2026_fnc_buildAISnapshot] call DRO2026_fnc_writeAIRequest};
                    [_ranked select 0,createHashMap,"DETERMINISTIC_OBSERVE"] call DRO2026_fnc_commitIntent;
                    _lastIntentAt=time;
                } else {
                    if (_mode == "HYBRID" && {_ready && _online}) then {
                        missionNamespace setVariable ["DRO2026_aiLatestDecision",[]];
                        missionNamespace setVariable ["DRO2026_aiPendingSequence",_sequence];
                        missionNamespace setVariable ["DRO2026_aiPendingCandidates",_candidates];
                        missionNamespace setVariable ["DRO2026_aiPendingAt",time];
                        ["snapshot",["TACTICAL_INTENT",_sequence,_candidates] call DRO2026_fnc_buildAISnapshot] call DRO2026_fnc_writeAIRequest;
                        ["AI_JOB_SUBMITTED",createHashMapFromArray [["sequence",_sequence],["candidateCount",count _candidates]],"AI"] call DRO2026_fnc_emitEvent;
                    } else {
                        [_ranked select 0,createHashMap,"DETERMINISTIC_OFFLINE"] call DRO2026_fnc_commitIntent;
                        _lastIntentAt=time;
                    };
                };
            };
        };
    };
    sleep 1;
};
