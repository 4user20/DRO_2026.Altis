params ["_positionASL", "_class", ["_quantity", 1], ["_requester", objNull]];

if (!isServer) exitWith {
    [createHashMapFromArray [["channel","CAS"],["assetClass",_class],["count",_quantity],["targetMode","MAP_POINT"],["targetPositionASL",AGLToASL _positionASL],["sourceMode","AUTO"],["controlMode","AUTO"]]] call DRO2026_fnc_submitSupportRequest
};
[] call DRO2026_fnc_initState;
if (isNull _requester && {hasInterface}) then {_requester = player};
if (!isNull _requester && {side (group _requester) != playersSide}) exitWith {["Штаб: авиационная поддержка недоступна для этой стороны.", _requester] call DRO2026_fnc_supportMessage};
if (count _positionASL < 2) exitWith {["Штаб: не задана точка удара.",_requester] call DRO2026_fnc_supportMessage};

private _allowedClasses = DRO2026_assetRegistry getOrDefault ["PLAYER_CAS_AIR", []];
if !(_class in _allowedClasses) exitWith {[format ["Штаб: авиационный класс %1 не входит в реестр выбранной фракции.", _class], _requester] call DRO2026_fnc_supportMessage};
if (!isClass (configFile >> "CfgVehicles" >> _class) || {!(_class isKindOf "Air")}) exitWith {[format ["Штаб: авиационный класс %1 недоступен.", _class], _requester] call DRO2026_fnc_supportMessage};
if (time < DRO2026_supportFireLockUntil || {DRO2026_activeHeavySupport >= DRO2026_MAX_CONCURRENT_HEAVY_SUPPORT}) exitWith {["Штаб: тяжёлый огневой канал занят.", _requester] call DRO2026_fnc_supportMessage};

private _airWindow = [_positionASL, playersSide] call DRO2026_fnc_getAirWindow;
private _windowState = _airWindow getOrDefault ["state", "CLOSED"];
if (_windowState == "CLOSED") exitWith {[format ["Штаб: воздушное окно закрыто. Причины: %1", (_airWindow getOrDefault ["reasons", []]) joinString "; "], _requester] call DRO2026_fnc_supportMessage};
private _farpId = "NODE_FRIENDLY_FARP";
private _farp = DRO2026_networkNodes getOrDefault [_farpId,createHashMap];
private _farpStocks = _farp getOrDefault ["stocks",createHashMap];
if (count _farp == 0 || {(toUpperANSI (_farp getOrDefault ["status","DISABLED"])) in ["DESTROYED","DISABLED","CANCELLED"]}) exitWith {["Штаб: FARP уничтожен или не готов.",_requester] call DRO2026_fnc_supportMessage};
private _availableMunitions = floor (_farpStocks getOrDefault ["HELICOPTER_MUNITIONS",0]);
private _availableFuel = floor (_farpStocks getOrDefault ["FUEL",0]);
private _sorties = floor (DRO2026_resources getOrDefault ["friendlyAirSorties",0]);
_quantity = ((round _quantity) max 1) min 2;
if (_windowState == "CONTESTED") then {_quantity = 1};
_quantity = _quantity min _availableMunitions min _availableFuel min _sorties;
if (_quantity <= 0) exitWith {["Штаб: на FARP нет готовых боеприпасов, топлива или вылетов.",_requester] call DRO2026_fnc_supportMessage};

