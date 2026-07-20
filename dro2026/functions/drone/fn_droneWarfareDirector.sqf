if (!isServer) exitWith {};
if (missionNamespace getVariable ["DRO2026_droneWarfareDirectorStarted", false]) exitWith {};
missionNamespace setVariable ["DRO2026_droneWarfareDirectorStarted", true];
if !(missionNamespace getVariable ["DRO2026_DRONE_ADAPTER_ENABLED", true]) exitWith {};

[] call DRO2026_fnc_initializeDroneRegistry;
private _ddtPresent = call DRO2026_fnc_hasDDT;
private _ddtReady = false;
if (_ddtPresent) then {
    _ddtReady = [missionNamespace getVariable ["DRO2026_DDT_READY_TIMEOUT", 30], 0.25] call DRO2026_fnc_waitDDTReady;
    if (_ddtReady) then {[] call DRO2026_fnc_configureDDT} else {["DDT detected but ddtReady timed out; retaining DRO fallback"] call DRO2026_fnc_log};
} else {
    ["DDT not loaded; retaining existing DRO drone fallback"] call DRO2026_fnc_log;
};

while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _now = time;
    if (_ddtReady && {(_now - DRO2026_lastDroneAssignmentPass) >= (missionNamespace getVariable ["DRO2026_DRONE_ASSIGNMENT_CYCLE", 60])}) then {
        DRO2026_lastDroneAssignmentPass = _now;
        private _processed = 0;
        {
            if (_processed < 8 && {[_x] call DRO2026_fnc_assignDroneLoadout}) then {_processed = _processed + 1};
        } forEach DRO2026_managedGroups;
        [3] call DRO2026_fnc_dispatchDDTDrones;
    };

    if ((_now - DRO2026_lastDroneIntelPass) >= (missionNamespace getVariable ["DRO2026_DRONE_INTEL_CYCLE", 45])) then {
        DRO2026_lastDroneIntelPass = _now;
        private _drones = DRO2026_activeDrones select {!isNull _x && {alive _x} && {simulationEnabled _x}};
        if (_ddtReady) then {
            {
                if (_x getVariable ["ddtTasked", false]) then {_drones pushBackUnique _x};
            } forEach allUnitsUAV;
        };
        {
            [_x, missionNamespace getVariable ["DRO2026_DRONE_INTEL_RANGE", 2200]] call DRO2026_fnc_collectDroneIntel;
        } forEach _drones;
    };

    if ((_now - DRO2026_lastDroneInfosharePass) >= (missionNamespace getVariable ["DRO2026_DRONE_INFOSHARE_CYCLE", 60])) then {
        DRO2026_lastDroneInfosharePass = _now;
        [missionNamespace getVariable ["DRO2026_DRONE_INFOSHARE_RANGE", 1800], 24] call DRO2026_fnc_shareDroneIntel;
    };

    if (_ddtReady && {missionNamespace getVariable ["DRO2026_DDT_ENABLE_UNASSIGNED", false]} &&
        {(_now - DRO2026_lastDroneUnassignedPass) >= (missionNamespace getVariable ["DRO2026_DDT_UNASSIGNED_CYCLE", 60])}) then {
        DRO2026_lastDroneUnassignedPass = _now;
        [2] call DRO2026_fnc_dispatchUnassignedDDT;
    };
    uiSleep 5;
};
