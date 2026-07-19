_rscLayer = ["RscLogo"] call BIS_fnc_rscLayer;
_rscLayer cutRsc ["DRO_Splash", "PLAIN", 0, true];

diag_log format ["DRO: Player %1 waiting for player init", player];
private _playerInitDeadline = diag_tickTime + 45;
waitUntil {sleep 0.05; !isNull player || {diag_tickTime > _playerInitDeadline}};
if (isNull player) exitWith {diag_log "DRO: initPlayerLocal aborted: player remained null"};

// Legacy libraries are included by the root initPlayerLocal.sqf. Keeping
// them there is intentional: Arma resolves #include relative to the file
// containing the directive, not relative to the mission root.

addWeaponItemEverywhere = compileFinal " _this select 0 addPrimaryWeaponItem (_this select 1); ";
addHandgunItemEverywhere = compileFinal " _this select 0 addHandgunItem (_this select 1); ";
removeWeaponItemEverywhere = compileFinal "_this select 0 removePrimaryWeaponItem (_this select 1)";

if (!hasInterface || isDedicated) exitWith {};

player setVariable ['startReady', false, true];
playerCameraView = cameraView;
loadoutSavingStarted = false;

fnc_missionText = {
	_campName = (missionNameSpace getVariable "publicCampName");
	diag_log format ["DRO: Player %1 establishing shot initialised", player];
	sleep 3;
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1</t>", toUpper _campName], true, nil, 5, 0.7, 0] spawn BIS_fnc_textTiles;
	sleep 6;
	_hours = if ((date select 3) < 10) then {format ["0%1", date select 3]} else {str (date select 3)};
	_minutes = if ((date select 4) < 10) then {format ["0%1", date select 4]} else {str (date select 4)};
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1  %2</t>", str(date select 1) + "." + str(date select 2) + "." + str(date select 0), _hours + _minutes + " Ч"], true, nil, 5, 0.7, 0] spawn BIS_fnc_textTiles;
	sleep 6;
	_missionName = missionNameSpace getVariable ["mName", ""];
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1</t>", toUpper _missionName], true, nil, 7, 0.7, 0] spawn BIS_fnc_textTiles;
};

0 fadeMusic 0;
playMusic "LeadTrack01_F_Jets";
5 fadeMusic 1;

player createDiarySubject ["dro", "DRO 2026"];
player createDiaryRecord ["dro", ["DRO 2026", "
	<font image='images\recon_image_collection.jpg' width='350' height='175'></font><br/><br/>
	DRO 2026 формирует случайную современную операцию. Задачи связаны с логистикой, артиллерией, ПВО, РЭБ, площадками БПЛА, разведкой и отсечением тыла.<br/><br/>
	Доступные модовые фракции и техника определяются автоматически. Отсутствующие специализированные классы заменяются ванильными аналогами.
"]];
player setVariable ["respawnLoadout", getUnitLoadout player, true];
VAR_CAMERA_VIEW = playerCameraView;
loadoutSavingStarted = false;

diag_log format ["clientOwner = %1", clientOwner];
playerReady = 0;
enableTeamSwitch false;
enableSentences false;

_doJIP = didJIP && {(missionNameSpace getVariable ["lobbyComplete", 0]) == 1};

if (_doJIP) exitWith {
	["DRO: JIP detected for player %1", player] call bis_fnc_logFormat;
	_pos = if (getMarkerColor "respawn" == "") then {getMarkerPos "campMkr"} else {getMarkerPos "respawn"};
	_pos set [2,0];
	_chosenSlotUnit = objNull;
	{
		if (!isPlayer _x) exitWith {_chosenSlotUnit = _x};
	} forEach units (grpNetId call BIS_fnc_groupFromNetId);
	if (!isNull _chosenSlotUnit) then {
		["DRO: JIP player %1 will be selectPlayer'd into %2", player, _chosenSlotUnit] call bis_fnc_logFormat;
		selectPlayer _chosenSlotUnit;
		removeAllActions _chosenSlotUnit;
		if (reviveDisabled < 3) then {[_chosenSlotUnit] call rev_addReviveToUnit};
	} else {
		[player, _pos] call sun_jipNewUnit;
	};
	_allHCs = entities "HeadlessClient_F";
	_currentPlayers = (allPlayers - _allHCs) - [player];
	_tasks = if (count _currentPlayers > 0) then {[_currentPlayers select 0] call BIS_fnc_tasksUnit} else {[]};
	{
		_taskDesc = [_x] call BIS_fnc_taskDescription;
		_taskDest = [_x] call BIS_fnc_taskDestination;
		_taskState = [_x] call BIS_fnc_taskState;
		_taskType = missionNamespace getVariable [format ["%1_taskType", _x], "Default"];
		[_x, player, _taskDesc, _taskDest, _taskState, 1, false, false, _taskType, true] call BIS_fnc_setTask;
	} forEach _tasks;
	player createDiaryRecord ["Diary", ["Briefing", briefingString]];
	_rscLayer cutFadeOut 2;
	enableSentences true;
	cutText ["", "BLACK IN", 3];
	playMusic "";
	[] call fnc_missionText;
};

sleep 0.1;
["objectivesSpawned"] spawn sun_randomCam;

diag_log format ["DRO: Player %1 waiting for factionDataReady", player];
private _factionDeadline = diag_tickTime + 120;
waitUntil {sleep 0.1; (missionNameSpace getVariable ["factionDataReady", 0]) == 1 || {diag_tickTime > _factionDeadline}};
if ((missionNameSpace getVariable ["factionDataReady", 0]) != 1) exitWith {
    diag_log "DRO: factionDataReady timeout";
    _rscLayer cutFadeOut 1;
    hint "Ошибка инициализации фракций. Проверьте RPT и набор модов.";
};
diag_log format ["DRO: Player %1 received factionDataReady", player];
private _topUnitDeadline = diag_tickTime + 45;
waitUntil {sleep 0.1; !isNil "topUnit" || {diag_tickTime > _topUnitDeadline}};
if (isNil "topUnit") then {topUnit = player; diag_log "DRO: topUnit timeout; local player used as fallback"};

sleep 3;
