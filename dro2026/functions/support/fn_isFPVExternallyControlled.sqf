/* Clean-room helper: only documented engine state, no source copied from fpv_ai_drones.pbo. */
params ["_drone"];
if (isNull _drone) exitWith {false};
if (_drone getVariable ["DRO2026_manualControl", false]) exitWith {true};
if (isUAVConnected _drone) exitWith {true};
private _zeusOwner = _drone getVariable ["bis_fnc_moduleRemoteControl_owner", objNull];
!isNull _zeusOwner
