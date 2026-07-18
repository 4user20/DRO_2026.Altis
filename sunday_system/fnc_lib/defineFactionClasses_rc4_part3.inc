} forEach ("(getNumber (_x >> 'scope') == 2)" configClasses (configFile / "CfgVehicles"));

// Ensure there are officers
if (count pOfficerClasses == 0) then {
	pOfficerClasses = pInfClasses;
};
if (count eOfficerClasses == 0) then {
	eOfficerClasses = eInfClasses;
};

// Ensure there are mortars
if (count pMortarClasses == 0) then {
	pMortarClasses = ["B_Mortar_01_F"];
};
if (count eMortarClasses == 0) then {
	eMortarClasses = ["O_Mortar_01_F"];
};

// Check to see if there are a lot of unarmed units, in which case, allow them to be valid
if (count _pInfClassesUnarmed > count pInfClasses) then {
	pInfClasses = pInfClasses + _pInfClassesUnarmed;
	{	
		(pInfClassesForWeights set [_forEachIndex, ((pInfClassesForWeights select _forEachIndex) + (pInfClassesUnarmedForWeights select _forEachIndex))]);	
		(pInfClassWeights set [_forEachIndex, ((pInfClassWeights select _forEachIndex) + (pInfClassUnarmedWeights select _forEachIndex))]);			
	} forEach _playerFactions;
};

if (count _eInfClassesUnarmed > count eInfClasses) then {
	eInfClasses = eInfClasses + _eInfClassesUnarmed;
	{	
		(eInfClassesForWeights set [_forEachIndex, ((eInfClassesForWeights select _forEachIndex) + (eInfClassesUnarmedForWeights select _forEachIndex))]);	
		(eInfClassWeights set [_forEachIndex, ((eInfClassWeights select _forEachIndex) + (eInfClassUnarmedWeights select _forEachIndex))]);			
	} forEach _enemyFactions;
};

// Hard filter editor subcategories before weighted selection. Pook SAM site/control classes
// can inherit from Man and otherwise become an entire SAM site when spawned as infantry.
_pInfEditorSubcats = _pInfEditorSubcats apply {_x select {!([_x] call _isBlockedSubcat)}};
_eInfEditorSubcats = _eInfEditorSubcats apply {_x select {!([_x] call _isBlockedSubcat)}};
_pInfEditorSubcats = _pInfEditorSubcats apply {_x select {!([_x] call _isBlockedSubcat)}};
_eInfEditorSubcats = _eInfEditorSubcats apply {_x select {!([_x] call _isBlockedSubcat)}};

diag_log format ["DRO: _pInfEditorSubcats = %1", _pInfEditorSubcats];
diag_log format ["DRO: pInfClassWeights = %1", pInfClassWeights];
diag_log format ["DRO: _eInfEditorSubcats = %1", _eInfEditorSubcats];
diag_log format ["DRO: eInfClassWeights = %1", eInfClassWeights];

