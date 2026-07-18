if (player == topUnit) then {	
	waitUntil {!dialog};
	// Faction dialog
	diag_log "DRO: Create menu dialog";
	_handle = createDialog "sundayDialog";
	diag_log format ["DRO: Created dialog: %1", _handle];
	[] call compile preprocessFileLineNumbers "loadProfile.sqf";
	[] execVM "sunday_system\dialogs\populateStartupMenu.sqf";
	//playSound "Transition1";
};

_rscLayer cutFadeOut 2;

//diag_log format ["DRO: Player %1 waiting for serverReady", player];
//waitUntil {(missionNameSpace getVariable ["serverReady", 0]) == 1};
//diag_log format ["DRO: Player %1 received serverReady", player];

if (player != topUnit) then {
	[toUpper "ПОДОЖДИТЕ, ОПЕРАЦИЯ ФОРМИРУЕТСЯ", "objectivesSpawned", 1, ""] spawn sun_callLoadScreen;
};

[] spawn {
	// Turn off menu music without leaving an immortal waiting thread.
	private _deadline = diag_tickTime + 180;
	waitUntil {sleep 0.25; (missionNameSpace getVariable ["factionsChosen", 0]) == 1 || {diag_tickTime > _deadline}};
	10 fadeMusic 0;
};

diag_log format ["DRO: Player %1 waiting for objectivesSpawned", player];
private _objectivesDeadline = diag_tickTime + 240;
waitUntil {sleep 0.1; (missionNameSpace getVariable ["objectivesSpawned", 0]) == 1 || {diag_tickTime > _objectivesDeadline}};
if ((missionNameSpace getVariable ["objectivesSpawned", 0]) != 1) exitWith {
    diag_log "DRO: objectivesSpawned timeout";
    _rscLayer cutFadeOut 1;
    hint "Генератор задач не завершил работу. Проверьте RPT.";
};
diag_log format ["DRO: Player %1 objectivesSpawned == 1", player];


// Get camera target point
_heightEnd = getTerrainHeightASL (missionNameSpace getVariable ["aoCamPos", []]);
_camEndPos = [(missionNameSpace getVariable "aoCamPos") select 0, (missionNameSpace getVariable ["aoCamPos", []]) select 1, 10];
_iconPos = ASLToAGL _camEndPos;

_aoLocationName = (missionNameSpace getVariable "aoLocationName");

// Create camera initial zoom point
_camDir = (random 360);
_initialCamPos = [_camEndPos, 3000, _camDir] call BIS_fnc_relPos;

// Create camera slowdown point
_extendPos = [_camEndPos, 200, _camDir] call BIS_fnc_relPos;
_heightStart = getTerrainHeightASL _extendPos;
if (_heightStart < _heightEnd) then {
	_heightStart = _heightEnd; 
};
if (_heightStart < 20) then {_heightStart = 0};
_camStartPos = [(_extendPos select 0), (_extendPos select 1), (_heightStart+15)];

_initialHeight = (_heightStart+50);
_initialCamPos set [2, _initialHeight];
_attempts = 0;
while {(terrainIntersectASL [_camStartPos, _initialCamPos])} do {
	if (_attempts > 10) exitWith {};
	_initialHeight = _initialHeight + 30;
	_initialCamPos set [2, _initialHeight];	
	_attempts = _attempts + 1;
	diag_log "DRO: Raised _initialCamPos";
};

// Init camera
cam = "camera" camCreate _initialCamPos;
diag_log format ["DRO: Player %1 waiting for randomCamActive", player];
private _randomCamDeadline = diag_tickTime + 45;
waitUntil {sleep 0.1; !randomCamActive || {diag_tickTime > _randomCamDeadline}};
if (diag_tickTime > _randomCamDeadline) then {randomCamActive = false; diag_log "DRO: randomCamActive timeout forced off"};
diag_log format ["DRO: Player %1 received randomCamActive", player];
cam cameraEffect ["internal", "BACK"];
cam camSetPos _initialCamPos;
cam camSetTarget _camEndPos;
cam camCommit 0;
if (timeOfDay == 4) then {
	camUseNVG true;
};	
cameraEffectEnableHUD false;
cam camPreparePos _camStartPos;
cam camCommitPrepared 3;

