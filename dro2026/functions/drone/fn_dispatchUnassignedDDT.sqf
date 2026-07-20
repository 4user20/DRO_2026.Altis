params [["_maxTakeovers", 2]];
if (!isServer) exitWith {0};
if !(missionNamespace getVariable ["DRO2026_DDT_ENABLE_UNASSIGNED", false]) exitWith {0};
if !(missionNamespace getVariable ["DRO2026_ddtConfigured", false]) exitWith {0};
if !(missionNamespace getVariable ["ddtReady", false]) exitWith {0};

private _ownedSides = missionNamespace getVariable ["DRO2026_ddtDeploySides", []];
private _script = "DrongosDroneTweaks\Scripts\Drones\AI_Unassigned.sqf";
private _taken = 0;
{
    private _drone = _x;
    if (_taken >= _maxTakeovers) exitWith {};
    private _crewGroup = group (driver _drone);
    private _droneSide = if (!isNull _crewGroup) then {side _crewGroup} else {side _drone};
    if (!isNull _drone && {alive _drone} && {_drone isKindOf "Air"} && {simulationEnabled _drone} &&
        {_droneSide in _ownedSides} && {(sizeOf typeOf _drone) <= 5} &&
        {!(_drone getVariable ["ddtTasked", false])} && {!(_drone getVariable ["ddtExclude", false])} &&
        {!(_drone getVariable ["DRO2026_ownedFPV", false])} && {!(_drone getVariable ["dro2026_fpvInitialized", false])} &&
        {(crew _drone) findIf {isPlayer _x} < 0} && {!([_drone] call DRO2026_fnc_isExternallyControlledUAV)}) then {
        // Reserve before execVM so no concurrent server pass can double-task the UAV.
        _drone setVariable ["ddtTasked", true, true];
        [_drone] execVM _script;
        _taken = _taken + 1;
    };
} forEach allUnitsUAV;
_taken
