/*
    Server-side black-box telemetry for DRO-owned state only.
    No EachFrame handler and no global allVehicles scan are used.
*/
if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_telemetryStarted", false]) exitWith {};
missionNamespace setVariable ["DRO2026_telemetryStarted", true];

private _modeRank = {
    private _modeValue = missionNamespace getVariable ["DRO2026_TELEMETRY_MODE", "BASIC"];
    if (_modeValue isEqualType 0) exitWith {((round _modeValue) max 0) min 3};
    switch (if (_modeValue isEqualType "") then {toUpperANSI _modeValue} else {"BASIC"}) do {
        case "OFF": {0}; case "BASIC": {1}; case "VERBOSE": {2}; case "TRACE": {3}; default {1};
    }
};

["TELEMETRY", "STARTED", createHashMapFromArray [
    ["mode", missionNamespace getVariable ["DRO2026_TELEMETRY_MODE", "BASIC"]],
    ["interval", missionNamespace getVariable ["DRO2026_TELEMETRY_INTERVAL", 10]],
    ["worldSnapshotInterval", missionNamespace getVariable ["DRO2026_TELEMETRY_WORLD_INTERVAL", 60]],
    ["positionBucket", missionNamespace getVariable ["DRO2026_TELEMETRY_POSITION_BUCKET", 500]],
    ["version", missionNamespace getVariable ["DRO2026_VERSION", "UNKNOWN"]]
], 1, "START", 0] call DRO2026_fnc_telemetryRecord;

private _handlers = [];
_handlers pushBack ["EntityKilled", addMissionEventHandler ["EntityKilled", {
    params ["_killed", "_killer", "_instigator"];
    if ([_killed] call DRO2026_fnc_isTelemetryOwnedObject) then {
        private _snapshot = [_killed, 250, true] call DRO2026_fnc_telemetryObjectSnapshot;
        _snapshot set ["killer", if (isNull _killer) then {""} else {netId _killer}];
        _snapshot set ["killerClass", if (isNull _killer) then {""} else {typeOf _killer}];
        _snapshot set ["instigator", if (isNull _instigator) then {""} else {netId _instigator}];
        ["ENTITY", "KILLED", _snapshot, 1, netId _killed, 0] call DRO2026_fnc_telemetryRecord;
    };
}]];
_handlers pushBack ["EntityDeleted", addMissionEventHandler ["EntityDeleted", {
    params ["_entity"];
    if ([_entity] call DRO2026_fnc_isTelemetryOwnedObject) then {
        ["ENTITY", "DELETED", createHashMapFromArray [
            ["class", typeOf _entity], ["netId", netId _entity],
            ["positionASL", getPosASL _entity]
        ], 1, netId _entity, 0] call DRO2026_fnc_telemetryRecord;
    };
}]];
_handlers pushBack ["PlayerConnected", addMissionEventHandler ["PlayerConnected", {
    ["MP", "PLAYER_CONNECTED", createHashMapFromArray [["args", str _this]], 1, "CONNECTION", 0] call DRO2026_fnc_telemetryRecord;
}]];
_handlers pushBack ["PlayerDisconnected", addMissionEventHandler ["PlayerDisconnected", {
    ["MP", "PLAYER_DISCONNECTED", createHashMapFromArray [["args", str _this]], 1, "CONNECTION", 0] call DRO2026_fnc_telemetryRecord;
}]];
_handlers pushBack ["HandleDisconnect", addMissionEventHandler ["HandleDisconnect", {
    ["MP", "HANDLE_DISCONNECT", createHashMapFromArray [["args", str _this]], 1, "DISCONNECT", 0] call DRO2026_fnc_telemetryRecord;
    false
}]];
_handlers pushBack ["Ended", addMissionEventHandler ["Ended", {
    ["MISSION", "ENDED", createHashMapFromArray [["args", str _this]], 1, "END", 0] call DRO2026_fnc_telemetryRecord;
}]];
_handlers pushBack ["MPEnded", addMissionEventHandler ["MPEnded", {
    ["MISSION", "MP_ENDED", createHashMapFromArray [["args", str _this]], 1, "MP_END", 0] call DRO2026_fnc_telemetryRecord;
}]];
missionNamespace setVariable ["DRO2026_telemetryMissionHandlers", _handlers];

