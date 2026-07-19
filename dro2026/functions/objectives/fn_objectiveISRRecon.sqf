params ["_AOIndex"];
private _opportunity = missionNamespace getVariable ["DRO2026_selectedOpportunity", createHashMap];
private _nodeId = _opportunity getOrDefault ["nodeId", ""];
private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
if (count _node == 0) exitWith {""};

private _targetPosition = _node getOrDefault ["position", (AOLocations select _AOIndex) select 0];
private _nodeType = _node getOrDefault ["type", "STRATEGIC_SITE"];
private _axis = DRO2026_theaterNodes getOrDefault ["AXIS", random 360];
private _relayPosition = [_targetPosition, 550, 1250, (_axis + 180) mod 360, 65, false, 350] call DRO2026_fnc_findStrategicPosition;
private _uncertainty = 420 + random 280;
private _estimate = _targetPosition getPos [random _uncertainty, random 360];
private _taskName = format ["D26_ISR_%1", floor random 1000000];
private _marker = format ["D26_M_ISR_%1", floor random 1000000];
private _color = if (isNil "markerColorEnemy") then {"ColorOPFOR"} else {markerColorEnemy};

private _labels = createHashMapFromArray [
    ["STRATEGIC_DRONE_SITE", ["Вскрыть площадку дальних БПЛА", "Разведка фиксирует работу тылового беспилотного узла. Найдите его передовой relay, удерживайте наблюдение или уничтожьте оборудование, чтобы уточнить координаты пускового района."]],
    ["ARTILLERY_SITE", ["Выявить артиллерийский район", "Противник использует передовой корректировочный relay. Подтвердите его и получите координаты батареи для дальнейшего удара."]],
    ["LOGISTICS_HUB", ["Выявить тыловой склад", "Найдите узел связи диспетчеров снабжения. Наблюдение раскроет положение склада и связанные маршруты."]],
    ["EW_SITE", ["Локализовать источник РЭБ", "Найдите передовой ретранслятор комплекса РЭБ. Его излучение позволит сузить район основной станции."]],
    ["AA_LONG", ["Локализовать дальнюю ПВО", "Найдите разведывательный relay сети ПВО и подтвердите направление на радарный узел."]],
    ["FPV_TEAM", ["Найти передовой расчёт FPV", "В районе действует операторская группа FPV. Выявите антенну и пункт управления."]],
    ["HQ", ["Вскрыть командный пункт", "Найдите передовой узел связи штаба. Его захват или наблюдение раскроет район командования."]]
];
private _text = _labels getOrDefault [_nodeType, ["Уточнить стратегический объект", "Найдите физический разведывательный relay и подтвердите связанный тыловой объект противника."]];
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
private _vehicleFallback = if (enemySide == west) then {"B_Truck_01_box_F"} else {if (enemySide == resistance) then {"I_Truck_02_box_F"} else {"O_Truck_03_transport_F"}};
private _vehicleRole = if (enemySide == west) then {"LOGISTICS_WEST"} else {"LOGISTICS_EAST"};
private _vehicleClass = [_vehicleRole, _vehicleFallback] call DRO2026_fnc_getRoleClass;
private _controlVehicle = createVehicle [_vehicleClass, _relayPosition getPos [20, random 360], [], 0, "NONE"];
private _operatorFallback = switch (enemySide) do {case west: {"B_soldier_UAV_F"}; case resistance: {"I_soldier_UAV_F"}; default {"O_soldier_UAV_F"}};
private _officerRole = if (enemySide == west) then {"OFFICER_WEST"} else {"OFFICER_EAST"};
private _operatorClass = [_officerRole, _operatorFallback] call DRO2026_fnc_getRoleClass;
private _group = createGroup [enemySide, true];
private _operator = _group createUnit [_operatorClass, _relayPosition getPos [3, random 360], [], 0, "NONE"];
for "_index" from 1 to 2 do {
    private _guard = _group createUnit [_operatorClass, _relayPosition getPos [8 + random 10, random 360], [], 2, "FORM"];
    if (!isNull _guard) then {_guard setSkill 0.48 + random 0.12};
};
if (!isNull _operator) then {_operator setSkill 0.65};
if (count units _group > 0) then {
    [_group, false] call DRO2026_fnc_registerManagedGroup;
    _group setVariable ["DRO2026_static", true];
    _group setBehaviourStrong "AWARE";
    [_group, _relayPosition, 65] call BIS_fnc_taskDefend;
};

private _objects = [_antenna, _generator, _table, _controlVehicle] select {!isNull _x};
private _extra = createHashMapFromArray [["operator", _operator], ["group", _group], ["relatedNodeId", _nodeId], ["background", false]];
private _site = ["ISR_RELAY", _relayPosition, _antenna, _objects, _extra] call DRO2026_fnc_createSiteRecord;
if ([_site, false] call DRO2026_fnc_validateSiteRecord) then {DRO2026_sites pushBack _site};

private _meta = createHashMapFromArray [["type", "ISR_RECON"], ["position", _relayPosition], ["nodeId", _nodeId], ["targetPosition", _targetPosition]];
[_taskName, _desc, _title, _marker, "scout", _estimate, 0, [], _meta] call DRO2026_fnc_createObjectiveRecord;

[_taskName, _relayPosition, _targetPosition, _nodeId, _nodeType, _marker, _antenna, _operator, _objects, _group] spawn {
    params ["_task", "_relayPosition", "_targetPosition", "_nodeId", "_nodeType", "_marker", "_antenna", "_operator", "_objects", "_group"];
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    private _observed = 0;
    private _finished = false;
    while {
        !_finished &&
        {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0} &&
        {!(missionNamespace getVariable ["DRO2026_missionEnding", false])}
    } do {
        private _qualified = false;
        {
            private _observer = _x;
            if (alive _observer && {_observer distance2D _relayPosition < 850}) then {
                private _visibility = ([_observer, "VIEW"] checkVisibility [eyePos _observer, AGLToASL (_relayPosition vectorAdd [0,0,4])]);
                if (_visibility > 0.16) then {_qualified = true};
                private _uav = getConnectedUAV _observer;
                if (!isNull _uav && {_uav distance2D _relayPosition < 1200}) then {_qualified = true};
            };
        } forEach allPlayers;
        if (_qualified) then {_observed = _observed + 2} else {_observed = (_observed - 1) max 0};
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
    sleep 5;
    {if (!isNull _x) then {deleteVehicle _x}} forEach _objects;
    if (!isNull _group) then {
        {if (!isNull _x) then {deleteVehicle _x}} forEach units _group;
        deleteGroup _group;
    };
};
[] spawn {
    waitUntil {sleep 1; missionNamespace getVariable ["playersReady", 0] == 1 || {missionNamespace getVariable ["DRO2026_missionEnding", false]}};
    if !(missionNamespace getVariable ["DRO2026_missionEnding", false]) then {
        sleep 7;
        ["NEW_TASK", "Штаб: Найдите физический разведывательный relay. Он выведет нас на конкретный стратегический объект."] call DRO2026_fnc_hqVoice;
    };
};
_taskName
