if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_dynamicObjectiveDirectorStarted",false]) exitWith {};
missionNamespace setVariable ["DRO2026_dynamicObjectiveDirectorStarted",true];
private _lastEventAt = -1;
private _createTask = {
    params ["_kind","_sourceId","_title","_description","_positionASL",["_uncertainty",250],["_contactId",""],["_icon","scout"]];
    private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]];
    _tasks = _tasks select {!((toUpperANSI (_x getOrDefault ["state","CREATED"])) in ["SUCCEEDED","FAILED","CANCELED","CANCELLED"])};
    if (count _tasks >= (missionNamespace getVariable ["DRO2026_MAX_DYNAMIC_TASKS",2])) exitWith {""};
    if ((_tasks findIf {(_x getOrDefault ["sourceId",""]) == _sourceId && {(_x getOrDefault ["kind",""]) == _kind}}) >= 0) exitWith {""};
    private _taskId = format ["D26_DYNAMIC_%1_%2",_kind,floor (diag_tickTime*1000)];
    private _approx = +_positionASL;
    if (count _approx < 2) then {_approx = [worldSize/2,worldSize/2,0]};
    if (_uncertainty > 25) then {_approx = _approx getPos [random _uncertainty,random 360]};
    [true,_taskId,[_description,_title,""],ASLToAGL _approx,"CREATED",2,true,_icon,true] call BIS_fnc_taskCreate;
    _tasks pushBack createHashMapFromArray [
        ["schema",2],["id",_taskId],["kind",_kind],["sourceId",_sourceId],["contactId",_contactId],
        ["state","CREATED"],["positionASL",+_positionASL],["uncertaintyRadius",_uncertainty max 0],
        ["createdAt",time],["updatedAt",time]
    ];
    missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true];
    ["NEW_TASK"] call DRO2026_fnc_hqVoice;
    _taskId
};
private _completeTasks = {
    params ["_sourceId","_kind","_state"];
    private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]];
    {
        if ((_x getOrDefault ["sourceId",""]) == _sourceId && {(_kind == "") || {(_x getOrDefault ["kind",""]) == _kind}} && {!((toUpperANSI (_x getOrDefault ["state","CREATED"])) in ["SUCCEEDED","FAILED","CANCELED","CANCELLED"])}) then {
            [_x getOrDefault ["id",""],_state,true] spawn BIS_fnc_taskSetState;
            _x set ["state",_state];
            _x set ["updatedAt",time];
        };
    } forEach _tasks;
    missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true];
};
private _profileForNode = {
    params ["_nodeId"];
    private _node = DRO2026_networkNodes getOrDefault [_nodeId,createHashMap];
    private _type = toUpperANSI (_node getOrDefault ["type","UNKNOWN"]);
    switch _type do {
        case "HQ": {["HQ_HUNT","Нарушить управление противника","Уничтожьте командный пункт. Потеря штаба замедлит поиск целей, выдачу приказов и диспетчеризацию резервов.","destroy"]};
        case "LOGISTICS_HUB": {["DEPOT_HUNT","Уничтожить склад снабжения","Уничтожьте складские объекты и диспетчерский узел. Это сократит запасы ракет, БПЛА, артиллерийских боеприпасов и остановит часть колонн.","destroy"]};
        case "BALLISTIC_MISSILE_SITE": {["OTRK_HUNT","Найти и уничтожить ОТРК","Разведка обнаружила вероятный район Искандера. Уничтожьте пусковую, узел управления или запас ракет до следующего пуска.","destroy"]};
        case "AA_LONG": {["AA_HUNT","Подавить дальнюю ПВО","Уничтожьте радар, пусковые или командную связь батареи. Это откроет воздушное окно и снизит вероятность перехвата наших ракет.","destroy"]};
        case "AA_SHORAD": {["SHORAD_HUNT","Подавить ближнюю ПВО","Уничтожьте мобильную огневую группу, прикрывающую узел от БПЛА и низколетящих целей.","destroy"]};
        case "ARTILLERY_SITE": {["ARTILLERY_HUNT","Подавить артиллерию","Уничтожьте орудия или перехватите боеприпасы. Без снабжения батарея прекратит огонь.","destroy"]};
        case "FARP": {["FARP_HUNT","Вывести из строя FARP","Уничтожьте топливный, ремонтный и диспетчерский компоненты площадки. Это остановит часть вертолётных вылетов.","destroy"]};
        case "STRATEGIC_DRONE_SITE": {["DRONE_SITE_HUNT","Уничтожить площадку дальних БПЛА","Уничтожьте операторов, антенны, пусковые и склад аппаратов.","destroy"]};
        default {["CONTACT","Уточнить стратегический контакт","Проведите разведку района и подтвердите состав цели перед вызовом тяжёлого удара.","scout"]};
    }
};

