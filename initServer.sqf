#include "sunday_system\fnc_lib\sundayFunctions.sqf"

[] call DRO2026_fnc_initState;

missionNameSpace setVariable ["factionDataReady", 0, true];
missionNameSpace setVariable ["weatherChanged", 0, true];
missionNameSpace setVariable ["factionsChosen", 0, true];
missionNameSpace setVariable ["arsenalComplete", 0, true];
missionNameSpace setVariable ["aoCamPos", [], true];
missionNameSpace setVariable ["dro_introCamReady", 0, true];
missionNameSpace setVariable ["dro_introCamComplete", 0, true];
missionNameSpace setVariable ["briefingReady", 0, true];
missionNameSpace setVariable ["playersReady", 0, true];
missionNameSpace setVariable ["publicCampName", "", true];
missionNameSpace setVariable ["startPos", [], true];
missionNameSpace setVariable ["initArsenal", 0, true];
missionNameSpace setVariable ["allArsenalComplete", 0, true];
missionNameSpace setVariable ["aoComplete", 0, true];
missionNameSpace setVariable ["objectivesSpawned", 0, true];
missionNameSpace setVariable ["aoLocationName", "", true];
missionNameSpace setVariable ["aoLocation", "", true];
missionNameSpace setVariable ["lobbyComplete", 0, true];

private _requestedRespawnMode = paramsArray param [0, 1];
private _respawnDisabled = _requestedRespawnMode == 3;
missionNamespace setVariable ["DRO2026_respawnDisabled", _respawnDisabled, true];

// Legacy start.sqf assigns nil in mode 3 and then publicVariables the deleted variable.
// Feed it a safe value only until the first assignment has completed, then restore the
// original mission parameter and publish the explicit -1 sentinel used by all handlers.
if (_respawnDisabled) then {paramsArray set [0, 2]};
[] execVM "start.sqf";

if (_respawnDisabled) then {
    [_requestedRespawnMode] spawn {
        params ["_requestedRespawnMode"];
        private _deadline = diag_tickTime + 15;
        waitUntil {
            sleep 0.01;
            !isNil "respawnTime" || {diag_tickTime > _deadline}
        };
        paramsArray set [0, _requestedRespawnMode];
        respawnTime = -1;
        publicVariable "respawnTime";
        missionNamespace setVariable ["DRO2026_respawnDisabled", true, true];
    };
};