params [["_allowRepeat", false]];
if (!isServer) exitWith {"ISR_RECON"};
[] call DRO2026_fnc_evaluateOperationPhase;
private _phase = DRO2026_operationState getOrDefault ["phase", "RECON"];
private _candidates = [];

private _knownNode = {
    params ["_nodeId"];
    (DRO2026_contacts findIf {
        (_x getOrDefault ["owner", ""]) == "PLAYER" &&
        {(_x getOrDefault ["subjectId", ""]) == _nodeId} &&
        {(_x getOrDefault ["confidence", 0]) >= 0.42}
    }) >= 0
};
private _add = {
    params ["_type", "_nodeId", "_base", ["_reason", ""]];
    private _node = if (_nodeId == "") then {createHashMap} else {DRO2026_networkNodes getOrDefault [_nodeId, createHashMap]};
    private _status = _node getOrDefault ["status", "ACTIVE"];
    if (_nodeId != "" && {_status in ["DESTROYED", "DISABLED"]}) exitWith {};
    private _score = _base;
    if (_nodeId != "" && {[_nodeId] call _knownNode}) then {_score = _score + 0.28};
    if (!_allowRepeat && {_type in DRO2026_usedObjectiveTypes}) then {_score = _score - 0.38};
    switch _phase do {
        case "RECON": {if (_type == "ISR_RECON") then {_score = _score + 0.55} else {_score = _score - 0.18}};
        case "DISRUPTION": {if (_type in ["LOGISTICS_RUN", "CONVOY_INTERDICTION", "EW_HUNT", "DRONE_SITE"]) then {_score = _score + 0.22}};
        case "EXPLOITATION": {if (_type in ["ARTILLERY_HUNT", "AIR_DEFENCE", "LOGISTICS_HUB", "CUT_REAR"]) then {_score = _score + 0.25}};
        case "COUNTERATTACK": {if (_type in ["CUT_REAR", "ARTILLERY_HUNT", "UAV_TEAM"]) then {_score = _score + 0.30}};
    };
    _candidates pushBack createHashMapFromArray [
        ["type", _type], ["nodeId", _nodeId], ["score", _score max 0.01],
        ["reason", _reason], ["phase", _phase], ["createdAt", time]
    ];
};

["ISR_RECON", "", 0.38 + (1 - DRO2026_intelQuality), "Нарастить разведывательную картину"] call _add;
["LOGISTICS_HUB", "NODE_LOGISTICS_01", 0.62, "Нарушить источник снабжения"] call _add;
["ARTILLERY_HUNT", "NODE_ARTILLERY_01", 0.58, "Лишить противника огневой поддержки"] call _add;
["DRONE_SITE", "NODE_DRONE_REAR_01", 0.54, "Сорвать дальние беспилотные удары"] call _add;
["UAV_TEAM", "NODE_FPV_FORWARD_01", 0.57, "Подавить передовой беспилотный контур"] call _add;
["EW_HUNT", "NODE_EW_01", 0.56, "Открыть разведывательное окно"] call _add;
["AIR_DEFENCE", "NODE_AA_LONG_01", 0.52, "Создать permissive air window"] call _add;
["CUT_REAR", "NODE_ENEMY_HQ", 0.42, "Разорвать управление и резерв"] call _add;

private _openEdges = (keys DRO2026_networkEdges) select {
    private _edge = DRO2026_networkEdges get _x;
    (_edge getOrDefault ["status", "OPEN"]) == "OPEN"
};
if (count _openEdges > 0) then {
    ["LOGISTICS_RUN", "NODE_LOGISTICS_01", 0.60, "Перехватить конкретную поставку"] call _add;
    if (count DRO2026_activeConvoys < DRO2026_ACTIVE_CONVOY_LIMIT) then {
        ["CONVOY_INTERDICTION", "NODE_LOGISTICS_01", 0.64, "Перехватить материализованную supply lane"] call _add;
    };
};

if (count _candidates == 0) exitWith {"ISR_RECON"};
_candidates = [_candidates, [], {-(_x getOrDefault ["score", 0])}, "ASCEND"] call BIS_fnc_sortBy;
private _top = _candidates select [0, (count _candidates) min 4];
private _weights = _top apply {(_x getOrDefault ["score", 0.01]) max 0.01};
private _selected = [_top, _weights] call BIS_fnc_selectRandomWeighted;
DRO2026_operationState set ["activeOpportunities", _top];
["OPPORTUNITY_SELECTED", createHashMapFromArray [["type", _selected get "type"], ["nodeId", _selected get "nodeId"], ["score", _selected get "score"], ["phase", _phase]], "OPERATION"] call DRO2026_fnc_emitEvent;
_selected getOrDefault ["type", "ISR_RECON"]