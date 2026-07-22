params ["_vehicle", "_side"];
if (isNull _vehicle || {!(_vehicle isKindOf "AllVehicles")}) exitWith {false};
if (!local _vehicle) exitWith {
    ["ROLE","CREW_LOCALITY_REJECTED",createHashMapFromArray [
        ["class",typeOf _vehicle],["netId",netId _vehicle],["owner",owner _vehicle]
    ],"CREW"] call DRO2026_fnc_logStructured;
    false
};
private _crewable =
    count (fullCrew [_vehicle, "driver", true]) > 0 ||
    {count (fullCrew [_vehicle, "gunner", true]) > 0} ||
    {count (fullCrew [_vehicle, "commander", true]) > 0};
if (!_crewable) exitWith {
    DRO2026_managedVehicles pushBackUnique _vehicle;
    _vehicle setVariable ["DRO2026_telemetryOwned", true];
    ["ENTITY", "REGISTERED_UNCREWED", [_vehicle,500,false] call DRO2026_fnc_telemetryObjectSnapshot, 1, netId _vehicle, 0] call DRO2026_fnc_telemetryRecord;
    true
};
private _group = _side createVehicleCrew _vehicle;
if (isNull _group || {count crew _vehicle == 0}) exitWith {
    ["ENTITY", "CREW_CREATION_FAILED", createHashMapFromArray [["class",typeOf _vehicle],["netId",netId _vehicle],["side",str _side]], 1, typeOf _vehicle, 0] call DRO2026_fnc_telemetryRecord;
    deleteVehicleCrew _vehicle;
    if (!isNull _group) then {deleteGroup _group};
    deleteVehicle _vehicle;
    false
};
_group addVehicle _vehicle;
[_group, false] call DRO2026_fnc_registerManagedGroup;
DRO2026_managedVehicles pushBackUnique _vehicle;
_vehicle setVariable ["DRO2026_telemetryOwned", true];
["ENTITY", "CREW_CREATED", [_vehicle,500,false] call DRO2026_fnc_telemetryObjectSnapshot, 1, netId _vehicle, 0] call DRO2026_fnc_telemetryRecord;
true
