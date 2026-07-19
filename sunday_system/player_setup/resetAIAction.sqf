params ["_unit", "_caller"];

private ["_varName", "_unitNew", "_id", "_loadout", "_class", "_firstName", "_lastName", "_pos"];
private _playerGroup = group _caller;
private _respawnDisabled = missionNamespace getVariable ["DRO2026_respawnDisabled", (paramsArray param [0, 1]) == 3];

diag_log format ["DRO: Initiating AI reset for %1", _unit];
_loadout = getUnitLoadout _unit;
_varName = vehicleVarName _unit;
_id = (parseNumber ((str _unit) select [1])) - 1;
_class = typeOf _unit;
_firstName = ((nameLookup select _id) select 0);
_lastName = ((nameLookup select _id) select 1);
_face = ((nameLookup select _id) select 3);
_speaker = speaker _unit;

_pos = [getPos _unit, 0, 50, 1, 0, -1, 0, [], [[0,0,0],[0,0,0]]] call BIS_fnc_findSafePos;
if (_pos isEqualTo [0,0,0]) then {
	_pos = [getPos _caller, 0, 50, 1, 0, -1, 0, [], [[0,0,0],[0,0,0]]] call BIS_fnc_findSafePos;
};
if (_pos isEqualTo [0,0,0]) exitWith {
	"Не удалось найти безопасную позицию для восстановления бойца." remoteExecCall ["hint", _caller];
};

private _temporaryGroup = createGroup playersSide;
_unitNew = _temporaryGroup createUnit [_class, _pos, [], 0, "NONE"];
if (isNull _unitNew) exitWith {deleteGroup _temporaryGroup};

if (reviveDisabled < 3) then {
	[_unitNew, _unit] call rev_addReviveToUnit;
};
deleteVehicle _unit;
[_unitNew, _varName] remoteExec ["setVehicleVarName", 0, true];
[_unitNew, _lastName] remoteExec ["setNameSound", 0, true];
[_unitNew, _firstName, _lastName, _speaker, _face] remoteExec ["sun_setNameMP", 0, true];

_unitNew joinAsSilent [_playerGroup, _id];
_unitNew setUnitLoadout _loadout;
_unitNew setVariable ["respawnLoadout", getUnitLoadout _unitNew, true];
[_unitNew] call sun_addResetAction;

if (_respawnDisabled) then {
	[_unitNew, ["respawn", {deleteVehicle (_this select 0)}]] remoteExec ["addEventHandler", _unitNew, true];
} else {
	[_unitNew, ["killed", {[(_this select 0)] execVM "sunday_system\player_setup\fakeRespawn.sqf"}]] remoteExec ["addEventHandler", _unitNew, true];
	[_unitNew, ["respawn", {deleteVehicle (_this select 0)}]] remoteExec ["addEventHandler", _unitNew, true];
};

deleteGroup _temporaryGroup;