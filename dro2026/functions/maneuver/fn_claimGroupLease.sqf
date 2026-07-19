params ["_group","_owner",["_seconds",120]];
if (!isServer || {isNull _group}) exitWith {false};
private _leaseUntil=_group getVariable ["DRO2026_commandLeaseUntil",-1];
private _currentOwner=_group getVariable ["DRO2026_commandOwner","DIRECTOR"];
if (_leaseUntil > time && {_currentOwner != _owner}) exitWith {false};
_group setVariable ["DRO2026_commandOwner",_owner,true];
_group setVariable ["DRO2026_commandLeaseUntil",time+((_seconds max 15) min 600),true];
_group setVariable ["DRO2026_commandRevision",(_group getVariable ["DRO2026_commandRevision",0])+1,true];
true
