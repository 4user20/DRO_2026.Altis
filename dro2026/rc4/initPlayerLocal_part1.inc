_rscLayer = ["RscLogo"] call BIS_fnc_rscLayer;
_rscLayer cutRsc ["DRO_Splash", "PLAIN", 0, true];

diag_log format ["DRO: Player %1 waiting for player init", player];
private _playerInitDeadline = diag_tickTime + 45;
waitUntil {sleep 0.05; !isNull player || {diag_tickTime > _playerInitDeadline}};
if (isNull player) exitWith {diag_log "DRO: initPlayerLocal aborted: player remained null"};

#include "sunday_system\fnc_lib\sundayFunctions.sqf";
#include "sunday_system\fnc_lib\droFunctions.sqf";
#include "sunday_revive\reviveFunctions.sqf";
#include "sunday_system\fnc_lib\menuFunctions.sqf";

addWeaponItemEverywhere = compileFinal " _this select 0 addPrimaryWeaponItem (_this select 1); ";
addHandgunItemEverywhere = compileFinal " _this select 0 addHandgunItem (_this select 1); ";
removeWeaponItemEverywhere = compileFinal "_this select 0 removePrimaryWeaponItem (_this select 1)";

if (!hasInterface || isDedicated) exitWith {};

player setVariable ['startReady', false, true];
playerCameraView = cameraView;
loadoutSavingStarted = false;

fnc_missionText = {
	// Mission info readout
	_campName = (missionNameSpace getVariable "publicCampName");
	diag_log format ["DRO: Player %1 establishing shot initialised", player];
	sleep 3;
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1</t>", toUpper _campName], true, nil, 5, 0.7, 0] spawn BIS_fnc_textTiles;
	sleep 6;
	_hours = "";
	if ((date select 3) < 10) then {
		_hours = format ["0%1", (date select 3)];
	} else {
		_hours = str (date select 3);
	};
	_minutes = "";
	if ((date select 4) < 10) then {
		_minutes = format ["0%1", (date select 4)];
	} else {
		_minutes = str (date select 4);
	};
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1  %2</t>", str(date select 1) + "." + str(date select 2) + "." + str(date select 0), _hours + _minutes + " Ч"], true, nil, 5, 0.7, 0] spawn BIS_fnc_textTiles;
	sleep 6;
	// Operation title text
	_missionName = missionNameSpace getVariable ["mName", ""];
	_string = format ["<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1</t>", _missionName];
	[parseText format [ "<t font='EtelkaMonospaceProBold' color='#ffffff' size = '1.7'>%1</t>", toUpper _missionName], true, nil, 7, 0.7, 0] spawn BIS_fnc_textTiles;
};

// Turn on menu music
0 fadeMusic 0;
playMusic "LeadTrack01_F_Jets";
5 fadeMusic 1;

player createDiarySubject ["dro", "DRO 2026"];
player createDiaryRecord ["dro", ["DRO 2026", "
	<font image='images\recon_image_collection.jpg' width='350' height='175'></font><br/><br/>
	DRO 2026 формирует случайную современную операцию. Задачи связаны с логистикой, артиллерией, ПВО, РЭБ, площадками БПЛА, разведкой и отсечением тыла.<br/><br/>
	Доступные модовые фракции и техника определяются автоматически. Отсутствующие специализированные классы заменяются ванильными аналогами.
"]];
player setVariable ["respawnLoadout", (getUnitLoadout player), true];
VAR_CAMERA_VIEW = playerCameraView;
loadoutSavingStarted = false;

diag_log format ["clientOwner = %1", clientOwner];
playerReady = 0;
enableTeamSwitch false;
enableSentences false;

// Move to mission area if JIP and do not process intro script
_doJIP = if (didJIP) then {
	if ((missionNameSpace getVariable ["lobbyComplete", 0]) == 0) then {
		false
	} else {
		true
	};	
} else {
	false
};

if (_doJIP) exitWith {
	["DRO: JIP detected for player %1", player] call bis_fnc_logFormat;
	//Position
	_pos = if (getMarkerColor "respawn" == "") then {
		getMarkerPos "campMkr"
	} else {
		getMarkerPos "respawn"
	};
	_pos set [2,0];
	// Loadout	
	_chosenSlotUnit = objNull;
	{
		if (!isPlayer _x) exitWith {
			_chosenSlotUnit = _x;
		};
	} forEach units (grpNetId call BIS_fnc_groupFromNetId);	
	if (!isNull _chosenSlotUnit) then {
		["DRO: JIP player %1 will be selectPlayer'd into %2", player, _chosenSlotUnit] call bis_fnc_logFormat;		
		selectPlayer _chosenSlotUnit;
		removeAllActions _chosenSlotUnit;
		if (reviveDisabled < 3) then {
			[_chosenSlotUnit] call rev_addReviveToUnit;	
		};	
	} else {
		//_class = (selectRandom unitList);
		//[player, _class] execVM 'sunday_system\player_setup\switchUnitLoadout.sqf';
		//sleep 1;
		[player, _pos] call sun_jipNewUnit;
	};
	_allHCs = entities "HeadlessClient_F";
	_currentPlayers = allPlayers - _allHCs;
	_currentPlayers = _currentPlayers - [player];
	_tasks = if (count _currentPlayers > 0) then {[ _currentPlayers select 0 ] call BIS_fnc_tasksUnit} else {[]};
	{
		_taskDesc = [_x] call BIS_fnc_taskDescription;
		_taskDest = [_x] call BIS_fnc_taskDestination;		
		_taskState = [_x] call BIS_fnc_taskState;		
		_taskType = missionNamespace getVariable [(format ["%1_taskType", _x]), "Default"];	
		_id = [_x, player, _taskDesc, _taskDest, _taskState, 1, false, false, _taskType, true] call BIS_fnc_setTask;
		//[_x, _taskType] call BIS_fnc_taskSetType;
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


//cutText ["", "BLACK IN", 2];

//["Preload"] spawn BIS_fnc_arsenal;
//sleep 2;
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


/*
_counter = 0;
while {_counter < 1} do {
	{
		((findDisplay 999991) displayCtrl _x) ctrlSetFade _counter;
		((findDisplay 999991) displayCtrl _x) ctrlCommit 0;
	} forEach [1000, 1001, 1002];
	sleep 0.02;
	_counter = _counter + 0.01;
};
closeDialog 1;
*/

sleep 3;

