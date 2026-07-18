// *****
// SETUP ENEMIES
// *****

params ["_AOIndex", "_AOSize"];

private _debug = 0;
_patrolGroups = [];
_numPlayers = count allPlayers;
enemyAlertableGroups = [];
enemySemiAlertableGroups = [];
_sizeMod = switch (_AOSize) do {
	case "REGULAR": {1};
	case "SMALL": {0.4};
	default {1};
};
enemyPosCollection = [];
private _currentEnemyAI = {alive _x && {side (group _x) == enemySide}} count allUnits;
private _remainingAIBudget = ((missionNamespace getVariable ["DRO2026_MAX_TOTAL_ENEMY_AI", 72]) - _currentEnemyAI) max 0;
private _aoBudget = (_remainingAIBudget min (missionNamespace getVariable ["DRO2026_MAX_LEGACY_AI_PER_AO", 34]));
if (_aoBudget <= 0) exitWith {diag_log "[DRO2026] Legacy enemy generation skipped: global AI budget exhausted"};

// If this is the first AO location then garrison all the previously located military buildings in the entire AO area
if (_AOIndex == 0) then {
	// RC4/SP budget: at most one local building patrol and two explicit garrisons.
	[1] call dro_localBuildingPatrol;
	private _garrisonCandidates = +milBuildings;
	_garrisonCandidates = _garrisonCandidates call BIS_fnc_arrayShuffle;
	{
		if (_forEachIndex < 2 && {({alive _x && {side (group _x) == enemySide}} count allUnits) < DRO2026_MAX_TOTAL_ENEMY_AI}) then {
			[_x] call dro_spawnEnemyGarrison;
		};
	} forEach _garrisonCandidates;
};

diag_log format ["DRO: AO %1, aiMultiplier = %2, _sizeMod = %3", _AOIndex, aiMultiplier, _sizeMod];

// Generate extra building garrisons
//_tempBuildings = [];
_tempBuildings = (((AOLocations select _AOIndex) select 2) select 7);
_numGarrisons = ((round ((([2, 3] call BIS_fnc_randomInt) * (aiMultiplier min 1)) * _sizeMod)) min 2) min (count (((AOLocations select _AOIndex) select 2) select 7));
diag_log format ["DRO: AO %1, Generate enemies - garrisons = %2", _AOIndex, _numGarrisons];
if (_numGarrisons > 0) then {
	for "_g" from 1 to _numGarrisons step 1 do {		
		[([_tempBuildings] call sun_selectRemove)] call dro_spawnEnemyGarrison;
		//[(selectRandom (((AOLocations select _AOIndex) select 2) select 7))] call dro_spawnEnemyGarrison;
	};
};
/*
_numCompounds = (round ((([2, 4] call BIS_fnc_randomInt) * aiMultiplier) * _sizeMod) min (count (((AOLocations select _AOIndex) select 2) select 9)));
diag_log format ["DRO: AO %1, Generate enemies - compounds = %2", _AOIndex, _numCompounds];
if (_numCompounds > 0) then {
	for "_c" from 1 to _numCompounds step 1 do {	
		[(selectRandom (((AOLocations select _AOIndex) select 2) select 9))] call fnc_spawnEnemyCompound;
	};
};
*/
// Infantry patrols
_numInf = (round ((([1,2] call BIS_fnc_randomInt) * (aiMultiplier min 1)) * _sizeMod)) min 2;	
_numInf = _numInf + (floor(_numPlayers/2));
diag_log format ["DRO: AO %1, Generate enemies - infantry patrols = %2", _AOIndex, _numInf];
if (missionPreset == 3) then {_numInf = _numInf min 1};
if (_numInf > 0) then {
	for "_infIndex" from 1 to _numInf step 1 do {
		_infPosition = [];
		if (_infIndex <= 1) then {
			_infPosition = selectRandom (((AOLocations select _AOIndex) select 2) select 2)
		} else {
			_infPosition = selectRandom (((AOLocations select _AOIndex) select 2) select 3)
		};
		if (count _infPosition > 0) then {
			_spawnedSquad = nil;	
			_minAI = ((round ((3 * (aiMultiplier min 1)) / (0.6 * _numInf))) max 2) min 4;
			_maxAI = ((_minAI + 1) min 5) min _aoBudget;
			_spawnedSquad = [_infPosition, enemySide, eInfClassesForWeights, eInfClassWeights, [_minAI, _maxAI]] call dro_spawnGroupWeighted;					
			waitUntil {!isNil "_spawnedSquad"};	
			_patrolGroups pushBack _spawnedSquad;				
			enemyAlertableGroups pushBack _spawnedSquad;	
		};
	};
};