cutText ["", "BLACK IN", 3];
diag_log "DRO: Intro camera begun";

playMusic "";
0 fadeMusic 1;
playmusic [musicIntroSting, 0];

sleep 3;
cam camPreparePos _camEndPos;
cam camPrepareFov 0.2;
cam camCommitPrepared 50;

[
	[
		[toUpper _aoLocationName, "align = 'center' shadow = '0' size = '2' font='EtelkaMonospaceProBold'"]		
	],
	0 * safezoneW + safezoneX,
	0.75 * safezoneH + safezoneY,
	false
] spawn BIS_fnc_typeText2;
sleep 7;
cutText ["", "BLACK OUT", 1];
10 fademusic 0;
sleep 1;

closeDialog 1;

cam cameraEffect ["terminate","back"];
camUseNVG false;
camDestroy cam;	
diag_log format ["DRO: Player %1 cam terminated", player];	


//waitUntil{(missionNameSpace getVariable ["dro_introCamComplete", 0]) == 1};
// Open map
_mapOpen = openMap [true, false];
mapAnimAdd [0, 0.05, markerPos "centerMkr"];
mapAnimCommit;
cutText ["", "BLACK IN", 1];
hintSilent "Закройте карту, чтобы перейти к подготовке";
diag_log format ["DRO: Player %1 map initialised", player];

private _mapDeadline = diag_tickTime + 900;
waitUntil {sleep 0.1; !visibleMap || {diag_tickTime > _mapDeadline}};
if (visibleMap) then {openMap false};
diag_log format ["DRO: Player %1 map closed", player];
hintSilent "";

cutText ["", "BLACK FADED"];

// Open lobby
_handle = CreateDialog "DRO_lobbyDialog";
diag_log format ["DRO: Player %1 created DRO_lobbyDialog: %2", player, _handle];
[] execVM "sunday_system\dialogs\populateLobby.sqf";

sleep 0.5;
cutText ["", "BLACK IN", 1];

_actionID = player addAction ["Открыть планирование группы", 
	{
		_handle = CreateDialog "DRO_lobbyDialog";
		[] execVM "sunday_system\dialogs\populateLobby.sqf";
	}, nil, 6
];

while {
	((missionNameSpace getVariable ["lobbyComplete", 0]) == 0)
} do {
	sleep 0.2;	
	if ((getMarkerColor "campMkr" == "")) then {
		((findDisplay 626262) displayCtrl 6006) ctrlSetText "Точка высадки: СЛУЧАЙНАЯ";
	} else {
		((findDisplay 626262) displayCtrl 6006) ctrlSetText format ["Точка высадки: %1", (mapGridPosition (getMarkerPos 'campMkr'))];			
	};
	{
		if (_x getVariable ["startReady", false] OR !isPlayer _x) then {
			((findDisplay 626262) displayCtrl (_x getVariable "unitNameTagIDC")) ctrlSetTextColor [0.05, 1, 0.5, 1];
		} else {
			((findDisplay 626262) displayCtrl (_x getVariable "unitNameTagIDC")) ctrlSetTextColor [1, 1, 1, 1];
		};
	} forEach (units group player);
	if (player == topUnit) then {
		_allHCs = entities "HeadlessClient_F";
		_allHPs = allPlayers - _allHCs;
		if (({(_x getVariable ["startReady", false])} count _allHPs) >= count _allHPs) then {
			missionNameSpace setVariable ['lobbyComplete', 1, true];	
		};	
	};
};

// Wait for host to press the start button
diag_log format ["DRO: Player %1 waiting for lobbyComplete", player];
waitUntil {((missionNameSpace getVariable ["lobbyComplete", 0]) == 1)};
diag_log format ["DRO: Player %1 received lobbyComplete", player];

// Close dialogs twice in case player has arsenal open
closeDialog 1;	
closeDialog 1;	

1 fadeSound 0;

