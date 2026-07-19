if (!isServer) exitWith {};
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    sleep 60;
    private _now = time;

    // Retain active routes and a bounded history of recent completed routes for status/debugging.
    DRO2026_supplyLanes = DRO2026_supplyLanes select {
        private _status = _x getOrDefault ["status", "UNKNOWN"];
        private _finishedAt = _x getOrDefault ["completedAt", _x getOrDefault ["createdAt", _now]];
        _status == "EN_ROUTE" || {(_now - _finishedAt) < DRO2026_SUPPLY_EVENT_TTL}
    };
    if (count DRO2026_supplyLanes > DRO2026_MAX_SUPPLY_EVENTS) then {
        DRO2026_supplyLanes deleteRange [0, count DRO2026_supplyLanes - DRO2026_MAX_SUPPLY_EVENTS];
    };

    // A delivered physical route is the only source of meaningful replenishment.
    {
        private _event = _x;
        if ((_event getOrDefault ["status", ""]) == "DELIVERED" && {!(_event getOrDefault ["processed", false])}) then {
            private _cargo = _event getOrDefault ["cargo", createHashMap];
            {
                private _key = _x;
                private _amount = _cargo getOrDefault [_key, 0];
                private _cap = switch _key do {
                    case "enemyDroneStock": {60};
                    default {100};
                };
                DRO2026_resources set [_key, ((DRO2026_resources getOrDefault [_key, 0]) + _amount) min _cap];
            } forEach keys _cargo;
            _event set ["processed", true];
            _event set ["processedAt", _now];
            [format ["Доставлен груз маршрута %1 в %2: %3", _event getOrDefault ["id", "?"], _event getOrDefault ["destinationType", "?"], _cargo]] call DRO2026_fnc_log;
        };
    } forEach DRO2026_supplyEvents;
    DRO2026_supplyEvents = DRO2026_supplyEvents select {
        private _processedAt = _x getOrDefault ["processedAt", _now];
        !(_x getOrDefault ["processed", false]) || {(_now - _processedAt) < DRO2026_SUPPLY_EVENT_TTL}
    };
    if (count DRO2026_supplyEvents > DRO2026_MAX_SUPPLY_EVENTS) then {
        DRO2026_supplyEvents deleteRange [0, count DRO2026_supplyEvents - DRO2026_MAX_SUPPLY_EVENTS];
    };

    private _liveHubs = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) in ["LOGISTICS_HUB", "ENEMY_HQ"] &&
        {[_x, true] call DRO2026_fnc_validateSiteRecord}
    };
    private _activeLanes = DRO2026_supplyLanes select {
        (_x getOrDefault ["status", ""]) == "EN_ROUTE" && {
            private _task = _x getOrDefault ["task", ""];
            _task == "" || {(missionNamespace getVariable [format ["%1Completed", _task], 0]) == 0}
        }
    };

    private _supply = DRO2026_resources getOrDefault ["enemySupply", 0];
    private _ammo = DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0];
    private _droneStock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];

    if (count _liveHubs == 0) then {
        // A severed network cannot preserve forward stocks indefinitely.
        DRO2026_resources set ["enemyArtilleryAmmo", (_ammo - 1.2) max 0];
        DRO2026_resources set ["enemyDroneStock", (_droneStock - 1) max 0];
        DRO2026_resources set ["enemySupply", (_supply - 0.7) max 0];
    } else {
        if (count _activeLanes == 0) then {
            // Hubs remain alive, but no cargo is moving: maintenance attrition continues slowly.
            DRO2026_resources set ["enemyArtilleryAmmo", (_ammo - 0.35) max 0];
            DRO2026_resources set ["enemyDroneStock", (_droneStock - 0.25) max 0];
            DRO2026_resources set ["enemySupply", (_supply - 0.25) max 0];
        } else {
            // Active lanes preserve readiness but do not create resources before delivery.
            DRO2026_resources set ["enemySupply", (_supply - (0.08 * count _activeLanes)) max 0];
        };
    };
};