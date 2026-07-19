if (!isServer) exitWith {};
private _lastIntentAt = -999;
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    [] call DRO2026_fnc_syncNetworkState;
    private _phase = [] call DRO2026_fnc_evaluateOperationPhase;

    private _current = missionNamespace getVariable ["DRO2026_currentIntent", createHashMap];
    private _currentStatus = _current getOrDefault ["status", ""];
    private _currentExpires = _current getOrDefault ["expiresAt", -1];
    if (count _current > 0 && {_currentStatus in ["EXECUTED", "CANCELLED"] || {time > _currentExpires}}) then {
        missionNamespace setVariable ["DRO2026_currentIntent", createHashMap];
        _current = createHashMap;
    };

    if (count _current == 0 && {(time - _lastIntentAt) > 18}) then {
        private _doctrine = DRO2026_operationState getOrDefault ["doctrine", "DRONE_HEAVY"];
        private _weights = switch _doctrine do {
            case "ARTILLERY_HEAVY": {createHashMapFromArray [["ARTILLERY_FIRE", 1.55], ["FPV_ATTACK", 0.85], ["LONG_RANGE_ATTACK", 0.9], ["REINFORCE", 0.8], ["ROUTE_ADAPT", 1.0]]};
            case "DEFENSIVE_NETWORK": {createHashMapFromArray [["ARTILLERY_FIRE", 1.0], ["FPV_ATTACK", 0.9], ["LONG_RANGE_ATTACK", 0.7], ["REINFORCE", 1.25], ["ROUTE_ADAPT", 1.35]]};
            case "MOBILE_RESERVES": {createHashMapFromArray [["ARTILLERY_FIRE", 0.8], ["FPV_ATTACK", 0.9], ["LONG_RANGE_ATTACK", 0.7], ["REINFORCE", 1.5], ["ROUTE_ADAPT", 1.25]]};
            default {createHashMapFromArray [["ARTILLERY_FIRE", 0.9], ["FPV_ATTACK", 1.5], ["LONG_RANGE_ATTACK", 1.25], ["REINFORCE", 0.75], ["ROUTE_ADAPT", 0.9]]};
        };
        private _contacts = DRO2026_contacts select {
            (_x getOrDefault ["owner", ""]) == "ENEMY" &&
            {(_x getOrDefault ["bdaState", "DETECTED"]) != "CONFIRMED_DESTROYED"} &&
            {(time - (_x getOrDefault ["lastSeen", 0])) < 320}
        };
        private _bestContact = if (count _contacts > 0) then {
            (_contacts orderBy [[], {-( (_x getOrDefault ["confidence", 0]) - ((_x getOrDefault ["uncertaintyRadius", 0]) / 3000) )}]) select 0
        } else {createHashMap};
        private _confidence = _bestContact getOrDefault ["confidence", 0];
        private _contactId = _bestContact getOrDefault ["id", ""];
        private _candidates = [];
        private _addIntent = {
            params ["_action", "_nodeId", "_base", "_cost", "_minConfidence"];
            private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
            if (count _node == 0 || {(_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED"]}) exitWith {};
            if (_minConfidence > 0 && {_confidence < _minConfidence}) exitWith {};
            private _exposure = if ((_node getOrDefault ["knownByPlayer", "UNKNOWN"]) in ["CONFIRMED", "TRACKED"]) then {0.22} else {0.05};
            private _phaseWeight = switch _phase do {
                case "RECON": {if (_action in ["FPV_ATTACK", "ARTILLERY_FIRE"]) then {0.65} else {0.85}};
                case "COUNTERATTACK": {if (_action in ["REINFORCE", "FPV_ATTACK"]) then {1.25} else {1.0}};
                default {1.0};
            };
            private _utility = (_base * (_weights getOrDefault [_action, 1]) * (_confidence max 0.45) * _phaseWeight) - _cost - _exposure;
            _candidates pushBack createHashMapFromArray [
                ["action", _action], ["actor", _nodeId], ["contactId", _contactId],
                ["utility", _utility], ["resourceCost", _cost], ["createdAt", time]
            ];
        };

        ["FPV_ATTACK", "NODE_FPV_FORWARD_01", 0.78, 0.10, DRO2026_CONTACT_REQUIRED_FOR_FPV] call _addIntent;
        ["ARTILLERY_FIRE", "NODE_ARTILLERY_01", 0.72, 0.12, 0.58] call _addIntent;
        ["LONG_RANGE_ATTACK", "NODE_DRONE_REAR_01", 0.82, 0.22, DRO2026_CONTACT_REQUIRED_FOR_LONG_RANGE] call _addIntent;
        if (DRO2026_alertLevel > 0.48) then {["REINFORCE", "NODE_ENEMY_HQ", 0.62, 0.16, 0] call _addIntent};
        private _recentInterdiction = (DRO2026_eventLog findIf {
            (_x getOrDefault ["type", ""]) == "DELIVERY_INTERDICTED" && {(time - (_x getOrDefault ["createdAt", 0])) < 600}
        }) >= 0;
        if (_recentInterdiction) then {["ROUTE_ADAPT", "NODE_LOGISTICS_01", 0.74, 0.04, 0] call _addIntent};

        if (count _candidates > 0) then {
            _candidates = [_candidates, [], {-(_x getOrDefault ["utility", 0])}, "ASCEND"] call BIS_fnc_sortBy;
            private _intent = _candidates select 0;
            _intent set ["id", format ["INTENT_%1_%2", floor diag_tickTime, floor random 1000000]];
            _intent set ["earliestAt", time + 5 + random 12];
            _intent set ["expiresAt", time + 110];
            _intent set ["status", "PROPOSED"];
            DRO2026_actionIntents pushBack _intent;
            if (count DRO2026_actionIntents > 80) then {DRO2026_actionIntents deleteRange [0, (count DRO2026_actionIntents) - 80]};
            missionNamespace setVariable ["DRO2026_currentIntent", _intent];
            ["INTENT_PROPOSED", createHashMapFromArray [["intentId", _intent get "id"], ["action", _intent get "action"], ["actor", _intent get "actor"], ["utility", _intent get "utility"]], "OPERATION"] call DRO2026_fnc_emitEvent;
            _lastIntentAt = time;
        };
    };
    sleep 12;
};