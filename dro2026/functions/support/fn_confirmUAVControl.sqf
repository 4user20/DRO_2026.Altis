if (!isServer) exitWith {};
params [["_uavNetId", "", [""]], ["_requesterUid", "", [""]], ["_connected", false, [true]]];
private _remoteOwner = remoteExecutedOwner;
private _players = allPlayers select {!isNull _x && {!(_x isKindOf "VirtualMan_F")} && {isPlayer _x} && {owner _x == _remoteOwner}};
if (count _players != 1) exitWith {};
private _requester = _players select 0;
if (getPlayerUID _requester != _requesterUid) exitWith {};
private _uav = objectFromNetId _uavNetId;
if (isNull _uav || {!alive _uav}) exitWith {};
if ((_uav getVariable ["DRO2026_authorizedControllerUid", ""]) != _requesterUid) exitWith {};
if (_connected) then {
    [_uav, "PLAYER", "TERMINAL_CONNECTION_CONFIRMED", "FPV_TERMINAL"] call DRO2026_fnc_setFlightAuthority;
    _uav setVariable ["DRO2026_manualControl", true, true];
} else {
    [_uav, "FPV_TERMINAL", "PLAYER_RELEASED_TERMINAL", "PLAYER"] call DRO2026_fnc_setFlightAuthority;
    _uav setVariable ["DRO2026_manualControl", false, true];
};