// If there are more than one subcategory of infantry units then select one
{
	_thisFactionIndex = _forEachIndex;
	if (count (_pInfEditorSubcats select _thisFactionIndex) > 1) then {
		_chosenClasses = [];
		_chosenWeights = [];
		
		// Check how many units are in a subcategory
		_unavailableSubcats = [];
		_availableSubcats = [];
		_subcatWeights = [];
		{
			_thisSubcat = _x;
			_chosenClasses = [];
			_chosenWeights = [];
						
			for "_i" from 0 to ((count (pInfClassesForWeights select _thisFactionIndex))-1) do {
				_unitSubcat = (((configFile >> "CfgVehicles" >> ((pInfClassesForWeights select _thisFactionIndex) select _i) >> "editorSubcategory")) call BIS_fnc_GetCfgData);
				if (_unitSubcat == _thisSubcat) then {
					_chosenClasses pushBack ((pInfClassesForWeights select _thisFactionIndex) select _i);
					_chosenWeights pushBack ((pInfClassWeights select _thisFactionIndex) select _i);
				};
			};
			
			diag_log format ["Subcat %2 _chosenWeights = %1", _chosenWeights, _thisSubcat];
			
			// Look at weights in this subcategory, if there are none above sniper level then disallow the subcategory
			_allowThisSubcat = false;
			{
				if (_x > 0.1) then {
					_allowThisSubcat = true;
				};
			} forEach _chosenWeights;
			
			if (!_allowThisSubcat) then {
				_unavailableSubcats pushBack _thisSubcat;
			} else {
				_availableSubcats pushBack _thisSubcat;
				_subcatWeights pushBack ((count _chosenClasses)/100);
			};
		} forEach (_pInfEditorSubcats select _thisFactionIndex);
		
		diag_log format ["_availableSubcats = %1", _availableSubcats];
		diag_log format ["_unavailableSubcats = %1", _unavailableSubcats];
		diag_log format ["_subcatWeights = %1", _subcatWeights];	
		
		// Choose a subcategory out of those remaining	
		_chosenSubcat = if (count _availableSubcats > 0) then {[_availableSubcats, _subcatWeights] call BIS_fnc_selectRandomWeighted} else {""};
		diag_log format ["_chosenSubcat = %1", _chosenSubcat];
		
		// Add units with that subcategory to the chosen units
		_chosenClasses = [];
		_chosenWeights = [];
		for "_i" from 0 to ((count (pInfClassesForWeights select _thisFactionIndex))-1) do {
			_thisSubcat = (((configFile >> "CfgVehicles" >> ((pInfClassesForWeights select _thisFactionIndex) select _i) >> "editorSubcategory")) call BIS_fnc_GetCfgData);
			if (_thisSubcat == _chosenSubcat) then {
				_chosenClasses pushBack ((pInfClassesForWeights select _thisFactionIndex) select _i);
				_chosenWeights pushBack ((pInfClassWeights select _thisFactionIndex) select _i);
			};		
		};
		pInfClassesForWeights set [_thisFactionIndex, _chosenClasses];
		pInfClassWeights set [_thisFactionIndex, _chosenWeights];		
	};
} forEach _playerFactions;


{
	_thisFactionIndex = _forEachIndex;
	if (count (_eInfEditorSubcats select _thisFactionIndex) > 1) then {
		_chosenClasses = [];
		_chosenWeights = [];
		
		// Check how many units are in a subcategory
		_unavailableSubcats = [];
		_availableSubcats = [];
		_subcatWeights = [];
		{
			_thisSubcat = _x;
			_chosenClasses = [];
			_chosenWeights = [];
						
			for "_i" from 0 to ((count (eInfClassesForWeights select _thisFactionIndex))-1) do {
				_unitSubcat = (((configFile >> "CfgVehicles" >> ((eInfClassesForWeights select _thisFactionIndex) select _i) >> "editorSubcategory")) call BIS_fnc_GetCfgData);
				if (_unitSubcat == _thisSubcat) then {
					_chosenClasses pushBack ((eInfClassesForWeights select _thisFactionIndex) select _i);
					_chosenWeights pushBack ((eInfClassWeights select _thisFactionIndex) select _i);
				};
			};
			
			diag_log format ["Subcat %2 _chosenWeights = %1", _chosenWeights, _x];
			
			// Look at weights in this subcategory, if there are none above sniper level then disallow the subcategory
			_allowThisSubcat = false;
			{
				if (_x > 0.1) then {
					_allowThisSubcat = true;
				};
			} forEach _chosenWeights;
			
			if (!_allowThisSubcat) then {
				_unavailableSubcats pushBack _x;
			} else {
				_availableSubcats pushBack _x;
				_subcatWeights pushBack ((count _chosenClasses)/100);
			};
		} forEach (_eInfEditorSubcats select _thisFactionIndex);
		
		diag_log format ["_availableSubcats = %1", _availableSubcats];
		diag_log format ["_unavailableSubcats = %1", _unavailableSubcats];
