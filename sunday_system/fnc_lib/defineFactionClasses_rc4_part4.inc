		diag_log format ["_subcatWeights = %1", _subcatWeights];	
		
		// Choose a subcategory out of those remaining	
		_chosenSubcat = if (count _availableSubcats > 0) then {[_availableSubcats, _subcatWeights] call BIS_fnc_selectRandomWeighted} else {""};
		diag_log format ["_chosenSubcat = %1", _chosenSubcat];
		
		// Add units with that subcategory to the chosen units
		_chosenClasses = [];
		_chosenWeights = [];
		for "_i" from 0 to ((count (eInfClassesForWeights select _thisFactionIndex))-1) do {
			_thisSubcat = (((configFile >> "CfgVehicles" >> ((eInfClassesForWeights select _thisFactionIndex) select _i) >> "editorSubcategory")) call BIS_fnc_GetCfgData);
			if (_thisSubcat == _chosenSubcat) then {
				_chosenClasses pushBack ((eInfClassesForWeights select _thisFactionIndex) select _i);
				_chosenWeights pushBack ((eInfClassWeights select _thisFactionIndex) select _i);
			};		
		};
		eInfClassesForWeights set [_thisFactionIndex, _chosenClasses];
		eInfClassWeights set [_thisFactionIndex, _chosenWeights];		
	};
} forEach _enemyFactions;

diag_log "DRO: Beginning DLC checks";

civCarClasses = civCarClasses - ["C_Kart_01_F", "C_Kart_01_Blu_F", "C_Kart_01_Fuel_F", "C_Kart_01_Red_F", "C_Kart_01_Vrana_F"];

if (civFaction == "CIV_F") then {
	private _worldName = worldName;
	if !(_worldName in ["Stratis","Altis","Malden","Tanoa","Enoch"]) then {_worldName = "Other"};
	civClasses = getArray (configfile >> "CfgVehicles" >> "ModuleCivilianPresence_F" >> "UnitTypes" >> _worldName);
};

// RC4: do not instantiate every vehicle class to detect DLC ownership.
// With large mod presets this created hundreds of heavy Pook vehicles and caused a major startup freeze.
_unavailableDLCS = getDLCS 2;
_unavailableVehicles = [];
diag_log "DRO: DLC vehicle instantiation check skipped; runtime class validation is used instead";