private _contacts = DRO2026_contacts select {
    (_x getOrDefault ["owner", ""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence", 0]) >= 0.72} &&
    {(_x getOrDefault ["uncertaintyRadius", 9999]) <= DRO2026_MAX_CONTACT_UNCERTAINTY_FOR_CAS} &&
    {(time - (_x getOrDefault ["lastSeen", 0])) < 180} &&
    {!((toUpperANSI (_x getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"])} &&
    {(_x getOrDefault ["positionMean",[0,0,0]]) distance2D _positionASL < 750} && {
        private _target = _x getOrDefault ["target",objNull]; !isNull _target && {alive _target}
    }
};
if (count _contacts == 0) exitWith {["Штаб: авиации нужна свежая подтверждённая физическая цель.", _requester] call DRO2026_fnc_supportMessage};
_contacts = [_contacts,[],{-((_x getOrDefault ["confidence",0]) - ((_x getOrDefault ["uncertaintyRadius",0]) / 3000))},"ASCEND"] call BIS_fnc_sortBy;
private _target = (_contacts select 0) getOrDefault ["target",objNull];
private _contactId = (_contacts select 0) getOrDefault ["id",""];
if (isNull _target || {!alive _target}) exitWith {["Штаб: цель потеряна.",_requester] call DRO2026_fnc_supportMessage};

private _home = +(_farp getOrDefault ["position",[]]);
private _missionId = format ["AIR_%1_%2",floor (diag_tickTime*1000),floor random 100000];
DRO2026_supportFireLockUntil = time + DRO2026_SUPPORT_HEAVY_FIRE_SPACING;
DRO2026_activeHeavySupport = DRO2026_activeHeavySupport + 1;
DRO2026_resources set ["friendlyAirSorties",(_sorties - _quantity) max 0];
[_farpId,"HELICOPTER_MUNITIONS",-_quantity,"PLAYER_AIR_MISSION_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
[_farpId,"FUEL",-_quantity,"PLAYER_AIR_MISSION_RESERVED"] call DRO2026_fnc_changeNetworkNodeStock;
["SUPPORT_REQUESTED",createHashMapFromArray [["missionId",_missionId],["type","STANDOFF_AIR"],["class",_class],["quantity",_quantity],["contactId",_contactId]],_missionId] call DRO2026_fnc_emitEvent;

[_missionId,_class,_target,_contactId,_quantity,_requester,_home,_farpId,_positionASL] spawn {
    params ["_missionId","_class","_target","_contactId","_quantity","_requester","_home","_farpId","_requestedPositionASL"];
    private _released = 0;
    private _refunded = 0;
    private _refundTail = {
        params ["_remaining","_reason"];
        if (_remaining > 0) then {
            DRO2026_resources set ["friendlyAirSorties",(DRO2026_resources getOrDefault ["friendlyAirSorties",0]) + _remaining];
            [_farpId,"HELICOPTER_MUNITIONS",_remaining,format ["AIR_TAIL_REFUND_%1",_reason]] call DRO2026_fnc_changeNetworkNodeStock;
            [_farpId,"FUEL",_remaining,format ["AIR_TAIL_REFUND_%1",_reason]] call DRO2026_fnc_changeNetworkNodeStock;
            _refunded = _refunded + _remaining;
        };
        ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","ABORTED"],["reason",_reason],["refunded",_remaining]],_missionId] call DRO2026_fnc_emitEvent;
    };
    for "_index" from 0 to (_quantity - 1) do {
        private _remaining = _quantity - _index;
        if (missionNamespace getVariable ["DRO2026_missionEnding",false]) exitWith {[_remaining,"MISSION_ENDING"] call _refundTail};
        if (isNull _target || {!alive _target}) exitWith {[_remaining,"TARGETS_LOST_BEFORE_LAUNCH"] call _refundTail};
        private _currentWindow = [_requestedPositionASL,playersSide] call DRO2026_fnc_getAirWindow;
        if ((_currentWindow getOrDefault ["state","CLOSED"]) == "CLOSED") exitWith {
            private _reason = if (_currentWindow getOrDefault ["civiliansClose",false]) then {"CIVILIAN_RISK"} else {
                if (_currentWindow getOrDefault ["friendliesClose",false]) then {"FRIENDLIES_CLOSE"} else {"AA_ACTIVE"}
            };
            [_remaining,"AIR_WINDOW_CLOSED_BEFORE_LAUNCH"] call _refundTail;
            ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","ABORTED"],["reason",_reason]],_missionId] call DRO2026_fnc_emitEvent;
        };

        private _spawn = _home getPos [450 + (_index * 120),_home getDir getPosATL _target];
        private _isHeli = _class isKindOf "Helicopter";
        _spawn set [2,if (_isHeli) then {85} else {540}];
        private _air = createVehicle [_class,_spawn,[],0,"FLY"];
        if (isNull _air) then {
            [1,"SPAWN_FAILED"] call _refundTail;
        } else {
            _air setDir (_spawn getDir getPosATL _target);
            _air setPosATL _spawn;
            private _group = playersSide createVehicleCrew _air;
            if (isNull _group || {isNull driver _air}) then {
                deleteVehicleCrew _air;
                deleteVehicle _air;
                if (!isNull _group) then {deleteGroup _group};
                [1,"NO_CREW"] call _refundTail;
            } else {
                _group addVehicle _air;
                [_group,false] call DRO2026_fnc_registerManagedGroup;
                DRO2026_managedVehicles pushBackUnique _air;
                private _result = [_air,_target,playersSide,_home,format ["%1_%2",_missionId,_index]] call DRO2026_fnc_executeStandoffAirMission;
                if (_result getOrDefault ["ok",false]) then {
                    _released = _released + 1;
                } else {
                    private _reason = _result getOrDefault ["code","NO_WEAPON_RELEASE"];
                    [_farpId,"HELICOPTER_MUNITIONS",1,format ["AIR_NO_RELEASE_REFUND_%1",_reason]] call DRO2026_fnc_changeNetworkNodeStock;
                    _refunded = _refunded + 1;
                    if (_reason == "INGRESS_FAILED" && {isNull _target || {!alive _target}}) then {
                        ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","ABORTED"],["reason","TARGET_LOST"]],_missionId] call DRO2026_fnc_emitEvent;
                    };
                };
                private _return = +_home;
                _return set [2,if (_isHeli) then {100} else {650}];
                if (alive _air && {!isNull driver _air}) then {(driver _air) doMove _return};
                private _deadline = time + 180;
                waitUntil {sleep 2; !alive _air || {_air distance2D _home < 500} || {time > _deadline} || {missionNamespace getVariable ["DRO2026_missionEnding",false]}};
                if (!isNull _air) then {deleteVehicleCrew _air; if (alive _air) then {deleteVehicle _air}};
                if (!isNull _group) then {deleteGroup _group};
            };
        };
        sleep 5;
    };
    DRO2026_activeHeavySupport = (DRO2026_activeHeavySupport - 1) max 0;
    ["AIR_MISSION_STATE_CHANGED",createHashMapFromArray [["missionId",_missionId],["state","COMPLETE"],["released",_released],["requested",_quantity],["refunded",_refunded]],_missionId] call DRO2026_fnc_emitEvent;
    [if (_released > 0) then {"ACK"} else {"ALERT"},format ["Штаб: авиационная задача завершена, выполнено пусков %1 из %2.",_released,_quantity],_requester] call DRO2026_fnc_hqVoice;
};