params ["_data", "_expectedSequence", "_candidates"];
private _result = createHashMapFromArray [["valid",false],["reason","INVALID_SHAPE"]];
if !(_data isEqualType []) exitWith {_result};
if (count _data < 12) exitWith {_result};
if ((_data param [0,"",[""]]) != "TACTICAL_INTENT") exitWith {_result};
if ((_data param [1,-1,[0]]) != _expectedSequence) exitWith {_result set ["reason","STALE_SEQUENCE"]; _result};
if ((_data param [2,"",[""]]) != "READY") exitWith {_result set ["reason","NOT_READY"]; _result};
private _decision = toUpperANSI (_data param [4,"",[""]]);
if !(_decision in ["EXECUTE","HOLD","USE_DETERMINISTIC"]) exitWith {_result set ["reason","UNKNOWN_DECISION"]; _result};
private _candidateId = _data param [3,"",[""]];
private _candidate = createHashMap;
if (_decision == "EXECUTE") then {
    private _index = _candidates findIf {(_x getOrDefault ["id",""]) == _candidateId};
    if (_index < 0) exitWith {_result set ["reason","UNKNOWN_CANDIDATE"]};
    _candidate = _candidates select _index;
};
if ((_result getOrDefault ["reason",""]) == "UNKNOWN_CANDIDATE") exitWith {_result};
_result set ["valid",true];
_result set ["reason","OK"];
_result set ["decision",_decision];
_result set ["candidate",_candidate];
_result set ["delaySeconds",((_data param [5,5,[0]]) max 0) min 30];
_result set ["tempoModifier",((_data param [6,1,[0]]) max 0.7) min 1.3];
_result set ["salvoCount",round (((_data param [7,1,[0]]) max 1) min 3)];
_result set ["relocateAfter",_data param [8,false,[true]]];
_result set ["searchRadius",((_data param [9,900,[0]]) max 300) min 2500];
_result set ["holdSeconds",((_data param [10,30,[0]]) max 15) min 90];
_result set ["reasonCode",(_data param [11,"NO_REASON",[""]]) select [0,80]];
_result
