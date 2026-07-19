params ["_mode", ["_quantity", 1], ["_position", []]];
if (!hasInterface) exitWith {};
_quantity = ((round _quantity) max 1) min 10;

if (count _position < 2) exitWith {
    missionNamespace setVariable ["DRO2026_pendingSupport", [_mode, _quantity]];
    openMap true;
    hint "Штаб: укажите точку применения поддержки на карте. Закройте карту для отмены.";
    onMapSingleClick "private _p = missionNamespace getVariable ['DRO2026_pendingSupport', []]; missionNamespace setVariable ['DRO2026_pendingSupport', []]; onMapSingleClick ''; openMap false; hintSilent ''; if (count _p >= 2) then {[_p select 0, _p select 1, _pos] call DRO2026_fnc_beginSupportTargeting}; true";
    [] spawn {
        waitUntil {
            sleep 0.2;
            !visibleMap ||
            {count (missionNamespace getVariable ["DRO2026_pendingSupport", []]) == 0} ||
            {missionNamespace getVariable ["DRO2026_missionEnding", false]}
        };
        if (!visibleMap && {count (missionNamespace getVariable ["DRO2026_pendingSupport", []]) > 0}) then {
            onMapSingleClick "";
            missionNamespace setVariable ["DRO2026_pendingSupport", []];
            hintSilent "";
            systemChat "Штаб: выбор точки поддержки отменён.";
        };
    };
};

private _upper = toUpperANSI _mode;
switch true do {
    case ((_upper find "FPV_CLASS_AUTO:") == 0): {[_position, false, _quantity, _mode select [15]] call DRO2026_fnc_requestFPV};
    case ((_upper find "FPV_CLASS_MANUAL:") == 0): {[_position, true, 1, _mode select [17]] call DRO2026_fnc_requestFPV};
    case (_upper == "FPV_AUTO"): {[_position, false, _quantity] call DRO2026_fnc_requestFPV};
    case (_upper == "FPV_MANUAL"): {[_position, true, 1] call DRO2026_fnc_requestFPV};
    case ((_upper find "ISR_CLASS:") == 0): {[_position, format ["CLASS:%1", _mode select [10]]] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_AUTO"): {[_position, "AUTO"] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_MICRO"): {[_position, "MICRO"] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_RQ7"): {[_position, "RQ7"] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_MQ4A"): {[_position, "MQ4A"] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_TACTICAL"): {[_position, "TACTICAL"] call DRO2026_fnc_requestISR};
    case (_upper == "ISR_HALE"): {[_position, "HALE"] call DRO2026_fnc_requestISR};
    case ((_upper find "STRIKE_CLASS:") == 0): {[_position, format ["CLASS:%1", _mode select [13]], false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_FP1"): {[_position, "FP1", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_FP2"): {[_position, "FP2", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_BM35"): {[_position, "BM35", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_BULAVA"): {[_position, "BULAVA", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_FP5"): {[_position, "FP5", false, 1] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_SHAHED"): {[_position, "SHAHED", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_AUTO"): {[_position, "AUTO", false, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case (_upper == "STRIKE_DECOY"): {[_position, "AUTO", true, _quantity] call DRO2026_fnc_requestLongRangeSupport};
    case ((_upper find "ARTY:") == 0): {[_position, _mode select [5], _quantity] call DRO2026_fnc_requestArtillery};
    case ((_upper find "AIR:") == 0): {[_position, _mode select [4], _quantity] call DRO2026_fnc_requestAirSupport};
    default {systemChat format ["Штаб: неизвестный профиль поддержки %1.", _mode]};
};
