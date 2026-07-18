params ["_objectivePos", "_thisTask", ["_reinfType", 1]];

// DRO2026 tasks own their completion, voice and reaction lifecycle. Do not attach legacy extras or reinforcements.
if ((toUpperANSI _thisTask find "D26_") == 0) exitWith {};

// Add cancel button to task
_taskData = [_thisTask] call BIS_fnc_taskDescription;
_taskDesc = (_taskData select 0) select 0;
_taskTitle = _taskData select 1;
_taskMarker = _taskData select 2;
_taskDescNew = format ["%1<br /><br /><execute expression='[""%2"", ""CANCELED"", true] spawn BIS_fnc_taskSetState;'>Cancel task</execute>", _taskDesc, _thisTask];

[_thisTask, [_taskDescNew, _taskTitle, _taskMarker]] call BIS_fnc_taskSetDescription;



// Add task ends
switch (_reinfType) do {
	case 0: {
		// No reinforcements
		waitUntil {
			sleep 10;
			[_thisTask] call BIS_fnc_taskCompleted			
		};
		if (reactiveChance > 0.85) then {
			diag_log "DRO: Creating reactive task";
			reactiveChance = 0;
			_thisObj = [] call fnc_selectReactiveObjective;
		} else {
			["TASK_SUCCEED"] spawn dro_sendProgressMessage;
		};		
	};
	case 1: {
		// Regular reinforce
		[_objectivePos, _thisTask] spawn {
			params ["_objectivePos", "_thisTask"];
			waitUntil {
				sleep 10;
				[_thisTask] call BIS_fnc_taskCompleted
			};
			if (reactiveChance > 0.85) then {
				diag_log "DRO: Creating reactive task";
				reactiveChance = 0;
				_thisObj = [] call fnc_selectReactiveObjective;
			} else {
				["TASK_SUCCEED"] spawn dro_sendProgressMessage;
			};
			reinforceChance = ((reinforceChance + 0.1) * aiMultiplier);
			if (!(missionNamespace getVariable ["DRO2026_DISABLE_LEGACY_REINFORCEMENTS", false]) && {(random 1) < reinforceChance}) then {
				if (!stealthActive && enemyCommsActive) then {
					[_objectivePos, [1,2]] execVM 'sunday_system\reinforce.sqf';
				};
			};
		};
	};
	case 2: {
		// Ambush
		[_objectivePos, _thisTask] spawn {
			params ["_objectivePos", "_thisTask"];
			waitUntil {
				sleep 10;
				[_thisTask] call BIS_fnc_taskCompleted
			};			
			sleep 5;
			_ambushGroup = [_objectivePos] call dro_triggerAmbushSpawn;
			if (!isNull _ambushGroup) then {
				["AMBUSH"] spawn dro_sendProgressMessage;
			};				
		};
	};
	case 3: {		
		// No success message
		waitUntil {
			sleep 10;
			[_thisTask] call BIS_fnc_taskCompleted			
		};
		if (reactiveChance > 0.85) then {
			diag_log "DRO: Creating reactive task";
			reactiveChance = 0;
			_thisObj = [] call fnc_selectReactiveObjective;
		};		
	};
	case 4: {
		// Nothing at all!
		
	};
};