private _lastWorldAt = -9999;
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _rank = call _modeRank;
    private _interval = missionNamespace getVariable ["DRO2026_TELEMETRY_INTERVAL", 10];
    _interval = (_interval max 5) min 60;
    private _worldInterval = missionNamespace getVariable ["DRO2026_TELEMETRY_WORLD_INTERVAL", 60];
    _worldInterval = (_worldInterval max 20) min 300;

    if (_rank >= 1 && {(time - _lastWorldAt) >= _worldInterval}) then {
        _lastWorldAt = time;
        private _eventCounts = missionNamespace getVariable ["DRO2026_telemetryEventIntervalCounts", createHashMap];
        private _stats = missionNamespace getVariable ["DRO2026_telemetryStats", createHashMap];
        ["WORLD", "SNAPSHOT", createHashMapFromArray [
            ["fps", floor (diag_fps * 10) / 10], ["fpsMin", floor (diag_fpsMin * 10) / 10],
            ["frame", diag_frameNo], ["activeScripts", count diag_activeSQFScripts],
            ["allUnits", count allUnits], ["allGroups", count allGroups], ["vehicles", count vehicles],
            ["managedGroups", count (missionNamespace getVariable ["DRO2026_managedGroups", []])],
            ["managedVehicles", count (missionNamespace getVariable ["DRO2026_managedVehicles", []])],
            ["activeDrones", count (missionNamespace getVariable ["DRO2026_activeDrones", []])],
            ["activeStrategicMunitions", count (missionNamespace getVariable ["DRO2026_activeStrategicMunitions", []])],
            ["sites", count (missionNamespace getVariable ["DRO2026_sites", []])],
            ["contacts", count (missionNamespace getVariable ["DRO2026_contacts", []])],
            ["logisticsJobs", count (missionNamespace getVariable ["DRO2026_logisticsJobs", []])],
            ["dynamicTasks", count (missionNamespace getVariable ["DRO2026_dynamicTasks", []])],
            ["eventCounts", _eventCounts], ["telemetryStats", _stats],
            ["resources", missionNamespace getVariable ["DRO2026_resources", createHashMap]],
            ["phase", (missionNamespace getVariable ["DRO2026_operationState", createHashMap]) getOrDefault ["phase", "UNKNOWN"]]
        ], 1, "WORLD", 0] call DRO2026_fnc_telemetryRecord;
        missionNamespace setVariable ["DRO2026_telemetryEventIntervalCounts", createHashMap];
    };

    if (_rank >= 2) then {
        private _trace = _rank >= 3;
        private _bucket = if (_trace) then {
            missionNamespace getVariable ["DRO2026_TELEMETRY_TRACE_POSITION_BUCKET", 100]
        } else {
            missionNamespace getVariable ["DRO2026_TELEMETRY_POSITION_BUCKET", 500]
        };
        private _entityInterval = if (_trace) then {10} else {120};
        private _maxEntities = missionNamespace getVariable ["DRO2026_TELEMETRY_MAX_TRACKED_ENTITIES", 220];
        private _entities = [];
        {_entities pushBackUnique _x} forEach (missionNamespace getVariable ["DRO2026_managedVehicles", []]);
        {_entities pushBackUnique _x} forEach (missionNamespace getVariable ["DRO2026_activeDrones", []]);
        {
            private _object = _x getOrDefault ["object", objNull];
            if (!isNull _object) then {_entities pushBackUnique _object};
        } forEach (missionNamespace getVariable ["DRO2026_activeStrategicMunitions", []]);
        if (count _entities > _maxEntities) then {_entities resize _maxEntities};
        {
            if (!isNull _x) then {
                _x setVariable ["DRO2026_telemetryOwned", true];
                private _snapshot = [_x, _bucket, _trace] call DRO2026_fnc_telemetryObjectSnapshot;
                ["ENTITY", "DELTA", _snapshot, 2, netId _x, _entityInterval] call DRO2026_fnc_telemetryRecord;
            };
        } forEach _entities;

        {
            private _group = _x;
            if (!isNull _group && {count units _group > 0}) then {
                private _id = _group getVariable ["DRO2026_telemetryId", ""];
                if (_id == "") then {
                    _id = format ["GRP_%1_%2", side _group, floor random 1000000];
                    _group setVariable ["DRO2026_telemetryId", _id, true];
                };
                private _leader = leader _group;
                private _wpIndex = currentWaypoint _group;
                private _wps = waypoints _group;
                private _wpType = if (_wpIndex >= 0 && {_wpIndex < count _wps}) then {waypointType [_group, _wpIndex]} else {""};
                private _leaderPos = getPosASL _leader;
                private _groupData = createHashMapFromArray [
                    ["groupId", _id], ["side", str side _group],
                    ["units", count units _group], ["aliveUnits", {alive _x} count units _group],
                    ["vehicles", count ((units _group apply {vehicle _x}) arrayIntersect (units _group apply {vehicle _x}))],
                    ["leader", netId _leader], ["leaderClass", typeOf _leader],
                    ["positionBucketASL", [floor ((_leaderPos select 0) / _bucket) * _bucket, floor ((_leaderPos select 1) / _bucket) * _bucket, floor ((_leaderPos select 2) / 50) * 50]],
                    ["currentWaypoint", _wpIndex], ["waypointType", _wpType],
                    ["combatMode", combatMode _group], ["speedMode", speedMode _group],
                    ["formation", formation _group], ["behaviour", behaviour _leader],
                    ["command", currentCommand _leader]
                ];
                ["GROUP", "DELTA", _groupData, 2, _id, if (_trace) then {10} else {120}] call DRO2026_fnc_telemetryRecord;
            };
        } forEach (missionNamespace getVariable ["DRO2026_managedGroups", []]);

        {
            private _site = _x;
            private _siteId = _site getOrDefault ["id", ""];
            if (_siteId != "") then {
                private _objects = (_site getOrDefault ["objects", []]) select {!isNull _x};
                private _siteData = createHashMapFromArray [
                    ["siteId", _siteId], ["type", _site getOrDefault ["type", ""]],
                    ["state", _site getOrDefault ["state", ""]], ["status", _site getOrDefault ["status", ""]],
                    ["physicalState", _site getOrDefault ["physicalState", ""]],
                    ["networkNodeId", _site getOrDefault ["networkNodeId", ""]],
                    ["objects", count _objects], ["aliveObjects", {alive _x} count _objects],
                    ["stockHealth", round ((_site getOrDefault ["stockHealth", 1]) * 20) / 20],
                    ["positionATL", _site getOrDefault ["positionATL", _site getOrDefault ["position", []]]]
                ];
                ["SITE", "DELTA", _siteData, 2, _siteId, if (_trace) then {15} else {90}] call DRO2026_fnc_telemetryRecord;
            };
        } forEach (missionNamespace getVariable ["DRO2026_sites", []]);

        private _nodes = missionNamespace getVariable ["DRO2026_networkNodes", createHashMap];
        {
            private _nodeId = _x;
            private _node = _nodes get _nodeId;
            private _nodeData = createHashMapFromArray [
                ["nodeId", _nodeId], ["type", _node getOrDefault ["type", ""]],
                ["status", _node getOrDefault ["status", ""]],
                ["stateMachineState", _node getOrDefault ["stateMachineState", ""]],
                ["emissionState", _node getOrDefault ["emissionState", ""]],
                ["knownByPlayer", _node getOrDefault ["knownByPlayer", false]],
                ["knownByEnemy", _node getOrDefault ["knownByEnemy", false]],
                ["stocks", _node getOrDefault ["stocks", createHashMap]],
                ["physicalRefs", count ((_node getOrDefault ["physicalRefs", []]) select {!isNull _x})]
            ];
            ["NODE", "DELTA", _nodeData, 2, _nodeId, if (_trace) then {15} else {90}] call DRO2026_fnc_telemetryRecord;
        } forEach keys _nodes;

        private _contacts = +(missionNamespace getVariable ["DRO2026_contacts", []]);
        private _contactLimit = if (_trace) then {160} else {80};
        if (count _contacts > _contactLimit) then {_contacts resize _contactLimit};
        {
            private _contactId = _x getOrDefault ["id", ""];
            if (_contactId != "") then {
                private _position = _x getOrDefault ["positionASL", []];
                private _positionBucket = if (count _position >= 3) then {[
                    floor ((_position select 0) / _bucket) * _bucket,
                    floor ((_position select 1) / _bucket) * _bucket,
                    floor ((_position select 2) / 50) * 50
                ]} else {[]};
                ["CONTACT", "DELTA", createHashMapFromArray [
                    ["contactId", _contactId], ["owner", _x getOrDefault ["owner", ""]],
                    ["state", _x getOrDefault ["state", ""]], ["bdaState", _x getOrDefault ["bdaState", ""]],
                    ["subjectMode", _x getOrDefault ["subjectMode", ""]],
                    ["classification", _x getOrDefault ["classification", ""]],
                    ["confidence", round ((_x getOrDefault ["confidence", 0]) * 20) / 20],
                    ["uncertainty", round ((_x getOrDefault ["uncertaintyRadius", 0]) / 25) * 25],
                    ["reservationId", _x getOrDefault ["reservationId", ""]],
                    ["positionBucketASL", _positionBucket]
                ], 2, _contactId, if (_trace) then {15} else {90}] call DRO2026_fnc_telemetryRecord;
            };
        } forEach _contacts;
    };
    sleep _interval;
};
