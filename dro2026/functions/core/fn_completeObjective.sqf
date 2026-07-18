params ["_taskName", ["_voice", "TASK_COMPLETE"], ["_resourceChanges", []]];
if ((missionNamespace getVariable [format ["%1Completed", _taskName], 0]) == 1) exitWith {};
missionNamespace setVariable [format ["%1Completed", _taskName], 1, true];
[_taskName, "SUCCEEDED", true] spawn BIS_fnc_taskSetState;
{
    _x params ["_key", "_delta"];
    private _current = DRO2026_resources getOrDefault [_key, 0];
    DRO2026_resources set [_key, (((_current + _delta) max 0) min 100)];
} forEach _resourceChanges;
[_voice] call DRO2026_fnc_hqVoice;
if (DRO2026_AUTO_SAVE) then {saveGame};
