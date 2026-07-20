params [["_request", createHashMap, [createHashMap]]];
if (!isServer) exitWith {[false, "NOT_SERVER", "", objNull, -1]};
private _remoteOwner = remoteExecutedOwner;
private _candidates = allPlayers select {
    !isNull _x && {!(_x isKindOf "VirtualMan_F")} && {isPlayer _x} && {owner _x == _remoteOwner}
};
if (count _candidates != 1) exitWith {[false, "REQUESTER_OWNER_UNRESOLVED", "", objNull, _remoteOwner]};
private _requester = _candidates select 0;
if (!alive _requester) exitWith {[false, "REQUESTER_DEAD", "", objNull, _remoteOwner]};
private _uid = getPlayerUID _requester;
private _claimedUid = _request getOrDefault ["requesterUid", ""];
private _claimedNetId = _request getOrDefault ["requesterNetId", ""];
if (_claimedUid != "" && {_claimedUid != _uid}) exitWith {[false, "REQUESTER_UID_MISMATCH", _uid, objNull, _remoteOwner]};
if (_claimedNetId != "" && {_claimedNetId != netId _requester}) exitWith {[false, "REQUESTER_NETID_MISMATCH", _uid, objNull, _remoteOwner]};
if (isDedicated && {_remoteOwner <= 2}) exitWith {[false, "REQUESTER_OWNER_NOT_CLIENT", _uid, objNull, _remoteOwner]};
[true, "OK", _uid, _requester, _remoteOwner]
