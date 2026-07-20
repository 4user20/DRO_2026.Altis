params ["_AOIndex"];
private _opportunity = missionNamespace getVariable ["DRO2026_selectedOpportunity", createHashMap];
private _nodeId = _opportunity getOrDefault ["nodeId", ""];
private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
if (count _node == 0) exitWith {""};
private _targetPosition = _node getOrDefault ["position", (AOLocations select _AOIndex) select 0];
private _nodeType = _node getOrDefault ["type", "STRATEGIC_SITE"];
private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", random 360];
private _relayPosition = [_targetPosition, 550, 1250, (_axis + 180) mod 360, 65, false, 350] call DRO2026_fnc_findStrategicPosition;
if (_relayPosition isEqualTo [0,0,0]) exitWith {""};
private _uncertainty = 420 + random 280;
private _estimate = _targetPosition getPos [random _uncertainty, random 360];
private _taskName = format ["D26_ISR_%1", floor random 1000000];
private _marker = format ["D26_M_ISR_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};
private _labels = createHashMapFromArray [
    ["STRATEGIC_DRONE_SITE", ["Вскрыть площадку дальних БПЛА", "Найдите передовой relay тылового беспилотного узла и подтвердите район запуска."]],
    ["ARTILLERY_SITE", ["Выявить артиллерийский район", "Подтвердите передовой relay корректировщиков и уточните координаты батареи."]],
    ["LOGISTICS_HUB", ["Выявить тыловой склад", "Найдите узел связи диспетчеров снабжения и уточните положение склада."]],
    ["EW_SITE", ["Локализовать источник РЭБ", "Найдите передовой ретранслятор комплекса РЭБ."]],
    ["AA_LONG", ["Локализовать дальнюю ПВО", "Подтвердите relay сети ПВО и направление на радарный узел."]],
    ["FPV_TEAM", ["Найти передовой расчёт FPV", "Выявите антенну и пункт управления FPV-группы."]],
    ["HQ", ["Вскрыть командный пункт", "Найдите передовой узел связи штаба."]]
];
private _text = _labels getOrDefault [_nodeType, ["Уточнить стратегический объект", "Найдите физический разведывательный relay и подтвердите связанный тыловой объект."]];
_text params ["_title", "_desc"];
createMarker [_marker, _estimate];
_marker setMarkerShape "ELLIPSE";
_marker setMarkerSize [_uncertainty, _uncertainty];
_marker setMarkerBrush "Border";
_marker setMarkerColor _color;
_marker setMarkerAlpha 0.55;
_marker setMarkerText format [" %1", _title];

private _antenna = createVehicle ["Land_TTowerSmall_1_F", _relayPosition, [], 0, "CAN_COLLIDE"];
private _generator = createVehicle ["Land_PortableGenerator_01_F", _relayPosition getPos [8, 120], [], 0, "CAN_COLLIDE"];
private _table = createVehicle ["Land_CampingTable_small_F", _relayPosition getPos [5, 210], [], 0, "CAN_COLLIDE"];
private _suffix = [enemySide] call DRO2026_fnc_getSideSuffix;
private _vehicleFallback = switch (enemySide) do {case west: {"B_Truck_01_box_F"}; case resistance: {"I_Truck_02_box_F"}; default {"O_Truck_03_transport_F"}};
private _vehicleClass = [format ["LOGISTICS_%1", _suffix], _vehicleFallback, enemySide] call DRO2026_fnc_getSideRoleClass;
private _controlVehicle = if (_vehicleClass == "") then {objNull} else {createVehicle [_vehicleClass, _relayPosition getPos [20, random 360], [], 0, "NONE"]};
if (!isNull _controlVehicle) then {DRO2026_managedVehicles pushBackUnique _controlVehicle};
private _operatorFallback = switch (enemySide) do {case west: {"B_soldier_UAV_F"}; case resistance: {"I_soldier_UAV_F"}; default {"O_soldier_UAV_F"}};
private _enemySideNumber = [enemySide] call DRO2026_fnc_getSideNumber;
private _operatorPool = [];
if (!isNil "eOfficerClasses") then {_operatorPool append eOfficerClasses};
if (!isNil "eInfClasses") then {_operatorPool append eInfClasses};
_operatorPool = (_operatorPool arrayIntersect _operatorPool) select {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    isClass _cfg && {_x isKindOf "Man"} && {getNumber (_cfg >> "scope") >= 2} && {getNumber (_cfg >> "side") == _enemySideNumber}
};
private _operatorClass = if (count _operatorPool > 0) then {selectRandom _operatorPool} else {_operatorFallback};
private _group = createGroup [enemySide, true];
if (isNull _group) exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach [_antenna, _generator, _table, _controlVehicle];
    deleteMarker _marker;
    ""
};
private _operator = _group createUnit [_operatorClass, _relayPosition getPos [3, random 360], [], 0, "NONE"];
if (isNull _operator) exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach [_antenna, _generator, _table, _controlVehicle];
    deleteGroup _group;
    deleteMarker _marker;
    ""
};
for "_index" from 1 to 2 do {
    private _guardClass = if (count _operatorPool > 0) then {selectRandom _operatorPool} else {_operatorFallback};
    private _guard = _group createUnit [_guardClass, _relayPosition getPos [8 + random 10, random 360], [], 2, "FORM"];
    if (!isNull _guard) then {_guard setSkill 0.48 + random 0.12};
};
_operator setSkill 0.65;
[_group, false] call DRO2026_fnc_registerManagedGroup;
_group setVariable ["DRO2026_static", true];
_group setBehaviourStrong "AWARE";
[_group, _relayPosition, 65] call BIS_fnc_taskDefend;
private _objects = [_antenna, _generator, _table, _controlVehicle] select {!isNull _x};
private _critical = +_objects;
_critical pushBackUnique _operator;
private _extra = createHashMapFromArray [["operator", _operator], ["group", _group], ["relatedNodeId", _nodeId], ["background", false]];
private _site = ["ISR_RELAY", _relayPosition, _antenna, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if !([_site, false] call DRO2026_fnc_validateSiteRecord) exitWith {
    {if (!isNull _x) then {deleteVehicle _x}} forEach _objects;
    {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
    deleteGroup _group;
    deleteMarker _marker;
    ""
};
DRO2026_sites pushBack _site;
private _meta = createHashMapFromArray [
    ["type", "ISR_RECON"], ["position", _relayPosition], ["nodeId", _nodeId],
    ["targetPosition", _targetPosition], ["critical", _critical], ["siteId", _site get "id"]
];
[_taskName, _desc, _title, _marker, "scout", _estimate, 0, [], _meta] call DRO2026_fnc_createObjectiveRecord;
[_taskName, _relayPosition, _targetPosition, _nodeId, _nodeType, _marker, _antenna, _operator, _objects, _group, _site] spawn {
    params ["_task", "_relayPosition", "_targetPosition", "_nodeId", "_nodeType", "_marker", "_antenna", "_operator", "_objects", "_group", "_site"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    private _observed = 0;
    private _finished = false;
    while {!_finished && {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0} && {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}} do {
        private _qualified = false;
        {
            if (_x distance2D _relayPosition < 850) then {
                if (([_x, "VIEW"] checkVisibility [eyePos _x, AGLToASL (_relayPosition vectorAdd [0,0,4])]) > 0.16) then {_qualified = true};
                private _uav = getConnectedUAV _x;
                if (!isNull _uav && {_uav distance2D _relayPosition < 1200}) then {_qualified = true};
            };
        } forEach (allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}});
        _observed = if (_qualified) then {_observed + 2} else {(_observed - 1) max 0};
        private _relayDestroyed = (isNull _antenna || {!alive _antenna}) && {(isNull _operator || {!alive _operator})};
        if (_observed >= 60 || {_relayDestroyed}) then {
            private _confidence = if (_observed >= 60) then {0.91} else {0.76};
            private _finalUncertainty = if (_observed >= 60) then {90} else {240};
            ["PLAYER", objNull, _targetPosition, _confidence, _nodeType, "ISR_RELAY", _finalUncertainty, _nodeId, 0.02] call DRO2026_fnc_addContact;
            private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
            if (count _node > 0) then {
                _node set ["knownByPlayer", if (_confidence > 0.85) then {"CONFIRMED"} else {"TRACKED"}];
                _node set ["lastUpdatedAt", time];
                DRO2026_networkNodes set [_nodeId, _node];
            };
            DRO2026_intelQuality = (DRO2026_intelQuality + 0.22) min 1;
            _marker setMarkerPos _targetPosition;
            _marker setMarkerSize [_finalUncertainty, _finalUncertainty];
            [_task, "TASK_COMPLETE", []] call DRO2026_fnc_completeObjective;
            ["NODE_RECON_CONFIRMED", createHashMapFromArray [["nodeId", _nodeId], ["confidence", _confidence], ["uncertainty", _finalUncertainty]], _nodeId] call DRO2026_fnc_emitEvent;
            _finished = true;
        };
        sleep 2;
    };
    if (missionNamespace getVariable ["DRO2026_missionEnding", false]) then {
        _site set ["status", "CANCELLED"];
        _site set ["physicalState", "DISABLED"];
        _site set ["disabledAt", time];
    };
    sleep 5;
    {if (!isNull _x) then {deleteVehicle _x}} forEach _objects;
    {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
    if (!isNull _group) then {deleteGroup _group};
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {sleep 7; ["NEW_TASK", "Штаб: Найдите физический разведывательный relay. Он выведет нас на конкретный стратегический объект."] call DRO2026_fnc_hqVoice};
};
_taskName
