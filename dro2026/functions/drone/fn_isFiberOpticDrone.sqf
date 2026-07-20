params [["_subject", objNull]];
private _class = "";
if (_subject isEqualType objNull) then {
    if (isNull _subject) exitWith {false};
    _class = typeOf _subject;
} else {
    if (_subject isEqualType "") then {_class = _subject};
};
if (_class == "") exitWith {false};

private _lower = toLowerANSI _class;
private _patternMatch = (_lower find "frtz_") == 0 && {(_lower find "_kvn_") >= 0};
if (_patternMatch) exitWith {true};

private _registeredFiber = false;
if (missionNamespace getVariable ["DRO2026_droneRegistryInitialized", false]) then {
    private _metadata = DRO2026_droneClassMetadata getOrDefault [_class, createHashMap];
    _registeredFiber = _metadata getOrDefault ["fiberOptic", false];
};
if (_registeredFiber) exitWith {true};

private _cfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg) exitWith {false};
private _baseA = configFile >> "CfgVehicles" >> "frtz_drone_kvn_base_F";
private _baseB = configFile >> "CfgVehicles" >> "frtz_KVN_Base";
(isClass _baseA && {_class isKindOf "frtz_drone_kvn_base_F"}) ||
{isClass _baseB && {_class isKindOf "frtz_KVN_Base"}}
