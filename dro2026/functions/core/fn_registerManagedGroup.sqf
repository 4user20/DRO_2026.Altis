params ["_group", ["_enableDynamic", true]];
if (isNull _group) exitWith {_group};
DRO2026_managedGroups pushBackUnique _group;
_group enableDynamicSimulation _enableDynamic;
if ((_group getVariable ["DRO2026_groupId", ""]) == "") then {
    private _sequence = (missionNamespace getVariable ["DRO2026_groupSequence", 0]) + 1;
    missionNamespace setVariable ["DRO2026_groupSequence", _sequence];
    _group setVariable ["DRO2026_groupId", format ["GRP_%1", _sequence], true];
    _group setVariable ["DRO2026_groupHome", getPosATL leader _group];
    _group setVariable ["DRO2026_commandOwner", "DIRECTOR", true];
    _group setVariable ["DRO2026_commandLeaseUntil", -1, true];
    _group setVariable ["DRO2026_commandRevision", 0, true];
};
_group
