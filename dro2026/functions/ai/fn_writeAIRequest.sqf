params ["_type", "_data"];
if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["DRO2026_aiTransportReady", false]) exitWith {""};
private _count = (missionNamespace getVariable ["DRO2026_aiRequestCount", 0]) + 1;
missionNamespace setVariable ["DRO2026_aiRequestCount", _count];
private _id = format ["%1_%2_%3", floor diag_tickTime, _count, _type];
private _db = ["new", "DROAI_out"] call OO_INIDBI;
["write", ["DROAI_out", _id, [_type, _data]]] call _db;
_id
