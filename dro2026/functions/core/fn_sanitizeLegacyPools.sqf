private _blockedTokens = [
    "spawner", "module", "logic", "dummy", "placeholder", "virtual", "_base", "curator", "site_", "_root",
    "samsite", "sam_site", "azncontrol", "unit_scanner", "pook_sam", "pook_azncontrol"
];
private _blockedSubcatTokens = [
    "samsite", "sam_site", "azncontrol", "module", "logic", "spawner", "control", "unit_scanner", "pook_sam"
];
private _exclusionStats = createHashMap;
private _safeConfigClass = {
    params ["_class", ["_mustBeMan", false]];
    if !(_class isEqualType "") exitWith {false};
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (!isClass _cfg) exitWith {false};
    if (getNumber (_cfg >> "scope") < 2) exitWith {false};
    if (_mustBeMan && {!(_class isKindOf "Man")}) exitWith {false};
    private _name = toLowerANSI _class;
    private _reasonIndex = _blockedTokens findIf {(_name find _x) >= 0};
    if (_reasonIndex >= 0) exitWith {
        private _reason = _blockedTokens select _reasonIndex;
        _exclusionStats set [_reason, (_exclusionStats getOrDefault [_reason, 0]) + 1];
        false
    };
    private _subcat = getText (_cfg >> "editorSubcategory");
    private _subName = toLowerANSI _subcat;
    private _subReasonIndex = _blockedSubcatTokens findIf {(_subName find _x) >= 0};
    if (_subReasonIndex >= 0) exitWith {
        private _reason = format ["subcat:%1", _blockedSubcatTokens select _subReasonIndex];
        _exclusionStats set [_reason, (_exclusionStats getOrDefault [_reason, 0]) + 1];
        false
    };
    true
};

private _filterFlatPool = {
    params ["_name", ["_mustBeMan", false]];
    private _pool = missionNamespace getVariable [_name, []];
    private _before = count _pool;
    _pool = _pool select {[_x, _mustBeMan] call _safeConfigClass};
    missionNamespace setVariable [_name, _pool];
    if (_before != count _pool) then {[format ["Очищен пул %1: %2 -> %3", _name, _before, count _pool]] call DRO2026_fnc_log};
};

{[_x, true] call _filterFlatPool} forEach ["pInfClasses", "eInfClasses", "civClasses", "pOfficerClasses", "eOfficerClasses"];
{[_x, false] call _filterFlatPool} forEach [
    "pCarClasses", "pCarNoTurretClasses", "pCarTurretClasses", "pTankClasses", "pAAClasses", "pStaticClasses",
    "pHeliClasses", "pPlaneClasses", "pUAVClasses", "pArtyClasses", "pMortarClasses", "pAmmoClasses", "pAPCClasses",
    "eCarClasses", "eCarNoTurretClasses", "eCarTurretClasses", "eTankClasses", "eAAClasses", "eStaticClasses",
    "eHeliClasses", "ePlaneClasses", "eUAVClasses", "eArtyClasses", "eMortarClasses", "eAmmoClasses", "eAPCClasses",
    "civCarClasses"
];

// Weighted infantry pools must be filtered together with their weight arrays.
{
    _x params ["_classesName", "_weightsName"];
    private _classSets = missionNamespace getVariable [_classesName, []];
    private _weightSets = missionNamespace getVariable [_weightsName, []];
    for "_setIndex" from 0 to ((count _classSets) - 1) do {
        private _classes = _classSets select _setIndex;
        private _weights = if (_setIndex < count _weightSets) then {_weightSets select _setIndex} else {[]};
        private _safeClasses = [];
        private _safeWeights = [];
        {
            if ([_x, true] call _safeConfigClass) then {
                _safeClasses pushBack _x;
                _safeWeights pushBack (if (_forEachIndex < count _weights) then {_weights select _forEachIndex} else {0.5});
            };
        } forEach _classes;
        _classSets set [_setIndex, _safeClasses];
        if (_setIndex < count _weightSets) then {_weightSets set [_setIndex, _safeWeights]};
    };
    missionNamespace setVariable [_classesName, _classSets];
    missionNamespace setVariable [_weightsName, _weightSets];
} forEach [
    ["pInfClassesForWeights", "pInfClassWeights"],
    ["eInfClassesForWeights", "eInfClassWeights"]
];

// Explicitly strip dangerous editor subcategories if the legacy script left them in local/global arrays.
{
    private _name = _x;
    private _sets = missionNamespace getVariable [_name, []];
    _sets = _sets apply {
        _x select {
            private _n = toLowerANSI _x;
            (_blockedSubcatTokens findIf {(_n find _x) >= 0}) < 0
        }
    };
    missionNamespace setVariable [_name, _sets];
} forEach ["_pInfEditorSubcats", "_eInfEditorSubcats"];

if (count _exclusionStats > 0) then {
    [format ["Legacy pools: исключения по причинам %1", _exclusionStats]] call DRO2026_fnc_log;
};
true