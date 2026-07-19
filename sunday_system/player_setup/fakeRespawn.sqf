private ["_varName", "_unit", "_id", "_loadout", "_class", "_firstName", "_lastName", "_unitOld"];

_unitOld = _this select 0;
private _respawnDisabled = missionNamespace getVariable ["DRO2026_respawnDisabled", (paramsArray param [0, 1]) == 3];
if (_respawnDisabled || {!isNil "respawnTime" && {respawnTime < 0}}) exitWith {
	if (!isNull _unitOld) then {deleteVehicle _unitOld};
};

diag_log format ["DRO: Initiating AI respawn for %1", _unitOld];
_loadout = _unitOld getVariable ["respawnLoadout", getUnitLoadout _unitOld];
_varName = vehicleVarName _unitOld;
_id = (parseNumber ((str _unitOld) select [1])) - 1;
_class = typeOf _unitOld;
_firstName = ((nameLookup select _id) select 0);
_lastName = ((nameLookup select _id) select 1);
_speaker = ((nameLookup select _id) select 2);
_face = ((nameLookup select _id) select 3);

if (missionNamespace getVariable ["DRO2026_DEBUG", false]) then {
	diag_log format ["DRO: AI respawn data unit=%1 var=%2 id=%3 class=%4", _unitOld, _varName, _id, _class];
};

sleep (respawnTime max 0);
if (missionNamespace getVariable ["DRO2026_respawnDisabled", false]) exitWith {
	if (!isNull _unitOld) then {deleteVehicle _unitOld};
};

_respawnPos = if ((paramsArray select 1) == 0 OR (paramsArray select 1) == 2) then {
	getMarkerPos "respawn"
} else {
	if ((paramsArray select 1) < 2) then {getMarkerPos "campMkr"} else {[]};
};

if (count _respawnPos > 0) then {
	_grp = createGroup playersSide;
	_unit = _grp createUnit [_class, _respawnPos, [], 0, "NONE"];
	if (isNull _unit) exitWith {deleteGroup _grp};

	if (reviveDisabled < 3) then {
		[_unit, _unitOld] call rev_addReviveToUnit;
	};
	deleteVehicle _unitOld;
	_unit setVehicleVarName _varName;
	[_unit, _firstName, _lastName, _speaker, _face] remoteExec ["sun_setNameMP", 0, true];

	_playerGroup = grpNetId call BIS_fnc_groupFromNetId;
	if (!isNull _playerGroup) then {_unit joinAsSilent [_playerGroup, _id]};
	_unit setUnitLoadout _loadout;
	_unit setVariable ["respawnLoadout", getUnitLoadout _unit, true];
	_unit setUnitTrait ["Medic", true];
	_unit setUnitTrait ["engineer", true];
	_unit setUnitTrait ["explosiveSpecialist", true];
	_unit setUnitTrait ["UAVHacker", true];

	if (missionNamespace getVariable ["DRO2026_respawnDisabled", false]) then {
		[_unit, ["respawn", {deleteVehicle (_this select 0)}]] remoteExec ["addEventHandler", _unit, true];
	} else {
		[_unit, ["killed", {[(_this select 0)] execVM "sunday_system\player_setup\fakeRespawn.sqf"}]] remoteExec ["addEventHandler", _unit, true];
		[_unit, ["respawn", {deleteVehicle (_this select 0)}]] remoteExec ["addEventHandler", _unit, true];
	};
	deleteGroup _grp;
};