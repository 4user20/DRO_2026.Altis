/* Future maneuver layer. Never expose raw group handles to the LLM. */
if (!isServer) exitWith {false};
{
    if (!isNull _x && {side _x == enemySide}) then {
        private _id = _x getVariable ["DRO2026_groupId",""];
        if (_id == "") then {
            private _seq=(missionNamespace getVariable ["DRO2026_groupSequence",0])+1;
            missionNamespace setVariable ["DRO2026_groupSequence",_seq];
            _id=format ["GRP_%1",_seq];
            _x setVariable ["DRO2026_groupId",_id,true];
            _x setVariable ["DRO2026_groupHome",getPosATL leader _x];
            _x setVariable ["DRO2026_commandOwner","DIRECTOR"];
            _x setVariable ["DRO2026_commandLeaseUntil",-1];
            _x setVariable ["DRO2026_commandRevision",0];
        };
    };
} forEach DRO2026_managedGroups;
true
