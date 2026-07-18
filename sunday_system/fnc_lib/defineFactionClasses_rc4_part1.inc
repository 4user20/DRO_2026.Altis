_playerFactions = [playersFaction] + (playersFactionAdv select {count _x > 0});
_enemyFactions = [enemyFaction] + (enemyFactionAdv select {count _x > 0});
_playerFactions = _playerFactions apply {toUpper _x};
_enemyFactions = _enemyFactions apply {toUpper _x};

pInfClasses = [];
pOfficerClasses = [];
pCarClasses = [];
pCarNoTurretClasses = [];
pTankClasses = [];
pArtyClasses = [];
pMortarClasses = [];
pHeliClasses = [];
pPlaneClasses = [];
pShipClasses = [];
pAmmoClasses = [];
pGenericNames = [];
pIdentityTypes = [];
pUAVClasses = [];
pInfClassesForWeights = [];
pInfClassWeights = [];
pCarTurretClasses = [];
pStaticClasses = [];
pAAClasses = [];
pAPCClasses = [];

eInfClasses = [];
eOfficerClasses = [];
eCarClasses = [];
eCarNoTurretClasses = [];
eTankClasses = [];
eArtyClasses = [];
eMortarClasses = [];
eHeliClasses = [];
ePlaneClasses = [];
eShipClasses = [];
eAmmoClasses = [];
eGenericNames = [];
eIdentityTypes = [];
eUAVClasses = [];
eInfClassesForWeights = [];
eInfClassWeights = [];
eCarTurretClasses = [];
eStaticClasses = [];
eAAClasses = [];
eAPCClasses = [];

civClasses = [];
civCarClasses = [];

_pInfClassesUnarmed = [];
_pInfClassesUnarmedForWeights = [];
_pInfClassUnarmedWeights = [];
_pInfEditorSubcats = [];

{
	pInfClassesForWeights pushBack [];
	pInfClassWeights pushBack [];
	_pInfClassesUnarmedForWeights pushBack [];
	_pInfClassUnarmedWeights pushBack [];
	_pInfEditorSubcats pushBack [];
} forEach _playerFactions;

_eInfClassesUnarmed = [];
_eInfClassesUnarmedForWeights = [];
_eInfClassUnarmedWeights = [];
_eInfEditorSubcats = [];

{
	eInfClassesForWeights pushBack [];
	eInfClassWeights pushBack [];
	_eInfClassesUnarmedForWeights pushBack [];
	_eInfClassUnarmedWeights pushBack [];
	_eInfEditorSubcats pushBack [];
} forEach _enemyFactions;

diag_log _playerFactions;
diag_log _enemyFactions;

