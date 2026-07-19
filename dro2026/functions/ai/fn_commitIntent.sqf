params ["_candidate", ["_decision",createHashMap], ["_source","DETERMINISTIC"]];
if (!isServer || {count _candidate == 0}) exitWith {createHashMap};
private _candidateId=_candidate getOrDefault ["id",""];
private _intent = createHashMap;
{_intent set [_x,_candidate get _x]} forEach (keys _candidate);
_intent set ["candidateId",_candidateId];
private _tempoModifier=(_decision getOrDefault ["tempoModifier",1]) max 0.7 min 1.3;
private _delay = (_decision getOrDefault ["delaySeconds",5 + random 12]) / _tempoModifier;
_intent set ["id",format ["INTENT_%1_%2",floor diag_tickTime,floor random 1000000]];
_intent set ["earliestAt",time + ((_delay max 0) min 30)];
_intent set ["expiresAt",time + 110];
_intent set ["status","PROPOSED"];
_intent set ["selectionSource",_source];
_intent set ["aiReasonCode",_decision getOrDefault ["reasonCode",""]];
_intent set ["aiTempoModifier",_tempoModifier];
_intent set ["aiModifiers",createHashMapFromArray [
    ["salvoCount",_decision getOrDefault ["salvoCount",1]],
    ["relocateAfter",_decision getOrDefault ["relocateAfter",false]],
    ["searchRadius",_decision getOrDefault ["searchRadius",900]]
]];
DRO2026_actionIntents pushBack _intent;
if (count DRO2026_actionIntents > 80) then {DRO2026_actionIntents deleteRange [0,(count DRO2026_actionIntents)-80]};
missionNamespace setVariable ["DRO2026_currentIntent",_intent];
["INTENT_PROPOSED",createHashMapFromArray [
    ["intentId",_intent get "id"],["action",_intent getOrDefault ["action",""]],["actor",_intent getOrDefault ["actor",""]],
    ["utility",_intent getOrDefault ["utility",0]],["selectionSource",_source],["reasonCode",_intent getOrDefault ["aiReasonCode",""]]
],"OPERATION"] call DRO2026_fnc_emitEvent;
if (_source == "LLM") then {
    ["AI_DECISION_ACCEPTED",createHashMapFromArray [["intentId",_intent get "id"],["candidateId",_intent getOrDefault ["candidateId",""]],["reasonCode",_intent getOrDefault ["aiReasonCode",""]]],"AI"] call DRO2026_fnc_emitEvent;
};
if ((_source find "DETERMINISTIC_AI_") == 0 || {_source == "DETERMINISTIC_OFFLINE"}) then {
    ["AI_FALLBACK_USED",createHashMapFromArray [["source",_source],["action",_intent getOrDefault ["action",""]]],"AI"] call DRO2026_fnc_emitEvent;
};
_intent
