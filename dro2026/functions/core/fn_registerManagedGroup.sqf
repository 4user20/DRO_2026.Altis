params ["_group", ["_enableDynamic", true]];
if (isNull _group) exitWith {_group};
DRO2026_managedGroups pushBackUnique _group;
_group enableDynamicSimulation _enableDynamic;
if (isServer && {missionNamespace getVariable ["DRO2026_droneAdapterReady", false]}) then {
    [_group] spawn {
        params ["_registeredGroup"];
        uiSleep 1;
        if (!isNull _registeredGroup) then {[_registeredGroup] call DRO2026_fnc_assignDroneLoadout};
    };
};
_group
