params ["_group", ["_enableDynamic", true]];
if (isNull _group) exitWith {_group};
DRO2026_managedGroups pushBackUnique _group;
private _telemetryId = _group getVariable ["DRO2026_telemetryId", ""];
if (_telemetryId == "") then {
    _telemetryId = format ["GRP_%1_%2", side _group, floor random 1000000];
    _group setVariable ["DRO2026_telemetryId", _telemetryId, true];
};
["GROUP", "REGISTERED", createHashMapFromArray [
    ["groupId", _telemetryId], ["side", str side _group], ["units", count units _group],
    ["dynamicSimulation", _enableDynamic]
], 1, _telemetryId, 60] call DRO2026_fnc_telemetryRecord;
_group enableDynamicSimulation _enableDynamic;
if (isServer && {missionNamespace getVariable ["DRO2026_droneAdapterReady", false]}) then {
    [_group] spawn {
        params ["_registeredGroup"];
        uiSleep 1;
        if (!isNull _registeredGroup) then {[_registeredGroup] call DRO2026_fnc_assignDroneLoadout};
    };
};
_group
