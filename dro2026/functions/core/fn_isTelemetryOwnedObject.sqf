params [["_object", objNull, [objNull]]];
if (isNull _object) exitWith {false};
if (_object getVariable ["DRO2026_telemetryOwned", false]) exitWith {true};
if (_object in (missionNamespace getVariable ["DRO2026_managedVehicles", []])) exitWith {true};
if (_object in (missionNamespace getVariable ["DRO2026_activeDrones", []])) exitWith {true};
if (_object in (missionNamespace getVariable ["DRO2026_activeStrategicMunitions", []] apply {_x getOrDefault ["object", objNull]})) exitWith {true};
private _identityVariables = [
    "DRO2026_siteId", "DRO2026_networkNodeId", "DRO2026_contactId",
    "DRO2026_stableSubjectId", "DRO2026_flightAuthority"
];
(_identityVariables findIf {
    private _value = _object getVariable [_x, ""];
    (_value isEqualType "" && {_value != ""}) || {_value isEqualType 0 && {_value != 0}}
}) >= 0
