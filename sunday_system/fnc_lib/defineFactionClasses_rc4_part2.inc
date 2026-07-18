							case "SpecialOperative": {_thisWeight = 0.15};
							default {_thisWeight = 0.5};
						};						
						// Overwrite weight if certain words appear in unit name
						_thisDisplayName = ((_cfgVehName >> "displayName") call BIS_fnc_GetCfgData);
						{
							if (([(_x select 0), _thisDisplayName, false] call BIS_fnc_inString)) exitWith {
								_thisWeight = (_x select 1);
							};
						} forEach [
							["medic", 0.25],
							["grenadier", 0.25],
							["machine", 0.25],
							["auto", 0.25],
							["sniper", 0.1],
							["marksman", 0.1],
							["spotter", 0.1],
							["sharp", 0.1],
							["asst.", 0.15],
							["missile", 0.15],
							["AT", 0.15],
							["AA", 0.15],
							["special", 0.15],
							["leader", 0.15],
							["gunner", 0.15],
							["ammo", 0.15],
							["uav", 0.1],
							["engineer", 0.1],
							["pilot", 0],
							["crew", 0]
						];						
						if (_isPlayerFaction) then {
							(pInfClassesForWeights select _pFactionIndex) pushBack _cfgName;
							(pInfClassWeights select _pFactionIndex) pushBack _thisWeight;
							private _subcat = ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData);
							if !([_subcat] call _isBlockedSubcat) then {(_pInfEditorSubcats select _pFactionIndex) pushBackUnique _subcat};
						};
						if (_isEnemyFaction) then {
							(eInfClassesForWeights select _eFactionIndex) pushBack _cfgName;
							(eInfClassWeights select _eFactionIndex) pushBack _thisWeight;
							private _subcat = ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData);
							if !([_subcat] call _isBlockedSubcat) then {(_eInfEditorSubcats select _eFactionIndex) pushBackUnique _subcat};
						};
					};
				};					
			};
		} else {
			_checkSubcats = true;
			if (_cfgName isKindOf 'Car') then {
				if (_isCivFaction) exitWith {
					civCarClasses pushBack _cfgName;					
				};
				_edSubcat = ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData);
				if (!isNil "_edSubcat") then {
					if (_edSubcat == "EdSubcat_Drones") then {
						
					} else {
						if (_edSubcat == "EdSubcat_APCs") then {
							if (_isPlayerFaction) then {
								pAPCClasses pushBackUnique _cfgName;								
							};
							if (_isEnemyFaction) then {
								eAPCClasses pushBackUnique _cfgName;								
							};
						} else {
							if (_isPlayerFaction) then {
								pCarClasses pushBackUnique _cfgName;
								if (count ([_cfgName, false] call BIS_fnc_allTurrets) > 0) then {
									pCarTurretClasses pushBackUnique _cfgName;
								} else {
									pCarNoTurretClasses pushBackUnique _cfgName;
								};								
							};
							if (_isEnemyFaction) then {
								eCarClasses pushBackUnique _cfgName;
								if (count ([_cfgName, false] call BIS_fnc_allTurrets) > 0) then {
									eCarTurretClasses pushBackUnique _cfgName;
								} else {
									eCarNoTurretClasses pushBackUnique _cfgName;
								};								
							};
						};
						_checkSubcats = false;
						/*
						{
							if ((configName _x) == "Turrets") then {						
								_turretCfg = ([(_cfgVehName >> "Turrets"), 0, true] call BIS_fnc_returnChildren);						
								if (count _turretCfg > 0) then {									
									_noTurret = 0;
									{										
										if (((_cfgVehName >> "Turrets" >> (configName _x) >> "gun") call BIS_fnc_GetCfgData) == "mainGun") then {
											_noTurret = 1;
											if (_isPlayerFaction) then {
												pCarTurretClasses pushBackUnique _cfgName;
											};
											if (_isEnemyFaction) then {
												eCarTurretClasses pushBackUnique _cfgName;
											};
										};
									} forEach _turretCfg;
									if (_noTurret == 0) then {
										if (_isPlayerFaction) then {
											pCarNoTurretClasses pushBackUnique _cfgName;
										};
										if (_isEnemyFaction) then {
											eCarNoTurretClasses pushBackUnique _cfgName;
										};
									};
								} else {
									if (_isPlayerFaction) then {
										pCarNoTurretClasses pushBackUnique _cfgName;
									};
									if (_isEnemyFaction) then {
										eCarNoTurretClasses pushBackUnique _cfgName;
									};
								};
							};
							
						} forEach ([(configFile >> "CfgVehicles" >> _cfgName), 0, true] call BIS_fnc_returnChildren);
						*/
					};
				};								
			} else {
				if (_cfgName isKindOf 'Tank') then {
					_edSubcat = ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData);
					if (
						!(["artillery", ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData), false] call BIS_fnc_inString) &&
						!(["aa", ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData), false] call BIS_fnc_inString) &&
						!(["drone", ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData), false] call BIS_fnc_inString) 
					) then {
						if (_isPlayerFaction) then {
							pTankClasses pushBackUnique _cfgName;
						};
						if (_isEnemyFaction) then {
							eTankClasses pushBackUnique _cfgName;
						};
						_checkSubcats = false;
					};					
				};
			};
			if (_checkSubcats) then {
				_edSubcat = ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData);
				if (!isNil "_edSubcat") then {	
					_pVars = [pArtyClasses, pAAClasses, pTankClasses, pTankClasses, pHeliClasses, pPlaneClasses, pShipClasses, pUAVClasses];
					_eVars = [eArtyClasses, eAAClasses, eTankClasses, eTankClasses, eHeliClasses, ePlaneClasses, eShipClasses, eUAVClasses];
					{						
						if ( [_x, ((_cfgVehName >> "editorSubcategory") call BIS_fnc_GetCfgData), false] call BIS_fnc_inString ) exitWith {
							if (_isPlayerFaction) then {
								(_pVars select _forEachIndex) pushBackUnique _cfgName;
							};
							if (_isEnemyFaction) then {
								(_eVars select _forEachIndex) pushBackUnique _cfgName;
							};
						};
					} forEach ["artillery", "aa", "tank", "apc", "helicopter", "plane", "boat", "drone"];					
				};				
				_pVars = [pMortarClasses, pStaticClasses, pStaticClasses, pAmmoClasses];
				_eVars = [eMortarClasses, eStaticClasses, eStaticClasses, eAmmoClasses];
				{						
					if (_cfgName isKindOf 'StaticMortar') exitWith {
						if (_isPlayerFaction) then {
							(_pVars select _forEachIndex) pushBackUnique _cfgName;
						};
						if (_isEnemyFaction) then {
							(_eVars select _forEachIndex) pushBackUnique _cfgName;
						};
					};
				} forEach ["StaticMortar", "StaticMGWeapon", "StaticGrenadeLauncher", "ReammoBox_F"];			
			};
		};
	};
