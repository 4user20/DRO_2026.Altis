/* Rare Nemotron-class policy requests. No direct world execution. */
if (!isServer) exitWith {};
private _lastRequest=-999;
private _lastMajorEventId="";
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _mode=toUpperANSI (missionNamespace getVariable ["DRO2026_AI_MODE","OFF"]);
    private _ready=missionNamespace getVariable ["DRO2026_aiTransportReady",false];
    private _online=missionNamespace getVariable ["DRO2026_aiBridgeOnline",false];
    private _pending=missionNamespace getVariable ["DRO2026_aiPendingStrategicSequence",-1];
    if (_pending >= 0 && {(time-(missionNamespace getVariable ["DRO2026_aiPendingStrategicAt",time]))>90}) then {
        ["AI_TIMEOUT",createHashMapFromArray [["jobType","STRATEGIC_POLICY"],["sequence",_pending]],"AI"] call DRO2026_fnc_emitEvent;
        missionNamespace setVariable ["DRO2026_aiPendingStrategicSequence",-1];
        missionNamespace setVariable ["DRO2026_aiPendingStrategicAt",-1];
        _pending=-1;
    };
    private _major="";
    for "_i" from ((count DRO2026_eventLog)-1) to 0 step -1 do {
        private _event=DRO2026_eventLog select _i;
        if ((_event getOrDefault ["type",""]) in ["PHASE_CHANGED","NETWORK_NODE_DESTROYED","SITE_DESTROYED","DELIVERY_INTERDICTED"]) exitWith {_major=_event getOrDefault ["id",""]};
    };
    private _majorChanged=_major != "" && {_major != _lastMajorEventId};
    if (_mode in ["OBSERVE","HYBRID"] && {_ready && _online} && {_pending < 0} && {((time-_lastRequest)>(missionNamespace getVariable ["DRO2026_AI_STRATEGIC_INTERVAL",300]) || _majorChanged)}) then {
        private _sequence=(missionNamespace getVariable ["DRO2026_aiSequence",0])+1;
        missionNamespace setVariable ["DRO2026_aiSequence",_sequence];
        missionNamespace setVariable ["DRO2026_aiPendingStrategicSequence",_sequence];
        missionNamespace setVariable ["DRO2026_aiPendingStrategicAt",time];
        ["snapshot",["STRATEGIC_POLICY",_sequence,[]] call DRO2026_fnc_buildAISnapshot] call DRO2026_fnc_writeAIRequest;
        ["AI_JOB_SUBMITTED",createHashMapFromArray [["jobType","STRATEGIC_POLICY"],["sequence",_sequence],["trigger",if (_majorChanged) then {"MAJOR_EVENT"} else {"INTERVAL"}]],"AI"] call DRO2026_fnc_emitEvent;
        _lastRequest=time; if (_majorChanged) then {_lastMajorEventId=_major};
    };
    sleep 10;
};
