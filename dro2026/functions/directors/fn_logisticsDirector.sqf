if (!isServer) exitWith {};
while {true} do {
    sleep 180;
    private _supply = DRO2026_resources getOrDefault ["enemySupply", 0];
    private _ammo = DRO2026_resources getOrDefault ["enemyArtilleryAmmo", 0];
    private _stock = DRO2026_resources getOrDefault ["enemyDroneStock", 0];

    // Abstract flow continues globally. Destroyed hubs reduce replenishment without requiring hundreds of physical vehicles.
    if (_supply > 10) then {
        DRO2026_resources set ["enemyArtilleryAmmo", (_ammo + (1 + floor (_supply / 35))) min 100];
        DRO2026_resources set ["enemyDroneStock", (_stock + (1 + floor (_supply / 45))) min 60];
    };
    DRO2026_resources set ["enemySupply", (_supply - 0.5) max 0];
};
