params [["_class", "", [""]]];
private _name = toLowerANSI _class;
private _cfg = configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg) exitWith {""};
private _size = sizeOf _class;
private _sensors = _cfg >> "Components" >> "SensorsManagerComponent" >> "Components";
private _hasSensors = isClass _sensors && {count _sensors > 0};
if ((_name find "mavic") >= 0 || {(_name find "quad") >= 0} || {_size <= 3}) exitWith {"smallQuadISR"};
if ((_name find "mq4") >= 0 || {(_name find "hale") >= 0}) exitWith {if (_hasSensors) then {"MALE_HALE_ISR"} else {""}};
if ((_name find "fp2") >= 0 && {!_hasSensors}) exitWith {""};
if ((_name find "shahed") >= 0 || {(_name find "geran") >= 0}) exitWith {if (_hasSensors) then {"longRangeISR"} else {""}};
if (_hasSensors && {_size > 10}) exitWith {"longRangeISR"};
if (_hasSensors) exitWith {"tacticalISR"};
""
