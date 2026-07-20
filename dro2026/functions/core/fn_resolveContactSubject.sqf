params [["_contact", createHashMap, [createHashMap]]];
if (count _contact == 0) exitWith {[false, objNull, "CONTACT_EMPTY", "EXPIRED"]};
private _state = toUpperANSI (_contact getOrDefault ["state", _contact getOrDefault ["bdaState", "DETECTED"]]);
if (_state in ["DESTROYED","EXPIRED","CONFIRMED_DESTROYED","PROBABLY_DESTROYED","CANCELLED","COMPLETED"]) exitWith {[false,objNull,"CONTACT_TERMINAL",_state]};
private _subject = _contact getOrDefault ["subjectObject", _contact getOrDefault ["target", objNull]];
if (!isNull _subject) exitWith {[alive _subject, _subject, if (alive _subject) then {"OBJECT_LIVE"} else {"OBJECT_DESTROYED"}, if (alive _subject) then {_state} else {"DESTROYED"}]};
private _subjectNetId = _contact getOrDefault ["subjectNetId", ""];
if (_subjectNetId == "") then {_subjectNetId = _contact getOrDefault ["subjectId", ""]};
if (_subjectNetId == "") exitWith {[false,objNull,"SUBJECT_ID_EMPTY","EXPIRED"]};
if ((_subjectNetId find "PLAYER:") == 0) exitWith {
    private _uid = _subjectNetId select [7];
    private _players = allPlayers select {!isNull _x && {!(_x isKindOf "VirtualMan_F")} && {alive _x} && {getPlayerUID _x == _uid}};
    if (count _players > 0) then {[true,_players select 0,"PLAYER_LIVE",_state]} else {[false,objNull,"PLAYER_MISSING","EXPIRED"]}
};
private _netId = if ((_subjectNetId find "SUPPORT:") == 0) then {_subjectNetId select [8]} else {_subjectNetId};
private _resolved = objectFromNetId _netId;
if (!isNull _resolved) exitWith {[alive _resolved,_resolved,if (alive _resolved) then {"NETID_LIVE"} else {"NETID_DESTROYED"},if (alive _resolved) then {_state} else {"DESTROYED"}]};
private _siteIndex = DRO2026_sites findIf {(_x getOrDefault ["id",""]) == _subjectNetId || {(_x getOrDefault ["networkNodeId",""]) == _subjectNetId}};
if (_siteIndex >= 0) exitWith {
    private _site = DRO2026_sites select _siteIndex;
    private _status = toUpperANSI (_site getOrDefault ["status","ACTIVE"]);
    private _obj = _site getOrDefault ["object",objNull];
    private _live = !(_status in ["DESTROYED","DISABLED","CANCELLED","COMPLETED"]) && {isNull _obj || {alive _obj}};
    [_live,_obj,if (_live) then {"SITE_LIVE"} else {"SITE_TERMINAL"},if (_live) then {_state} else {"DESTROYED"}]
};
private _positionIndex = DRO2026_friendlyPositions findIf {str (_x getOrDefault ["id",""]) == _subjectNetId || {(_x getOrDefault ["id",""]) isEqualTo _subjectNetId}};
if (_positionIndex >= 0) exitWith {
    private _record = DRO2026_friendlyPositions select _positionIndex;
    private _obj = _record getOrDefault ["object",objNull];
    [isNull _obj || {alive _obj},_obj,"FRIENDLY_POSITION",_state]
};
private _node = DRO2026_networkNodes getOrDefault [_subjectNetId, createHashMap];
if (count _node > 0) exitWith {
    private _status = toUpperANSI (_node getOrDefault ["status","ACTIVE"]);
    private _live = !(_status in ["DESTROYED","DISABLED","CANCELLED","COMPLETED"]);
    [_live,objNull,if (_live) then {"NODE_LIVE"} else {"NODE_TERMINAL"},if (_live) then {_state} else {"DESTROYED"}]
};
[false,objNull,"SUBJECT_UNRESOLVED","EXPIRED"]
