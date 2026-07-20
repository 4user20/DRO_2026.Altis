params ["_source", ["_range", 2200], ["_sourceHint", ""]];
if (!isServer) exitWith {0};

private _observer = objNull;
private _observerSide = sideUnknown;
if (_source isEqualType grpNull) then {
    if (isNull _source || {count units _source == 0}) exitWith {0};
    _observer = leader _source;
    _observerSide = side _source;
} else {
    if !(_source isEqualType objNull) exitWith {0};
    if (isNull _source || {!alive _source} || {!simulationEnabled _source}) exitWith {0};
    _observer = _source;
    if (!isNull driver _source) then {_observerSide = side (group (driver _source))} else {_observerSide = side _source};
};
if (isNull _observer || {!alive _observer}) exitWith {0};
if (_observerSide == civilian || {_observerSide == sideUnknown}) exitWith {0};

private _owner = if (_observerSide == playersSide) then {"PLAYER"} else {if (_observerSide == enemySide) then {"ENEMY"} else {""}};
if (_owner == "") exitWith {0};
private _targets = _observer targets [true, _range max 300];
private _count = 0;
{
    private _target = _x;
    if (!isNull _target && {alive _target} && {_target != _observer}) then {
        private _targetSide = side _target;
        if (!isNull driver _target) then {_targetSide = side (group (driver _target))};
        if ((_observerSide getFriend _targetSide) < 0.6) then {
            private _knowledge = _observer knowsAbout _target;
            if (_knowledge > 1.05) then {
                private _classLower = toLowerANSI typeOf _observer;
                private _fiber = [_observer] call DRO2026_fnc_isFiberOpticDrone;
                private _thermal = (_classLower find "_ti") >= 0;
                private _sourceName = toUpperANSI _sourceHint;
                if (_sourceName == "") then {
                    if (_fiber) then {
                        _sourceName = if (_thermal) then {"UAV_FIBEROPTIC_TI"} else {if ((_classLower find "_at") >= 0) then {"UAV_FIBEROPTIC_AT"} else {"UAV_FIBEROPTIC_AP"}};
                    } else {
                        private _metadata = DRO2026_droneClassMetadata getOrDefault [typeOf _observer, createHashMap];
                        private _category = _metadata getOrDefault ["category", ""];
                        if ((_category find "FPV_") == 0) then {
                            _sourceName = "UAV_FPV";
                        } else {
                            if (_category == "BOMBER") then {
                                _sourceName = "UAV_BOMBER";
                            } else {
                                private _ddtFPV = missionNamespace getVariable ["ddtClassesFPV", []];
                                private _ddtAT = missionNamespace getVariable ["ddtClassesFPVAT", []];
                                private _ddtBomber = missionNamespace getVariable ["ddtClassesBomber", []];
                                if ((typeOf _observer) in (_ddtFPV + _ddtAT)) then {
                                    _sourceName = "UAV_FPV";
                                } else {
                                    _sourceName = if ((typeOf _observer) in _ddtBomber) then {"UAV_BOMBER"} else {if (_observer getVariable ["ddtTasked", false]) then {"UAV_RECON"} else {"GROUND_AI"}};
                                };
                            };
                        };
                    };
                };
                private _confidence = linearConversion [1.05, 4, _knowledge, 0.38, 0.94, true];
                if (_thermal && {(sunOrMoon < 0.35) || {fog > 0.35} || {rain > 0.45}}) then {_confidence = (_confidence + 0.07) min 0.97};
                private _uncertainty = linearConversion [1.05, 4, _knowledge, 260, 38, true];
                private _classification = if (_target isKindOf "Man") then {"INFANTRY"} else {
                    if (_target isKindOf "Tank" || {_target isKindOf "Wheeled_APC_F"} || {_target isKindOf "Tracked_APC_F"}) then {"ARMOR"} else {
                        if (_target isKindOf "StaticWeapon") then {"STATIC"} else {"VEHICLE"}
                    }
                };
                private _contact = [_owner, _target, getPosATL _target, _confidence, _classification, _sourceName, _uncertainty] call DRO2026_fnc_addContact;
                if (count _contact > 0) then {
                    _contact set ["targetSide", str _targetSide];
                    _contact set ["observationSource", typeOf _observer];
                    _contact set ["fiberOptic", _fiber];
                    _count = _count + 1;
                };
            };
        };
    };
} forEach _targets;
_count
