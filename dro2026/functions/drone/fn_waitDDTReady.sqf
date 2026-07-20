params [["_timeout", 30], ["_pollInterval", 0.25]];
if (!isServer) exitWith {false};
if !(call DRO2026_fnc_hasDDT) exitWith {false};

private _deadline = diag_tickTime + (_timeout max 0);
missionNamespace setVariable ["ddtDeploySides", [], true];
missionNamespace setVariable ["ddtCycleUnassigned", -1, true];
waitUntil {
    // DDT postInit may apply Eden/CBA settings before setting ddtReady. Keep its unsafely local scanners inert.
    missionNamespace setVariable ["ddtDeploySides", [], true];
    missionNamespace setVariable ["ddtCycleUnassigned", -1, true];
    uiSleep (_pollInterval max 0.05);
    (missionNamespace getVariable ["ddtReady", false]) ||
    {diag_tickTime >= _deadline} ||
    {missionNamespace getVariable ["DRO2026_missionEnding", false]}
};
missionNamespace getVariable ["ddtReady", false]
