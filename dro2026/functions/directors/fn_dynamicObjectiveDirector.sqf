if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_dynamicObjectiveDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_dynamicObjectiveDirectorStarted",true];
private _lastEventAt = -1;
private _createTask = {
    params ["_kind","_sourceId","_title","_description","_positionASL",["_uncertainty",250],["_contactId",""]];
    private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]];
    _tasks = _tasks select {!((_x getOrDefault ["state","CREATED"]) in ["SUCCEEDED","FAILED","CANCELED"])};
    if (count _tasks >= (missionNamespace getVariable ["DRO2026_MAX_DYNAMIC_TASKS",2])) exitWith {""};
    if ((_tasks findIf {(_x getOrDefault ["sourceId",""]) == _sourceId && {(_x getOrDefault ["kind",""]) == _kind}}) >= 0) exitWith {""};
    private _taskId = format ["D26_DYNAMIC_%1_%2",_kind,floor (diag_tickTime*1000)]; private _approx = +_positionASL;
    if (count _approx < 2) then {_approx = [worldSize/2,worldSize/2,0]}; if (_uncertainty > 25) then {_approx = _approx getPos [random _uncertainty,random 360]};
    [true,_taskId,[_description,_title,""],ASLToAGL _approx,"CREATED",2,true,"scout",true] call BIS_fnc_taskCreate;
    _tasks pushBack createHashMapFromArray [["schema",1],["id",_taskId],["kind",_kind],["sourceId",_sourceId],["contactId",_contactId],["state","CREATED"],["positionASL",+_positionASL],["uncertaintyRadius",_uncertainty max 0],["createdAt",time],["updatedAt",time]];
    missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true]; _taskId
};
while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _events = [_lastEventAt,["DELIVERY_MATERIALIZED","DELIVERY_COMPLETED","DELIVERY_INTERDICTED","DRONE_LAUNCHED","CONTACT_UPDATED"],100] call DRO2026_fnc_readEvents;
    _events = [_events,[],{_x getOrDefault ["createdAt",0]},"ASCEND"] call BIS_fnc_sortBy;
    {
        _lastEventAt = _lastEventAt max (_x getOrDefault ["createdAt",-1]); private _type = _x getOrDefault ["type",""]; private _sourceId = _x getOrDefault ["sourceId",""]; private _payload = _x getOrDefault ["payload",createHashMap];
        switch _type do {
            case "DELIVERY_MATERIALIZED": {private _p = _payload getOrDefault ["position",[]]; if (count _p > 1) then {["CONVOY",_sourceId,"Обнаружена колонна снабжения","Перехватите колонну до прибытия к потребителю.",AGLToASL _p,180,""] call _createTask}};
            case "DRONE_LAUNCHED": {private _p = _payload getOrDefault ["positionASL",[]]; if ((_payload getOrDefault ["role",""]) in ["LONG_RANGE","FPV"] && {_sourceId find "ENEMY" >= 0}) then {["INCOMING_UAV",_sourceId,"Перехватить ударный БПЛА","Зафиксирован вражеский запуск.",_p,650,_payload getOrDefault ["contactId",""]] call _createTask}};
            case "CONTACT_UPDATED": {private _confidence = _payload getOrDefault ["confidence",0]; private _subjectId = _payload getOrDefault ["subjectId",""]; if (_confidence >= 0.62 && {_subjectId != ""}) then {private _contactId = _payload getOrDefault ["contactId",""]; private _idx = DRO2026_contacts findIf {(_x getOrDefault ["id",""]) == _contactId}; if (_idx >= 0) then {private _c = DRO2026_contacts select _idx; private _p = _c getOrDefault ["positionASL",[]]; if (count _p > 1) then {["CONTACT",_subjectId,"Уточнить контакт","Маркер показывает вероятный район, а не точную позицию.",_p,_c getOrDefault ["uncertaintyRadius",1000],_contactId] call _createTask}}}};
            case "DELIVERY_INTERDICTED": {private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]]; {{if ((_x getOrDefault ["sourceId",""]) == _sourceId && {(_x getOrDefault ["kind",""]) == "CONVOY"}) then {[_x getOrDefault ["id", ""],"SUCCEEDED",true] spawn BIS_fnc_taskSetState; _x set ["state","SUCCEEDED"]}} forEach _tasks}; missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true]};
            case "DELIVERY_COMPLETED": {private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]]; {{if ((_x getOrDefault ["sourceId",""]) == _sourceId && {(_x getOrDefault ["kind",""]) == "CONVOY"}) then {[_x getOrDefault ["id", ""],"FAILED",true] spawn BIS_fnc_taskSetState; _x set ["state","FAILED"]}} forEach _tasks}; missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true]};
        };
    } forEach _events;
    private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]];
    {
        private _contactId = _x getOrDefault ["contactId",""];
        if (_contactId != "" && {!((_x getOrDefault ["state","CREATED"]) in ["SUCCEEDED","FAILED","CANCELED"])}) then {
            private _idx = DRO2026_contacts findIf {(_x getOrDefault ["id",""]) == _contactId};
            if (_idx >= 0) then {private _c = DRO2026_contacts select _idx; private _p = _c getOrDefault ["positionASL",[]]; private _u = _c getOrDefault ["uncertaintyRadius",1000]; if (count _p > 1) then {[_x getOrDefault ["id",""],ASLToAGL (_p getPos [random (_u max 30),random 360])] call BIS_fnc_taskSetDestination; _x set ["positionASL",+_p]; _x set ["uncertaintyRadius",_u]; _x set ["updatedAt",time]}};
        };
    } forEach _tasks;
    missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true]; sleep 30;
};
