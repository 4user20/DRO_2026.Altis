params ["_taskName", "_description", "_title", "_markerName", "_taskType", "_position", ["_reconChance", 0.35], ["_subTasks", []], ["_meta", createHashMap]];
missionNamespace setVariable [format ["%1Completed", _taskName], 0, true];
missionNamespace setVariable [format ["%1_taskType", _taskName], _taskType, true];
allObjectives pushBack _taskName;
objData pushBack [_taskName, _description, _title, _markerName, _taskType, _position, _reconChance, _subTasks];
DRO2026_objectiveMeta set [_taskName, _meta];
[format ["Создана задача %1 (%2)", _title, _taskName]] call DRO2026_fnc_log;
_taskName
