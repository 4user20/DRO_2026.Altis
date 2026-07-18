params ["_group", ["_enableDynamic", true]];
if (isNull _group) exitWith {_group};
DRO2026_managedGroups pushBackUnique _group;
_group enableDynamicSimulation _enableDynamic;
_group
