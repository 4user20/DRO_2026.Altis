params [["_reason", "EXPLICIT", [""]]];
if (!isServer) exitWith {false};
DRO2026_assetRegistryInvalidated = true;
DRO2026_supportCatalogReady = false;
DRO2026_supportCatalogSignature = "";
missionNamespace setVariable ["DRO2026_supportCatalogReady", false, true];
["REGISTRY", "INVALIDATED", createHashMapFromArray [["reason", _reason]], _reason] call DRO2026_fnc_logStructured;
true
