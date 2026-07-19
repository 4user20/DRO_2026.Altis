private _normalizeFactionList = {
	params ["_values"];
	if !(_values isEqualType []) exitWith {[]};
	_values select {_x isEqualType "" && {_x != ""}}
};
if (isNil "playersFactionAdv") then {playersFactionAdv = []};
if (isNil "enemyFactionAdv") then {enemyFactionAdv = []};
playersFactionAdv = [playersFactionAdv] call _normalizeFactionList;
enemyFactionAdv = [enemyFactionAdv] call _normalizeFactionList;

_playerFactions = ([playersFaction] + playersFactionAdv) select {_x isEqualType "" && {_x != ""}};
_enemyFactions = ([enemyFaction] + enemyFactionAdv) select {_x isEqualType "" && {_x != ""}};
_playerFactions = _playerFactions apply {toUpperANSI _x};
_enemyFactions = _enemyFactions apply {toUpperANSI _x};
private _debugFactionScan = missionNamespace getVariable ["DRO2026_DEBUG", false];

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

if (_debugFactionScan) then {
	diag_log format ["DRO: player factions = %1", _playerFactions];
	diag_log format ["DRO: enemy factions = %1", _enemyFactions];
};

_cfgVeh = configFile >> "CfgVehicles";
// Block only classes with known editor/spawner/SAM side effects. A broad `pook_` token
// would incorrectly remove otherwise valid Pook aircraft, vehicles and infantry.
private _blockedClassTokens = [
	"spawner", "module", "logic", "dummy", "placeholder", "_root", "site_",
	"samsite", "sam_site", "azncontrol", "unit_scanner", "pook_sam", "pook_azncontrol"
];
private _blockedSubcatTokens = [
	"samsite", "sam_site", "azncontrol", "module", "logic", "spawner", "control", "unit_scanner", "pook_sam"
];
private _blockedClassStats = createHashMap;
private _blockedSubcatStats = createHashMap;
private _blockedClassCount = 0;
private _blockedSubcatCount = 0;
private _blockReason = {
	params ["_value", "_tokens"];
	if !(_value isEqualType "") exitWith {"non_string"};
	private _name = toLowerANSI _value;
	private _index = _tokens findIf {(_name find _x) >= 0};
	if (_index < 0) exitWith {""};
	_tokens select _index
};
private _isBlockedClass = {
	params ["_class"];
	private _reason = [_class, _blockedClassTokens] call _blockReason;
	if (_reason == "") exitWith {false};
	_blockedClassCount = _blockedClassCount + 1;
	_blockedClassStats set [_reason, (_blockedClassStats getOrDefault [_reason, 0]) + 1];
	true
};
private _isBlockedSubcat = {
	params ["_subcat"];
	private _reason = [_subcat, _blockedSubcatTokens] call _blockReason;
	if (_reason == "") exitWith {false};
	_blockedSubcatCount = _blockedSubcatCount + 1;
	_blockedSubcatStats set [_reason, (_blockedSubcatStats getOrDefault [_reason, 0]) + 1];
	true
};
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
						if ((count ((_cfgVehName >> "weapons") call BIS_fnc_GetCfgData)) <= 2) then {							
							civClasses pushBack _cfgName;
						};
					};
					_pFactionIndex = if (_isPlayerFaction) then {							
						(_playerFactions find (toUpperANSI ((_cfgVehName >> "faction") call BIS_fnc_GetCfgData)))
					};
					_eFactionIndex = if (_isEnemyFaction) then {
						(_enemyFactions find (toUpperANSI ((_cfgVehName >> "faction") call BIS_fnc_GetCfgData)))
					};					
					if ((count ((_cfgVehName >> "weapons") call BIS_fnc_GetCfgData) <= 2)) then {
						if (_isPlayerFaction && {_pFactionIndex >= 0}) then {
							_pInfClassesUnarmed pushBack _cfgName;
							(_pInfClassesUnarmedForWeights select _pFactionIndex) pushBack _cfgName;
							(_pInfClassUnarmedWeights select _pFactionIndex) pushBack 0.5;
						};
						if (_isEnemyFaction && {_eFactionIndex >= 0}) then {
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