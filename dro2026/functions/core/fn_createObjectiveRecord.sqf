params ["_taskName", "_description", "_title", "_markerName", "_taskType", "_position", ["_reconChance", 0.35], ["_subTasks", []], ["_meta", createHashMap]];
missionNamespace setVariable [format ["%1Completed", _taskName], 0, true];
missionNamespace setVariable [format ["%1_taskType", _taskName], _taskType, true];
allObjectives pushBackUnique _taskName;

// Legacy start.sqf replaces entries with reconTask.sqf when this value is >= baseReconChance.
// D26 operations already have a dedicated ISR_RECON objective and must remain concrete/direct.
private _effectiveReconChance = if ((toUpperANSI _taskName find "D26_") == 0) then {-1} else {_reconChance};
objData pushBack [
    _taskName, _description, _title, _markerName, _taskType,
    _position, _effectiveReconChance, _subTasks
];
DRO2026_objectiveMeta set [_taskName, _meta];
[format ["Создана прямая задача %1 (%2)", _title, _taskName]] call DRO2026_fnc_log;
_taskName
