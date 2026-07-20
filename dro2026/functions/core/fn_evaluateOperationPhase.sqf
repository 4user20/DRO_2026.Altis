if (!isServer) exitWith {DRO2026_operationState getOrDefault ["phase","DEPLOYMENT"]};
if !(missionNamespace getVariable ["DRO2026_networkBuilt",false]) exitWith {"DEPLOYMENT"};

private _keyNodes = [
    "NODE_LOGISTICS_01","NODE_ARTILLERY_01","NODE_FPV_FORWARD_01",
    "NODE_DRONE_REAR_01","NODE_EW_01","NODE_AA_LONG_01","NODE_AA_SHORAD_01","NODE_ENEMY_HQ"
];
private _active = 0;
private _degraded = 0;
private _destroyed = 0;
private _missing = 0;
{
    private _node = DRO2026_networkNodes getOrDefault [_x,createHashMap];
    if (count _node == 0) then {
        _missing = _missing + 1;
    } else {
        switch (toUpperANSI (_node getOrDefault ["status","ACTIVE"])) do {
            case "DESTROYED": {_destroyed = _destroyed + 1};
            case "DISABLED": {_destroyed = _destroyed + 1};
            case "CANCELED": {_destroyed = _destroyed + 1};
            case "CANCELLED": {_destroyed = _destroyed + 1};
            case "DEGRADED": {_degraded = _degraded + 1};
            default {_active = _active + 1};
        };
    };
} forEach _keyNodes;

private _confirmedIntel = count (DRO2026_contacts select {
    (_x getOrDefault ["owner",""]) == "PLAYER" &&
    {(_x getOrDefault ["confidence",0]) >= 0.58} &&
    {!((toUpperANSI (_x getOrDefault ["state","ACTIVE"])) in ["LOST","DESTROYED","INVALID","EXPIRED"])} &&
    {!((_x getOrDefault ["bdaState","DETECTED"]) in ["PROBABLY_DESTROYED", "CONFIRMED_DESTROYED"])}
});
private _interdictions = count (DRO2026_eventLog select {
    (_x getOrDefault ["type",""]) in ["DELIVERY_INTERDICTED","SITE_DESTROYED","NETWORK_NODE_DESTROYED","OBJECTIVE_COMPLETED"]
});
private _presentCount = (_active + _degraded + _destroyed) max 1;
private _networkHealth = linearConversion [0,_presentCount,_active + (_degraded * 0.5),0,1,true];
private _oldPhase = DRO2026_operationState getOrDefault ["phase","DEPLOYMENT"];
private _phase = _oldPhase;
private _elapsed = time - (DRO2026_operationState getOrDefault ["startedAt",time]);

switch _oldPhase do {
    case "DEPLOYMENT": {if (_elapsed >= 30) then {_phase = "RECON"}};
    case "RECON": {if (_confirmedIntel >= 2 || {DRO2026_alertLevel >= 0.30}) then {_phase = "SHAPING"}};
    case "SHAPING": {if (_interdictions > 0 || {_destroyed >= 1} || {_networkHealth <= 0.82}) then {_phase = "DISRUPTION"}};
    case "DISRUPTION": {if (_destroyed >= 2 || {_networkHealth <= 0.68}) then {_phase = "DEEP_STRIKE"}};
    case "DEEP_STRIKE": {if (DRO2026_alertLevel >= 0.55 && {_destroyed >= 3 || {_networkHealth <= 0.55}}) then {_phase = "COUNTERATTACK"}};
    case "COUNTERATTACK": {if (_destroyed >= 4 || {_networkHealth <= 0.42}) then {_phase = "EXPLOITATION"}};
};

private _alertState = if (DRO2026_alertLevel < 0.32) then {"GREEN"} else {
    if (DRO2026_alertLevel < 0.62) then {"YELLOW"} else {"RED"}
};
DRO2026_operationState set ["alertState",_alertState];
DRO2026_operationState set ["networkHealth",_networkHealth];
DRO2026_operationState set ["activeCapabilities",_active];
DRO2026_operationState set ["degradedCapabilities",_degraded];
DRO2026_operationState set ["destroyedCapabilities",_destroyed];
DRO2026_operationState set ["missingCapabilities",_missing];
DRO2026_operationState set ["operationScore",round ((1 - _networkHealth) * 70 + (DRO2026_intelQuality * 20) - (DRO2026_alertLevel * 10))];

private _endgame = [] call DRO2026_fnc_evaluateEndgame;
if (_endgame getOrDefault ["ready",false]) then {_phase = "ENDGAME"};

if (_phase != _oldPhase) then {
    DRO2026_operationState set ["phase",_phase];
    DRO2026_operationState set ["lastPhaseChange",time];
    ["PHASE_CHANGED",createHashMapFromArray [
        ["from",_oldPhase],["to",_phase],["networkHealth",_networkHealth],
        ["confirmedIntel",_confirmedIntel],["interdictions",_interdictions],["missingCapabilities",_missing]
    ],"OPERATION"] call DRO2026_fnc_emitEvent;
    [format ["Фаза операции: %1 -> %2, здоровье сети %3%%",_oldPhase,_phase,round (_networkHealth * 100)]] call DRO2026_fnc_log;
};
_phase
