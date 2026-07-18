params ["_position", "_side", ["_type", "FPV_TEAM"]];
private _preferred = switch (_side) do {
    case west: {["FP1_B_T_soldier_UAV_F", "B_soldier_UAV_F", "B_recon_JTAC_F"]};
    case resistance: {["I_soldier_UAV_F", "I_Soldier_F"]};
    default {["O_soldier_UAV_F", "O_recon_JTAC_F", "O_Soldier_F"]};
};
private _class = "";
{if (_class == "" && {[_x, _side] call DRO2026_fnc_isSafeInfantryClass}) then {_class = _x}} forEach _preferred;
if (_class == "") then {_class = switch (_side) do {case west: {"B_Soldier_F"}; case resistance: {"I_Soldier_F"}; default {"O_Soldier_F"}}};
private _group = createGroup [_side, true];
private _operator = _group createUnit [_class, _position, [], 5, "NONE"];
_operator setSkill 0.62;
_operator setVariable ["DRO2026_droneOperator", true];
_operator setVariable ["DRO2026_teamType", _type];
private _assistant = _group createUnit [_class, _position getPos [5, random 360], [], 4, "NONE"];
_assistant setSkill 0.48;
private _antenna = createVehicle ["Land_SatelliteAntenna_01_F", _position getPos [7, 80], [], 0, "CAN_COLLIDE"];
private _tent = createVehicle ["Land_TentDome_F", _position getPos [8, 240], [], 0, "CAN_COLLIDE"];
[_group, false] call DRO2026_fnc_registerManagedGroup;
_group setBehaviourStrong "AWARE";
_group setCombatMode "YELLOW";
createHashMapFromArray [["operator", _operator], ["assistant", _assistant], ["group", _group], ["antenna", _antenna], ["tent", _tent], ["position", _position], ["type", _type]]
