params [["_drone", objNull]];
if (isNull _drone) exitWith {false};
if (_drone getVariable ["DRO2026_manualControl", false]) exitWith {true};
if (_drone getVariable ["DRO2026_zeusControlled", false]) exitWith {true};
private _zeusOwner = _drone getVariable ["BIS_fnc_moduleRemoteControl_owner", objNull];
if (!isNull _zeusOwner) exitWith {true};
isUAVConnected _drone
