waitUntil {!isNull player};
["DRO: Player %1 respawned: %2", player, _this] call bis_fnc_logFormatServer;
if (!isNil "loadoutSavingStarted") then {
	if (loadoutSavingStarted) then {
		playerRespawning = true;
		private _loadout = player getVariable ["respawnLoadout", []];
		if (count _loadout > 0) then {
			diag_log format ["DRO: Respawning with loadout = %1", _loadout];
			player setUnitLoadout _loadout;
		};
		if (!isNil "respawnTime" && {respawnTime >= 0}) then {
			setPlayerRespawnTime respawnTime;
		};
		deleteVehicle (_this select 1);
		playerRespawning = false;
	};
};
if (!isNil "droGroupIconsVisible") then {
	if (droGroupIconsVisible) then {
		setGroupIconsVisible [true, false];
	};
};