while {!(missionNamespace getVariable ["DRO2026_missionEnding",false])} do {
    private _events = [_lastEventAt,[
        "DELIVERY_MATERIALIZED","DELIVERY_COMPLETED","DELIVERY_INTERDICTED","DRONE_LAUNCHED","CONTACT_UPDATED",
        "STRATEGIC_MUNITION_DETECTED","STRATEGIC_STRIKE_ORDERED","STRATEGIC_MUNITION_INTERCEPTED",
        "STRATEGIC_IMPACT_RESOLVED","NETWORK_NODE_DESTROYED","NETWORK_NODE_DISABLED","AIR_MISSION_STATE_CHANGED"
    ],160] call DRO2026_fnc_readEvents;
    _events = [_events,[],{_x getOrDefault ["createdAt",0]},"ASCEND"] call BIS_fnc_sortBy;
    {
        _lastEventAt = _lastEventAt max (_x getOrDefault ["createdAt",-1]);
        private _type = _x getOrDefault ["type",""];
        private _sourceId = _x getOrDefault ["sourceId",""];
        private _payload = _x getOrDefault ["payload",createHashMap];
        switch _type do {
            case "DELIVERY_MATERIALIZED": {
                private _p = _payload getOrDefault ["position",[]];
                if (count _p > 1) then {
                    ["CONVOY",_sourceId,"Перехватить колонну снабжения",format ["Колонна перевозит %1 к узлу-потребителю. Уничтожьте грузовые машины до разгрузки.",_payload getOrDefault ["cargoType","ресурсы"]],[_p,"ATL",objNull] call DRO2026_fnc_normalizePositionASL,180,"","destroy"] call _createTask
                };
            };
            case "DRONE_LAUNCHED": {
                private _p = _payload getOrDefault ["positionASL",[]];
                if ((_payload getOrDefault ["role",""]) in ["LONG_RANGE","FPV"] && {(_sourceId find "ENEMY") >= 0}) then {
                    ["INCOMING_UAV",_sourceId,"Перехватить ударный БПЛА","Зафиксирован вражеский запуск. ПВО и мобильные огневые группы попытаются перехватить аппарат.",_p,650,_payload getOrDefault ["contactId",""],"interact"] call _createTask
                };
            };
            case "STRATEGIC_MUNITION_DETECTED": {
                private _defender = _payload getOrDefault ["defender",""];
                if (_defender == str playersSide) then {
                    private _munitionId = _payload getOrDefault ["munitionId",_sourceId];
                    private _registry = missionNamespace getVariable ["DRO2026_activeStrategicMunitions",[]];
                    private _index = _registry findIf {(_x getOrDefault ["id",""]) == _munitionId};
                    private _munitionObject = if (_index >= 0) then {(_registry select _index) getOrDefault ["object",objNull]} else {objNull};
                    private _p = if (!isNull _munitionObject) then {getPosASL _munitionObject} else {[]};
                    ["INCOMING_MISSILE",_munitionId,"Отразить ракетный удар",format ["Обнаружена цель профиля %1. Не покидайте укрытия; дальняя ПВО выполняет ограниченное число попыток перехвата.",_payload getOrDefault ["profile","UNKNOWN"]],_p,900,"","interact"] call _createTask;
                };
            };
            case "STRATEGIC_STRIKE_ORDERED": {
                private _actor = _payload getOrDefault ["actor",_sourceId];
                private _node = DRO2026_networkNodes getOrDefault [_actor,createHashMap];
                private _p = [_node getOrDefault ["position",[]],"ATL",objNull] call DRO2026_fnc_normalizePositionASL;
                ["OTRK_HUNT",_actor,"Найти и уничтожить ОТРК","Подтверждён пуск баллистической ракеты. Используйте контрбатарейную разведку и БПЛА, чтобы уничтожить ОТРК до повторного пуска.",_p,850,"","destroy"] call _createTask;
            };
            case "CONTACT_UPDATED": {
                private _confidence = _payload getOrDefault ["confidence",0];
                private _subjectId = _payload getOrDefault ["subjectId",""];
                if (_confidence >= 0.62 && {_subjectId != ""}) then {
                    private _contactId = _payload getOrDefault ["contactId",""];
                    private _idx = DRO2026_contacts findIf {(_x getOrDefault ["id",""]) == _contactId && {(_x getOrDefault ["owner",""]) == "PLAYER"}};
                    if (_idx >= 0) then {
                        private _contact = DRO2026_contacts select _idx;
                        private _p = _contact getOrDefault ["positionASL",[]];
                        if (count _p > 1) then {
                            private _profile = [_subjectId] call _profileForNode;
                            _profile params ["_kind","_title","_description","_icon"];
                            [_kind,_subjectId,_title,_description,_p,_contact getOrDefault ["uncertaintyRadius",1000],_contactId,_icon] call _createTask;
                        };
                    };
                };
            };
            case "DELIVERY_INTERDICTED": {[_sourceId,"CONVOY","SUCCEEDED"] call _completeTasks};
            case "DELIVERY_COMPLETED": {[_sourceId,"CONVOY","FAILED"] call _completeTasks};
            case "STRATEGIC_MUNITION_INTERCEPTED": {[_payload getOrDefault ["munitionId",_sourceId],"INCOMING_MISSILE","SUCCEEDED"] call _completeTasks};
            case "STRATEGIC_IMPACT_RESOLVED": {
                private _munitionId = _payload getOrDefault ["munitionId",_sourceId];
                [_munitionId,"INCOMING_MISSILE","FAILED"] call _completeTasks;
            };
            case "NETWORK_NODE_DESTROYED": {
                private _nodeId = _payload getOrDefault ["nodeId",_sourceId];
                [_nodeId,"","SUCCEEDED"] call _completeTasks;
            };
            case "NETWORK_NODE_DISABLED": {
                private _nodeId = _payload getOrDefault ["nodeId",_sourceId];
                [_nodeId,"","SUCCEEDED"] call _completeTasks;
            };
        };
    } forEach _events;

    private _tasks = missionNamespace getVariable ["DRO2026_dynamicTasks",[]];
    {
        private _contactId = _x getOrDefault ["contactId",""];
        if (_contactId != "" && {!((toUpperANSI (_x getOrDefault ["state","CREATED"])) in ["SUCCEEDED","FAILED","CANCELED","CANCELLED"])}) then {
            private _index = DRO2026_contacts findIf {(_x getOrDefault ["id",""]) == _contactId};
            if (_index >= 0) then {
                private _contact = DRO2026_contacts select _index;
                private _p = _contact getOrDefault ["positionASL",[]];
                private _uncertainty = _contact getOrDefault ["uncertaintyRadius",1000];
                if (count _p > 1) then {
                    [_x getOrDefault ["id",""],ASLToAGL (_p getPos [random (_uncertainty max 30),random 360])] call BIS_fnc_taskSetDestination;
                    _x set ["positionASL",+_p];
                    _x set ["uncertaintyRadius",_uncertainty];
                    _x set ["updatedAt",time];
                };
            };
        };
    } forEach _tasks;
    missionNamespace setVariable ["DRO2026_dynamicTasks",_tasks,true];
    sleep 20;
};