_cfgVeh = configFile >> "CfgVehicles";
private _blockedClassTokens = ["spawner", "module", "logic", "dummy", "placeholder", "_root", "site_", "pook_sam", "pook_", "azncontrol"];
private _blockedSubcatTokens = ["pook_", "samsite", "sam_site", "azncontrol", "module", "logic", "spawner", "control"];
private _isBlockedClass = {params ["_class"]; private _n = toLowerANSI _class; (_blockedClassTokens findIf {(_n find _x) >= 0}) >= 0};
private _isBlockedSubcat = {params ["_subcat"]; if !(_subcat isEqualType "") exitWith {true}; private _n = toLowerANSI _subcat; (_blockedSubcatTokens findIf {(_n find _x) >= 0}) >= 0};
{
	_cfgName = (configName _x);
	_cfgVehName = configFile >> "CfgVehicles" >> _cfgName;
	_thisFac = ((_cfgVeh >> _cfgName >> "faction") call BIS_fnc_GetCfgData);
	if !(_thisFac isEqualType "") then {_thisFac = ""};
	private _classBlocked = [_cfgName] call _isBlockedClass;
	_isCivFaction = (!_classBlocked) && {toUpperANSI _thisFac == toUpperANSI civFaction};
	_isPlayerFaction = (!_classBlocked) && {(toUpperANSI _thisFac) in _playerFactions};
	_isEnemyFaction = (!_classBlocked) && {(toUpperANSI _thisFac) in _enemyFactions};	
	if (_isPlayerFaction OR _isEnemyFaction OR _isCivFaction) then {				
		if (_cfgName isKindOf 'Man') then {	
			if (_isPlayerFaction) then {	
				if (count pGenericNames == 0) then {
					pGenericNames = ((_cfgVehName >> "genericNames") call BIS_fnc_GetCfgData);
					pIdentityTypes = ((_cfgVehName >> "identityTypes") call BIS_fnc_GetCfgData);					
				};
			} else {
				if (_isEnemyFaction) then {
					if (count eGenericNames == 0) then {
						eGenericNames = ((_cfgVehName >> "genericNames") call BIS_fnc_GetCfgData);
						eIdentityTypes = ((_cfgVehName >> "identityTypes") call BIS_fnc_GetCfgData);
					};
				};
			};	
			if ((["officer", _cfgName, false] call BIS_fnc_inString) || (["commander", _cfgName, false] call BIS_fnc_inString)) then {
				if (_isPlayerFaction) then {
					pOfficerClasses pushBack _cfgName;
				};
				if (_isEnemyFaction) then {
					eOfficerClasses pushBack _cfgName;
				};
			} else {					
				if (						
					(["driver", _cfgName, false] call BIS_fnc_inString) ||
					(["diver", _cfgName, false] call BIS_fnc_inString) ||
					(["story", _cfgName, false] call BIS_fnc_inString) ||
					(["competitor", _cfgName, false] call BIS_fnc_inString) ||
					(["survivor", _cfgName, false] call BIS_fnc_inString) ||
					(["unarmed", _cfgName, false] call BIS_fnc_inString) ||
					(["protagonist", _cfgName, false] call BIS_fnc_inString) ||						
					(["_vr_", _cfgName, false] call BIS_fnc_inString) ||
					(["story", ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData), false] call BIS_fnc_inString)						
				) then {
				
				} else {
					if (_isCivFaction) exitWith {
						//diag_log (count ((_cfgVehName >> "weapons") call BIS_fnc_GetCfgData));
						if ((count ((_cfgVehName >> "weapons") call BIS_fnc_GetCfgData)) <= 2) then {							
							civClasses pushBack _cfgName;
						};
					};
					_pFactionIndex = if (_isPlayerFaction) then {							
						(_playerFactions find (toUpper ((_cfgVehName >> "faction") call BIS_fnc_GetCfgData)))
					};
					_eFactionIndex = if (_isEnemyFaction) then {
						(_enemyFactions find (toUpper ((_cfgVehName >> "faction") call BIS_fnc_GetCfgData)))
					};					
					if ((count ((_cfgVehName >> "weapons") call BIS_fnc_GetCfgData) <= 2)) then {
						if (_isPlayerFaction) then {
							_pInfClassesUnarmed pushBack _cfgName;
							(_pInfClassesUnarmedForWeights select _pFactionIndex) pushBack _cfgName;
							(_pInfClassUnarmedWeights select _pFactionIndex) pushBack 0.5;
						};
						if (_isEnemyFaction) then {
							_eInfClassesUnarmed pushBack _cfgName;
							(_eInfClassesUnarmedForWeights select _eFactionIndex) pushBack _cfgName;
							(_eInfClassUnarmedWeights select _eFactionIndex) pushBack 0.5;
						};
					} else {
						if (_isPlayerFaction) then {
							pInfClasses pushBack _cfgName;
						};
						if (_isEnemyFaction) then {
							eInfClasses pushBack _cfgName;
						};							
						_thisWeight = 0;							
						// Check config 'role' value
						_thisRole = ((_cfgVehName >> "role") call BIS_fnc_GetCfgData);
						switch (_thisRole) do {
							case "Crewman": {_thisWeight = 0};
							case "Assistant": {_thisWeight = 0.15};
							case "CombatLifeSaver": {_thisWeight = 0.25};
							case "Grenadier": {_thisWeight = 0.25};
							case "MachineGunner": {_thisWeight = 0.25};
							case "Marksman": {_thisWeight = 0.1};
							case "MissileSpecialist": {_thisWeight = 0.15};
							case "Rifleman": {_thisWeight = 1};
							case "Sapper": {_thisWeight = 0.15};
