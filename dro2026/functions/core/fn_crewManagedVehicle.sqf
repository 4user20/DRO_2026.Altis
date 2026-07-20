params ["_vehicle", "_side"];
if (isNull _vehicle || {!(_vehicle isKindOf "AllVehicles")}) exitWith {false};
private _crewable =
    count (fullCrew [_vehicle, "driver", true]) > 0 ||
    {count (fullCrew [_vehicle, "gunner", true]) > 0} ||
    {count (fullCrew [_vehicle, "commander", true]) > 0};
if (!_crewable) exitWith {
    DRO2026_managedVehicles pushBackUnique _vehicle;
    true
};
private _group = _side createVehicleCrew _vehicle;
if (isNull _group || {count crew _vehicle == 0}) exitWith {
    deleteVehicleCrew _vehicle;
    if (!isNull _group) then {deleteGroup _group};
    deleteVehicle _vehicle;
    false
};
[_group, false] call DRO2026_fnc_registerManagedGroup;
DRO2026_managedVehicles pushBackUnique _vehicle;
true
