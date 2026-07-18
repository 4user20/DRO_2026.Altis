player removeAction _actionID;

(format ["DRO: Player %1 lobby closed", player]) remoteExec ["diag_log", 2, false];

cutText ["", "BLACK FADED"];

(format ["DRO: Player %1 preparing to terminate camera %2", player, camLobby]) remoteExec ["diag_log", 2, false];
camLobby cameraEffect ["terminate","back"];
camUseNVG false;
camDestroy camLobby;
(format ["DRO: Player %1 terminated camera %2", player, camLobby]) remoteExec ["diag_log", 2, false];
player switchCamera playerCameraView;
(format ["DRO: Player %1 switched to cameraView %2", player, cameraView]) remoteExec ["diag_log", 2, false];

private _startPosDeadline = diag_tickTime + 60;
waitUntil {sleep 0.1; count (missionNameSpace getVariable ["startPos", []]) > 0 || {diag_tickTime > _startPosDeadline}};
if (count (missionNameSpace getVariable ["startPos", []]) == 0) then {
    missionNameSpace setVariable ["startPos", if (getMarkerColor "campMkr" != "") then {getMarkerPos "campMkr"} else {getPosATL player}, true];
    diag_log "DRO: startPos timeout; fallback position assigned";
};

3 fadeSound 1;
enableSentences true;
cutText ["", "BLACK IN", 3];

// Mission info readout
[] call fnc_missionText;

player createDiarySubject ["dro", "DRO 2026"];
player createDiaryRecord ["dro", ["DRO 2026", "
	<font image='images\recon_image_collection.jpg' width='350' height='175'></font><br/><br/>
	DRO 2026 формирует случайную современную операцию. Задачи связаны с логистикой, артиллерией, ПВО, РЭБ, площадками БПЛА, разведкой и отсечением тыла.<br/><br/>
	Доступные модовые фракции и техника определяются автоматически. Отсутствующие специализированные классы заменяются ванильными аналогами.
"]];

// Start saving player loadout periodically
[] spawn {
	loadoutSavingStarted = true;
	playerRespawning = false;
	diag_log format ["DRO: Initial respawn loadout = %1", (getUnitLoadout player)];
	while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
		sleep 5;
		if (alive player && !playerRespawning) then {
			player setVariable ["respawnLoadout", getUnitLoadout player, true]; 
		};
	};
};

