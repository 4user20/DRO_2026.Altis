params [["_contact", createHashMap, [createHashMap]], ["_reason", "INVALID_RECORD", [""]]];
if (!isServer) exitWith {false};
private _id = _contact getOrDefault ["id", format ["INVALID_%1", floor (diag_tickTime * 1000)]];
private _quarantine = missionNamespace getVariable ["DRO2026_contactQuarantine", createHashMap];
if (isNil {_quarantine get _id}) then {
    _contact set ["state", "EXPIRED"];
    _contact set ["bdaState", "EXPIRED"];
    _contact set ["lastUpdatedAt", time];
    _quarantine set [_id, createHashMapFromArray [["reason",_reason],["contact",_contact],["at",time]]];
    missionNamespace setVariable ["DRO2026_contactQuarantine", _quarantine];
    ["CONTACT", "INVALID_RECORD", createHashMapFromArray [["id",_id],["reason",_reason]], _id] call DRO2026_fnc_logStructured;
};
false
