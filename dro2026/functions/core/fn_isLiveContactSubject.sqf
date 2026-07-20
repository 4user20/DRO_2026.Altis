params ["_contact"];
if !(_contact isEqualType createHashMap) exitWith {false};
if ((_contact getOrDefault ["bdaState", "DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"]) exitWith {false};
private _target = _contact getOrDefault ["target", objNull];
if (!isNull _target) exitWith {alive _target};
private _subjectId = _contact getOrDefault ["subjectId", ""];
if (_subjectId == "") exitWith {false};

if ((_subjectId find "PLAYER:") == 0) exitWith {
    private _uid = _subjectId select [7];
    (allPlayers findIf {
        !(_x isKindOf "VirtualMan_F") && {!isNull _x} && {alive _x} && {getPlayerUID _x == _uid}
    }) >= 0
};
if ((_subjectId find "SUPPORT:") == 0) exitWith {
    private _object = objectFromNetId (_subjectId select [8]);
    !isNull _object && {alive _object}
};

private _siteIndex = DRO2026_sites findIf {
    (_x getOrDefault ["id", ""]) == _subjectId ||
    {(_x getOrDefault ["networkNodeId", ""]) == _subjectId}
};
if (_siteIndex >= 0) exitWith {
    private _site = DRO2026_sites select _siteIndex;
    private _status = _site getOrDefault ["status", "ACTIVE"];
    private _object = _site getOrDefault ["object", objNull];
    !(_status in ["DESTROYED", "DISABLED", "CANCELLED"]) && {isNull _object || {alive _object}}
};

private _positionIndex = DRO2026_friendlyPositions findIf {
    (_x getOrDefault ["id", ""]) == _subjectId
};
if (_positionIndex >= 0) exitWith {
    private _record = DRO2026_friendlyPositions select _positionIndex;
    private _object = _record getOrDefault ["object", objNull];
    isNull _object || {alive _object}
};

private _node = DRO2026_networkNodes getOrDefault [_subjectId, createHashMap];
count _node > 0 && {!((_node getOrDefault ["status", "ACTIVE"]) in ["DESTROYED", "DISABLED", "CANCELLED"])}
