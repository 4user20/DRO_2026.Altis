params ["_message", ["_requester", objNull]];
if !(_message isEqualType "") exitWith {};

if (hasInterface) exitWith {
    systemChat _message;
};

if (!isServer) exitWith {};
private _target = if (!isNull _requester) then {_requester} else {-2};
[_message] remoteExecCall ["DRO2026_fnc_supportMessage", _target, false];