if (isMultiplayer) then {
	private _respawnDisabled = missionNamespace getVariable ["DRO2026_respawnDisabled", (paramsArray param [0, 1]) == 3];
	if (_respawnDisabled) then {
		[player, -2000, true] call BIS_fnc_respawnTickets;
		diag_log ([player, 0, true] call BIS_fnc_respawnTickets);
		[missionNamespace, -2000] call BIS_fnc_respawnTickets;
	};
};