params ["_siteId", ["_allowRelocating", false]];
if !(_siteId isEqualType "") exitWith {false};
if (_siteId == "") exitWith {false};
private _index = DRO2026_sites findIf {(_x getOrDefault ["id", ""]) == _siteId};
if (_index < 0) exitWith {false};
private _site = DRO2026_sites select _index;
private _status = _site getOrDefault ["status", "ACTIVE"];
private _terminal = ["DESTROYED", "DISABLED", "CANCELLED", "COMPLETED"];
if (!_allowRelocating) then {_terminal pushBack "RELOCATING"};
if (_status in _terminal) exitWith {false};
private _physicalState = _site getOrDefault ["physicalState", "ACTIVE"];
if (_physicalState in ["DESTROYED", "DISABLED", "CANCELLED", "COMPLETED"]) exitWith {false};
private _operator = _site getOrDefault ["operator", objNull];
if (!isNull _operator && {!alive _operator}) exitWith {false};
true
