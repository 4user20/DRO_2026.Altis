if (!isServer) exitWith {};
while {!DRO2026_missionEnding} do {
    sleep 180;
    private _liveHubs = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) in ["LOGISTICS_HUB", "ENEMY_HQ"] && {
            private _obj = _x getOrDefault ["object", objNull];
            !isNull _obj && {alive _obj}
        }
    };
    private _liveRuns = DRO2026_sites select {
        (_x getOrDefault ["type", ""]) in ["LOGISTICS_RUN", "CONVOY"] && {
            private _obj = _x getOrDefault ["object", objNull];
            !isNull _obj && {alive _obj} && {canMove _obj}
        }
    };
    private _networkFactor = ((count _liveHubs) * 0.65 + (count _liveRuns) * 0.25) min 1;
    private _supply = DRO2026_resources getOrDefault ["enemySupply", 0];
    private _ammo = DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0];
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];

    if (_networkFactor > 0.15 && {_supply > 8}) then {
        DRO2026_resources set ["enemyArtilleryAmmo", (_ammo + ceil (3 * _networkFactor)) min 100];
        DRO2026_resources set ["enemyDroneStock", (_stock + ceil (2 * _networkFactor)) min 60];
        DRO2026_resources set ["enemySupply", (_supply - (1.2 + _networkFactor)) max 0];
    } else {
        // No functioning hub or delivery means the remaining stocks continue to decay rather than magically regenerate.
        DRO2026_resources set ["enemyArtilleryAmmo", (_ammo - 1) max 0];
        DRO2026_resources set ["enemyDroneStock", (_stock - 1) max 0];
        DRO2026_resources set ["enemySupply", (_supply - 0.3) max 0];
    };
};
