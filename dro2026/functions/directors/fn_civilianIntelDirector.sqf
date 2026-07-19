if (!isServer) exitWith {};
if (isNil {DRO2026_operationState get "civilianFear"}) then {DRO2026_operationState set ["civilianFear", 18]};
if (isNil {DRO2026_operationState get "localHostility"}) then {DRO2026_operationState set ["localHostility", 10]};
private _lastReportAt = -999;

while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    private _civilians = allUnits select {alive _x && {side (group _x) == civilian}};
    {
        private _civilian = _x;
        if !(_civilian getVariable ["DRO2026_civilianTracked", false]) then {
            _civilian setVariable ["DRO2026_civilianTracked", true];
            _civilian addEventHandler ["Killed", {
                params ["_unit", "_killer", "_instigator"];
                if (!isServer) exitWith {};
                private _responsible = if (!isNull _instigator) then {_instigator} else {_killer};
                private _responsibleSide = sideUnknown;
                if (!isNull _responsible) then {
                    _responsibleSide = side _responsible;
                    if (_responsible isKindOf "Man") then {_responsibleSide = side (group _responsible)};
                    if (count crew _responsible > 0) then {_responsibleSide = side (group ((crew _responsible) select 0))};
                };
                private _trust = DRO2026_operationState getOrDefault ["civilianTrust", 55];
                private _fear = DRO2026_operationState getOrDefault ["civilianFear", 18];
                private _hostility = DRO2026_operationState getOrDefault ["localHostility", 10];
                if (_responsibleSide == playersSide) then {
                    _trust = (_trust - 9) max 0;
                    _fear = (_fear + 8) min 100;
                    _hostility = (_hostility + 7) min 100;
                    DRO2026_operationState set ["playerNoise", (DRO2026_operationState getOrDefault ["playerNoise", 0]) + 8];
                } else {
                    if (_responsibleSide == enemySide) then {
                        _trust = (_trust + 2) min 100;
                        _fear = (_fear + 5) min 100;
                    } else {
                        _fear = (_fear + 3) min 100;
                    };
                };
                DRO2026_operationState set ["civilianTrust", _trust];
                DRO2026_operationState set ["civilianFear", _fear];
                DRO2026_operationState set ["localHostility", _hostility];
                ["CIVILIAN_HARM", createHashMapFromArray [
                    ["position", getPosATL _unit], ["responsibleSide", str _responsibleSide],
                    ["trust", _trust], ["fear", _fear], ["localHostility", _hostility]
                ], "CIVILIAN_LAYER"] call DRO2026_fnc_emitEvent;
            }];
        };
    } forEach _civilians;

    private _trust = DRO2026_operationState getOrDefault ["civilianTrust", 55];
    private _fear = DRO2026_operationState getOrDefault ["civilianFear", 18];
    private _hostility = DRO2026_operationState getOrDefault ["localHostility", 10];
    private _reportInterval = linearConversion [0, 100, _trust, 210, 85, true] + random 50;
    if (count _civilians > 0 && {(time - _lastReportAt) >= _reportInterval} && {_trust > 12}) then {
        private _reporter = selectRandom _civilians;
        private _reporterPosition = getPosATL _reporter;
        private _observations = [];

        {
            private _nodeId = _x;
            private _node = DRO2026_networkNodes get _nodeId;
            private _status = _node getOrDefault ["status", "ACTIVE"];
            private _position = _node getOrDefault ["position", []];
            if (!(_status in ["DESTROYED", "DISABLED"]) && {count _position > 1} && {_position distance2D _reporterPosition < 2400}) then {
                private _type = _node getOrDefault ["type", "UNKNOWN"];
                private _classification = switch _type do {
                    case "FPV_TEAM": {"ПОДОЗРИТЕЛЬНЫЕ ОПЕРАТОРЫ БПЛА"};
                    case "STRATEGIC_DRONE_SITE": {"ПУСКОВАЯ ПЛОЩАДКА БПЛА"};
                    case "ARTILLERY_SITE": {"ТЯЖЁЛАЯ ТЕХНИКА / АРТИЛЛЕРИЯ"};
                    case "EW_SITE": {"АНТЕННЫ И РАДИОТЕХНИКА"};
                    case "AA_LONG": {"ПВО И РАДАР"};
                    case "AA_SHORAD": {"МОБИЛЬНАЯ ПВО"};
                    case "LOGISTICS_HUB": {"СКЛАДСКАЯ АКТИВНОСТЬ"};
                    default {"ПОДОЗРИТЕЛЬНАЯ ВОЕННАЯ АКТИВНОСТЬ"};
                };
                _observations pushBack [_position, _classification, _nodeId, _position distance2D _reporterPosition];
            };
        } forEach keys DRO2026_networkNodes;

        {
            private _delivery = _x;
            private _status = _delivery getOrDefault ["status", ""];
            private _position = _delivery getOrDefault ["virtualPosition", _delivery getOrDefault ["source", []]];
            if (_status in ["VIRTUAL", "IN_TRANSIT", "EN_ROUTE"] && {count _position > 1} && {_position distance2D _reporterPosition < 2200}) then {
                _observations pushBack [_position, "КОЛОННА / ПОСТАВКА", "", _position distance2D _reporterPosition];
            };
        } forEach DRO2026_supplyLanes;

        private _falseProbability = linearConversion [0, 100, _trust, 0.38, 0.06, true];
        _falseProbability = (_falseProbability + linearConversion [0, 100, _fear + _hostility, 0, 0.22, true]) min 0.60;
        private _useFalseReport = count _observations == 0 || {random 1 < _falseProbability};
        private _truePosition = _reporterPosition;
        private _classification = "СЛУХ О ВОЕННОЙ АКТИВНОСТИ";
        private _subjectId = "";
        if (!_useFalseReport) then {
            _observations = [_observations, [], {_x select 3}, "ASCEND"] call BIS_fnc_sortBy;
            private _observation = _observations select 0;
            _truePosition = _observation select 0;
            _classification = _observation select 1;
            _subjectId = _observation select 2;
        } else {
            _truePosition = _reporterPosition getPos [350 + random 1700, random 360];
        };
        private _delayError = linearConversion [0, 100, _trust, 650, 220, true] + random 240;
        private _estimate = _truePosition getPos [random _delayError, random 360];
        private _confidence = (linearConversion [0, 100, _trust, 0.28, 0.62, true]) - (0.16 * _falseProbability);
        [
            "PLAYER", objNull, _estimate, _confidence max 0.18, _classification,
            "CIVILIAN", _delayError, _subjectId, if (_useFalseReport) then {0.62} else {_falseProbability}
        ] call DRO2026_fnc_addContact;
        ["CIVILIAN_REPORT", createHashMapFromArray [
            ["classification", _classification], ["subjectId", _subjectId], ["estimate", _estimate],
            ["uncertainty", _delayError], ["confidence", _confidence], ["falseProbability", if (_useFalseReport) then {0.62} else {_falseProbability}],
            ["trust", _trust], ["fear", _fear]
        ], "CIVILIAN_LAYER"] call DRO2026_fnc_emitEvent;
        _lastReportAt = time;
    };
    sleep 25;
};