if (missionPreset == 3) then {
	// Combined Arms tanks
	// Vehicle patrol
	if (count eAPCClasses > 0) then {
		_numVeh = if (_aoBudget > 18) then {1} else {0};
		for "_x" from 1 to _numVeh do {
			_indexes = [[0, 1]] call dro_checkAOIndexes;
			if (count _indexes > 0) then {			
				_vehPos = [(((AOLocations select _AOIndex) select 2) select (selectRandom _indexes))] call sun_selectRemove;			
				_vehType = selectRandom eAPCClasses;
				_veh = createVehicle [_vehType, _vehPos, [], 0, "NONE"];		
				[_veh] call sun_createVehicleCrew;
				//createVehicleCrew _veh;
				waitUntil {!isNull (driver _veh)};				
				_vehSlots = [_vehType] call sun_getTrueCargo;
				if (false && {_vehSlots > 2}) then {					
					_minAI = (_vehSlots/2) * aiMultiplier;							
					_reinfGroup = [_vehPos, enemySide, eInfClassesForWeights, eInfClassWeights, [_minAI, _vehSlots]] call dro_spawnGroupWeighted;				
					waitUntil {!isNil "_reinfGroup"};
					[_reinfGroup, _veh, true] spawn sun_groupToVehicle;					
				};				
				_patrolGroups pushBack (group (driver _veh));
				//[(group(driver _veh)), _vehPos, 800] call BIS_fnc_taskPatrol;		
				_vehPos = selectRandom (((AOLocations select _AOIndex) select 2) select 0);
			};			
		};
	};
	if (count eTankClasses > 0) then {
		_numVeh = if (_aoBudget > 24) then {1} else {0};
		for "_x" from 1 to _numVeh do {
			_indexes = [[0, 1]] call dro_checkAOIndexes;
			if (count _indexes > 0) then {			
				_vehPos = [(((AOLocations select _AOIndex) select 2) select (selectRandom _indexes))] call sun_selectRemove;			
				_vehType = selectRandom eTankClasses;
				_veh = createVehicle [_vehType, _vehPos, [], 0, "NONE"];		
				[_veh] call sun_createVehicleCrew;
				//createVehicleCrew _veh;
				waitUntil {!isNull (driver _veh)};				
				_vehSlots = [_vehType] call sun_getTrueCargo;
				if (false && {_vehSlots > 2}) then {					
					_minAI = (_vehSlots/2) * aiMultiplier;							
					_reinfGroup = [_vehPos, enemySide, eInfClassesForWeights, eInfClassWeights, [_minAI, _vehSlots]] call dro_spawnGroupWeighted;				
					waitUntil {!isNil "_reinfGroup"};
					[_reinfGroup, _veh, true] spawn sun_groupToVehicle;					
				};				
				_patrolGroups pushBack (group (driver _veh));
				//[(group(driver _veh)), _vehPos, 800] call BIS_fnc_taskPatrol;		
				_vehPos = selectRandom (((AOLocations select _AOIndex) select 2) select 0);
				[[(group (driver _veh)), "TANK"]] call dro_unitTaskObjective;
			};			
		};
	};	
};

// Vehicle patrol
if (count eCarClasses > 0) then {
	if (random 1 > 0.4) then {
		_numVeh = 1;
		for "_x" from 1 to _numVeh do {
			_indexes = [[0, 1]] call dro_checkAOIndexes;
			if (count _indexes > 0) then {			
				_vehPos = [(((AOLocations select _AOIndex) select 2) select (selectRandom _indexes))] call sun_selectRemove;			
				_vehType = selectRandom eCarClasses;
				_veh = createVehicle [_vehType, _vehPos, [], 0, "NONE"];		
