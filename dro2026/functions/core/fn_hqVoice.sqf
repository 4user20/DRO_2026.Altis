params ["_event", ["_forceSubtitle", ""]];
if (!hasInterface) exitWith {};
private _variants = DRO2026_voiceMap getOrDefault [_event, []];
if (count _variants == 0) exitWith {
    if (_forceSubtitle != "") then {systemChat _forceSubtitle};
};
private _variant = +(selectRandom _variants);
if (_forceSubtitle != "") then {_variant set [2, _forceSubtitle]};
if (count DRO2026_voiceQueue >= 8) then {DRO2026_voiceQueue deleteAt 0};
DRO2026_voiceQueue pushBack _variant;
if (!DRO2026_voiceWorkerActive) then {
    DRO2026_voiceWorkerActive = true;
    [] spawn {
        while {count DRO2026_voiceQueue > 0} do {
            private _entry = DRO2026_voiceQueue deleteAt 0;
            _entry params ["_path", "_duration", "_subtitle"];
            if (_subtitle != "") then {
                [parseText format ["<t font='RobotoCondensedBold' color='#b9e5ff' size='1.05'>%1</t>", _subtitle], true, nil, 5, 0.4, 0] spawn BIS_fnc_textTiles;
            };
            // fileExists only resolves relative virtual paths and rejects getMissionPath absolute paths.
            // playSoundUI accepts the mission absolute path, including files packed inside a mission PBO.
            private _absolute = getMissionPath _path;
            playSoundUI [_absolute, 1, 1];
            uiSleep (_duration + 0.45);
        };
        DRO2026_voiceWorkerActive = false;
    };
};
