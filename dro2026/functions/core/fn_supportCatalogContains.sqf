params [["_mode", "", [""]], ["_class", "", [""]]];
private _catalog = missionNamespace getVariable ["DRO2026_supportCatalog", []];
if !(_catalog isEqualType []) exitWith {false};
(_catalog findIf {
    _x isEqualType createHashMap &&
    {(_x getOrDefault ["mode",""]) == _mode} &&
    {_class == "" || {(_x getOrDefault ["assetClass",""]) == _class}}
}) >= 0
