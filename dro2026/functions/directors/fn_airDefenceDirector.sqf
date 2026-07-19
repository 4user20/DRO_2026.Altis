if (!isServer) exitWith {};
private _lastEmissionContact = createHashMap;
while {!(missionNamespace getVariable ["DRO2026_missionEnding", false])} do {
    {
        private _nodeId = _x;
        private _node = DRO2026_networkNodes getOrDefault [_nodeId, createHashMap];
        if (count _node > 0) then {
            private _status = _node getOrDefault ["status", "ACTIVE"];
            private _refs = (_node getOrDefault ["physicalRefs", []]) select {!isNull _x && {alive _x}};
            private _stocks = _node getOrDefault ["stocks", createHashMap];
            private _missiles = _stocks getOrDefault ["AA_MISSILES", 0];
            private _baseChannels = if (_nodeId == "NODE_AA_LONG_01") then {3} else {2};
            private _components = _node getOrDefault ["components", createHashMap];
            private _radarHealth = _components getOrDefault ["radar", if (_nodeId == "NODE_AA_LONG_01") then {1} else {0.65}];
            private _commandHealth = _components getOrDefault ["commandLink", 1];
            private _channels = floor (_baseChannels * ((_radarHealth max 0.25) min 1) * ((_commandHealth max 0.35) min 1));
            _channels = (_channels max 1) min _baseChannels;

            {
                private _asset = _x;
                if !(_asset getVariable ["DRO2026_AAStockEH", false]) then {
                    _asset setVariable ["DRO2026_AAStockEH", true];
                    _asset setVariable ["DRO2026_networkNodeId", _nodeId, true];
                    _asset addEventHandler ["Fired", {
                        params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile"];
                        if (!isServer) exitWith {};
                        private _nodeId = _unit getVariable ["DRO2026_networkNodeId", ""];
                        if (_nodeId == "") exitWith {};
                        private _lower = toLowerANSI format ["%1 %2 %3", _weapon, _magazine, _ammo];
                        if ((_lower find "missile") >= 0 || {(_lower find "rocket") >= 0} || {(_lower find "sam") >= 0} || {(_lower find "aa") >= 0}) then {
                            [_nodeId, "AA_MISSILES", -1, "AA_LAUNCH"] call DRO2026_fnc_changeNetworkNodeStock;
                            ["AA_MISSILE_LAUNCHED", createHashMapFromArray [["nodeId", _nodeId], ["weapon", _weapon], ["magazine", _magazine], ["projectile", _projectile]], _nodeId] call DRO2026_fnc_emitEvent;
                        };
                    }];
                };
            } forEach _refs;

            private _nodePos = _node getOrDefault ["position", [0,0,0]];
            private _coverage = if (_nodeId == "NODE_AA_LONG_01") then {12500} else {4800};
            private _tracks = [];
            {
                private _air = _x;
                if (!isNull _air && {alive _air} && {_air isKindOf "Air"}) then {
                    private _airSide = side _air;
                    if (count crew _air > 0) then {_airSide = side (group ((crew _air) select 0))};
                    if (_airSide == playersSide && {_air distance2D _nodePos <= _coverage}) then {
                        private _priority = 0.55;
                        if (_air getVariable ["DRO2026_decoy", false]) then {_priority = 0.72};
                        if (_air isKindOf "Plane") then {_priority = _priority + 0.20};
                        _tracks pushBack [_air, _priority, _air distance2D _nodePos];
                    };
                };
            } forEach DRO2026_activeDrones;
            {
                private _air = _x;
                if (_air isKindOf "Air" && {alive _air} && {_air distance2D _nodePos <= _coverage}) then {
                    private _airSide = side _air;
                    if (count crew _air > 0) then {_airSide = side (group ((crew _air) select 0))};
                    private _alreadyTracked = (_tracks findIf {(_x select 0) == _air}) >= 0;
                    if (_airSide == playersSide && {!_alreadyTracked}) then {
                        _tracks pushBack [_air, 0.9, _air distance2D _nodePos];
                    };
                };
            } forEach vehicles;
            _tracks = [_tracks, [], {-((_x select 1) - ((_x select 2) / (_coverage * 2)))}, "ASCEND"] call BIS_fnc_sortBy;
            private _activeTracks = _tracks select [0, (count _tracks) min _channels];

            private _emission = "SILENT";
            if (_status in ["DESTROYED", "DISABLED"] || {_missiles <= 0}) then {
                _emission = "OFF";
            } else {
                if (count _tracks > 0) then {
                    _emission = if (count _activeTracks >= _channels) then {"ENGAGE"} else {"TRACK"};
                } else {
                    private _phase = DRO2026_operationState getOrDefault ["phase", "RECON"];
                    _emission = if (_phase == "COUNTERATTACK" || {DRO2026_alertLevel > 0.68}) then {"SEARCH"} else {"SILENT"};
                };
            };
            private _oldEmission = _node getOrDefault ["emissionState", "SILENT"];
            _node set ["trackingChannels", _channels];
            _node set ["activeTracks", _activeTracks apply {netId (_x select 0)}];
            _node set ["emissionState", _emission];
            _node set ["lastUpdatedAt", time];
            DRO2026_networkNodes set [_nodeId, _node];

            if (_emission != _oldEmission) then {
                ["AA_EMISSION_CHANGED", createHashMapFromArray [["nodeId", _nodeId], ["from", _oldEmission], ["to", _emission], ["tracks", count _activeTracks], ["channels", _channels]], _nodeId] call DRO2026_fnc_emitEvent;
            };
            if (_emission in ["SEARCH", "TRACK", "ENGAGE"] && {(time - (_lastEmissionContact getOrDefault [_nodeId, -999])) > 42}) then {
                private _known = _node getOrDefault ["knownByPlayer", "UNKNOWN"];
                private _confidence = if (_emission == "ENGAGE") then {0.78} else {if (_known == "CONFIRMED") then {0.72} else {0.56}};
                private _uncertainty = if (_known == "CONFIRMED") then {120} else {350};
                private _estimate = _nodePos getPos [random _uncertainty, random 360];
                ["PLAYER", objNull, _estimate, _confidence, if (_nodeId == "NODE_AA_LONG_01") then {"ИЗЛУЧЕНИЕ ДАЛЬНЕЙ ПВО"} else {"ИЗЛУЧЕНИЕ SHORAD"}, "ELINT", _uncertainty, _nodeId, 0.04] call DRO2026_fnc_addContact;
                _lastEmissionContact set [_nodeId, time];
            };
        };
    } forEach ["NODE_AA_LONG_01", "NODE_AA_SHORAD_01"];
    sleep 5;
};