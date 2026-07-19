_playersIndex = lbCurSel 1301;
_enemyIndex = lbCurSel 1311;
_civIndex = lbCurSel 1321;
_playersFaction = lbData [1301, _playersIndex];
_enemyFaction = lbData [1311, _enemyIndex];

_playersSideNum = ((configFile >> "CfgFactionClasses" >> _playersFaction >> "side") call BIS_fnc_GetCfgData);
_enemySideNum = ((configFile >> "CfgFactionClasses" >> _enemyFaction >> "side") call BIS_fnc_GetCfgData);
			
playersFaction = "";
if ((lbData [1301, _playersIndex]) == "RANDOM") then {			
	playersFaction = lbData [1301, ([1, lbSize 1301] call BIS_fnc_randomInt)];
	profileNamespace setVariable ["DRO_playersFaction", "RANDOM"];
} else {
	playersFaction = lbData [1301, _playersIndex];
	profileNamespace setVariable ["DRO_playersFaction", playersFaction];
};		
publicVariable "playersFaction";		
playersFactionAdv = [lbData [3800, lbCurSel 3800], lbData [3801, lbCurSel 3801], lbData [3802, lbCurSel 3802]] select {
	_x isEqualType "" && {_x != ""} && {_x != "0"}
};
publicVariable "playersFactionAdv";			

if ((lbData [1311, _enemyIndex]) == "RANDOM") then {			
	enemyFaction = lbData [1311, ([1, lbSize 1311] call BIS_fnc_randomInt)];
	profileNamespace setVariable ["DRO_enemyFaction", "RANDOM"];
} else {
	enemyFaction = lbData [1311, _enemyIndex];
	profileNamespace setVariable ["DRO_enemyFaction", enemyFaction];
};
publicVariable "enemyFaction";		
enemyFactionAdv = [lbData [3803, lbCurSel 3803], lbData [3804, lbCurSel 3804], lbData [3805, lbCurSel 3805]] select {
	_x isEqualType "" && {_x != ""} && {_x != "0"}
};
publicVariable "enemyFactionAdv";

civFaction = lbData [1321, _civIndex];
publicVariable "civFaction";		

if (missionNamespace getVariable ["DRO2026_DEBUG", false]) then {
	diag_log format ["DRO: okAO player=%1 players=%2 adv=%3 enemy=%4 adv=%5", player, playersFaction, playersFactionAdv, enemyFaction, enemyFactionAdv];
};

missionNameSpace setVariable ["factionsChosen", 1, true];

aiMultiplier = (round (((sliderPosition 2041)/10) * (10 ^ 1)) / (10 ^ 1));
publicVariable "aiMultiplier";

if (('FORTIFY' in preferredObjectives) || ('DISARM' in preferredObjectives) || ('PROTECTCIV' in preferredObjectives)) then {
	neutralTasksChosen = true
} else {
	if (count preferredObjectives > 0) then {
		noNeutralTasksChosen = true;
	};
};

hintSilent "";
closeDialog 1;				
[toUpper "Please wait while mission is generated", "objectivesSpawned", 1, ""] call sun_callLoadScreen;