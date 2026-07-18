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
};

// Generate military POIs
{
	switch (_x) do {
		case "ROADBLOCK": {						
			_numRoadblocks = if (_aoBudget > 18) then {1} else {0};
			diag_log format ["DRO: AO %1, Generate enemies - _numRoadblocks = %2", _AOIndex, _numRoadblocks];
			if (_numRoadblocks > 0) then {
				for "_x" from 1 to _numRoadblocks step 1 do {
					[_AOIndex] call fnc_generateRoadblock;
				};
			};		
		};
		case "BUNKER": {			
			_numBunkers = if (_aoBudget > 20 && {random 1 > 0.45}) then {1} else {0};
			diag_log format ["DRO: AO %1, Generate enemies - _numBunkers = %2", _AOIndex, _numBunkers];
			if (_numBunkers > 0) then {
				for "_x" from 1 to _numBunkers step 1 do {	
					[_AOIndex] call fnc_generateBunker;
				};
			};
		};		
		case "CAMP": {			
			_numCamps = if (_aoBudget > 22 && {random 1 > 0.55}) then {1} else {0};
			diag_log format ["DRO: AO %1, Generate enemies - _numCamps = %2", _AOIndex, _numCamps];
			if (_numCamps > 0) then {
				for "_x" from 1 to _numCamps step 1 do {
					_campPositions = [];
					if (count (((AOLocations select _AOIndex) select 2) select 6) > 0) then {_campPositions pushBack 6};
					if (count (((AOLocations select _AOIndex) select 2) select 9) > 0) then {_campPositions pushBack 9};
					_campPos = [(((AOLocations select _AOIndex) select 2) select (selectRandom _campPositions))] call sun_selectRemove;
					[_campPos] execVM "sunday_system\generate_ao\generateCampsite.sqf";
					_minAI = (round ((2 * aiMultiplier) / (0.4 * _numCamps)) min 3);
					_maxAI = (round ((3 * aiMultiplier) / (0.4 * _numCamps)) min 5);		
					_spawnedSquad = nil;
					_spawnedSquad = [_campPos, enemySide, eInfClassesForWeights, eInfClassWeights, [_minAI,_maxAI]] call dro_spawnGroupWeighted;			
					waitUntil {!isNil "_spawnedSquad"};
					[_spawnedSquad, _campPos] call bis_fnc_taskDefend;	
					enemyAlertableGroups pushBack _spawnedSquad;
					_markerName = format["campMkr%1", floor(random 10000)];
					_markerCamp = createMarker [_markerName, _campPos];			
					_markerCamp setMarkerShape "ICON";
					_markerCamp setMarkerType "hd_warning";
					_markerCamp setMarkerText "Camp";			
					_markerCamp setMarkerColor markerColorEnemy;
					_markerCamp setMarkerAlpha 0;				
					travelPosPOIMil pushBack _campPos;	
				};
			};
		};		
		case "EMPLACEMENT": {
			_numEmplacements = if (_aoBudget > 24 && {random 1 > 0.6}) then {1} else {0};
			diag_log format ["DRO: AO %1, Generate enemies - _numEmplacements = %2", _AOIndex, _numEmplacements];
			if (_numEmplacements > 0) then {
				for "_x" from 1 to _numEmplacements step 1 do {	
					[_AOIndex] call fnc_generateEmplacement;
				};
			};			
		};
		case "BARRIER": {
			if (_sizeMod > 0.5) then {
				[_AOIndex] call fnc_generateBarrier;
			};
		};
	};
} forEach AO_POIs;


// Get a selection of possible new travel locations if chance allows
if (count _patrolGroups > 0) then {
	diag_log format ["DRO: _patrolGroups = %1", _patrolGroups];
	_availableTravelPositions = [];			
	{
		if (_forEachIndex != 0) then {			
			if ((_x select 3) isEqualTo "ROUTE") then {
				if (count ((_x select 2) select 0) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 0)};
				if (count ((_x select 2) select 1) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 1)};
				if (count ((_x select 2) select 2) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 2)};
			};
		} else {
			if (count ((_x select 2) select 0) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 0)};
			if (count ((_x select 2) select 1) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 1)};
			if (count ((_x select 2) select 2) > 0) then {_availableTravelPositions = _availableTravelPositions + ((_x select 2) select 2)};
		};
	} forEach AOLocations;
	_availableTravelPositions = _availableTravelPositions + travelPosPOIMil;
	{
		_thisGroup = _x;
		_startPos = (getPos (leader _thisGroup));
		if (count _availableTravelPositions > 0) then {
			_thesePositions = _availableTravelPositions;
			diag_log format ["DRO: Enemy patrol _thesePositions = %1", _thesePositions];					
			// Initialise route waypoints
			_wpFirst = _thisGroup addWaypoint [_startPos, 0];
			_wpFirst setWaypointType "MOVE";
			_wpFirst setWaypointBehaviour "SAFE";
			_wpFirst setWaypointSpeed "LIMITED";
			for "_w" from 1 to (([3, 6] call BIS_fnc_randomInt) min (count _thesePositions)) step 1 do {				
				_pos = [_thesePositions] call sun_selectRemove;
				_pos = if (typeName _pos == "OBJECT") then {getPos _pos} else {_pos};
				_wp = _thisGroup addWaypoint [_pos, 0];
				_wp setWaypointType "MOVE";
				_wp setWaypointCompletionRadius 20;
				_wp setWaypointTimeout [45, 60, 90];					
			};
			_wpLast = _thisGroup addWaypoint [_startPos, 0];
			_wpLast setWaypointType "CYCLE";		
			_wpLast setWaypointCompletionRadius 20;
			_wpLast setWaypointTimeout [20, 30, 45];								
		} else {		
			if (vehicle (leader _thisGroup) == (leader _thisGroup)) then {
				[_thisGroup, _startPos, 200] call BIS_fnc_taskPatrol;	
			} else {
				[_thisGroup, _startPos, 800] call BIS_fnc_taskPatrol;	
			};
		};
		if (_debug == 1) then {
			_garMarker = createMarker [format["garMkr%1", random 10000], _startPos];
			_garMarker setMarkerShape "ICON";
			_garMarker setMarkerColor "ColorOrange";
			_garMarker setMarkerType "mil_dot";
			_garMarker setMarkerText format ["Patrol %2: %1", _thisGroup, _forEachIndex];
			_garMarker setMarkerSize [0.7, 0.7];
			diag_log format ["Patrol %1: %2", _forEachIndex, (waypoints _thisGroup)];
		};
	} forEach _patrolGroups;		
	
};

publicVariable "enemyIntelMarkers";