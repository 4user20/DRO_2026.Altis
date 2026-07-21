from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "cfg": ROOT / "dro2026" / "CfgFunctions.hpp",
    "init": ROOT / "dro2026" / "functions" / "core" / "fn_initState.sqf",
    "position": ROOT / "dro2026" / "functions" / "core" / "fn_normalizePositionASL.sqf",
    "road": ROOT / "dro2026" / "functions" / "core" / "fn_findRoadAwarePosition.sqf",
    "contact": ROOT / "dro2026" / "functions" / "core" / "fn_createContactRecord.sqf",
    "add_contact": ROOT / "dro2026" / "functions" / "directors" / "fn_addContact.sqf",
    "transition": ROOT / "dro2026" / "functions" / "core" / "fn_transitionContactState.sqf",
    "roles": ROOT / "dro2026" / "functions" / "core" / "fn_initStrategicOperationData.sqf",
    "role_resolver": ROOT / "dro2026" / "functions" / "core" / "fn_getAssetPrimaryRole.sqf",
    "role_guard": ROOT / "dro2026" / "functions" / "core" / "fn_isAssetAllowedForRole.sqf",
    "asset_refresh": ROOT / "dro2026" / "functions" / "core" / "fn_refreshFactionAssets.sqf",
    "plan": ROOT / "dro2026" / "functions" / "core" / "fn_buildStrategicPlan.sqf",
    "site_select": ROOT / "dro2026" / "functions" / "core" / "fn_selectStrategicSite.sqf",
    "theater": ROOT / "dro2026" / "functions" / "core" / "fn_buildTheaterGraph.sqf",
    "network": ROOT / "dro2026" / "functions" / "core" / "fn_buildCapabilityNetwork.sqf",
    "node": ROOT / "dro2026" / "functions" / "core" / "fn_createNetworkNode.sqf",
    "effects": ROOT / "dro2026" / "functions" / "core" / "fn_getOperationalEffects.sqf",
    "effects_director": ROOT / "dro2026" / "functions" / "directors" / "fn_capabilityEffectsDirector.sqf",
    "target_select": ROOT / "dro2026" / "functions" / "core" / "fn_selectStrategicTarget.sqf",
    "munition_register": ROOT / "dro2026" / "functions" / "core" / "fn_registerStrategicMunition.sqf",
    "munition_launch": ROOT / "dro2026" / "functions" / "core" / "fn_launchStrategicMunition.sqf",
    "munition_impact": ROOT / "dro2026" / "functions" / "core" / "fn_resolveStrategicImpact.sqf",
    "missile_defence": ROOT / "dro2026" / "functions" / "directors" / "fn_missileDefenceDirector.sqf",
    "strategic_strike": ROOT / "dro2026" / "functions" / "directors" / "fn_strategicStrikeDirector.sqf",
    "site_components": ROOT / "dro2026" / "functions" / "core" / "fn_createSiteComponents.sqf",
    "node_site": ROOT / "dro2026" / "functions" / "core" / "fn_spawnOperationalNodeSite.sqf",
    "point_spawn": ROOT / "dro2026" / "functions" / "core" / "fn_spawnPointDefenceGroup.sqf",
    "point_director": ROOT / "dro2026" / "functions" / "directors" / "fn_pointDefenceDirector.sqf",
    "standoff_weapon": ROOT / "dro2026" / "functions" / "core" / "fn_getStandoffWeapon.sqf",
    "standoff_mission": ROOT / "dro2026" / "functions" / "core" / "fn_executeStandoffAirMission.sqf",
    "enemy_air": ROOT / "dro2026" / "functions" / "directors" / "fn_enemyAirDirector.sqf",
    "enemy_isr": ROOT / "dro2026" / "functions" / "directors" / "fn_enemyISRDirector.sqf",
    "player_air": ROOT / "dro2026" / "functions" / "support" / "fn_requestAirSupport.sqf",
    "infrastructure": ROOT / "dro2026" / "functions" / "core" / "fn_createStrategicInfrastructure.sqf",
    "start": ROOT / "dro2026" / "functions" / "directors" / "fn_startDirectors.sqf",
    "dynamic_objectives": ROOT / "dro2026" / "functions" / "directors" / "fn_dynamicObjectiveDirector.sqf",
    "aa": ROOT / "dro2026" / "functions" / "core" / "fn_spawnLayeredAA.sqf",
    "crew": ROOT / "dro2026" / "functions" / "core" / "fn_crewManagedVehicle.sqf",
    "artillery": ROOT / "dro2026" / "functions" / "objectives" / "fn_artilleryLoop.sqf",
    "logistics": ROOT / "dro2026" / "functions" / "directors" / "fn_logisticsDirector.sqf",
    "long_support": ROOT / "dro2026" / "functions" / "support" / "fn_requestLongRangeSupport.sqf",
    "operation": ROOT / "dro2026" / "functions" / "directors" / "fn_operationDirector.sqf",
    "seed": ROOT / "dro2026" / "functions" / "core" / "fn_seededRandom.sqf",
    "phase": ROOT / "dro2026" / "functions" / "core" / "fn_evaluateOperationPhase.sqf",
    "endgate": ROOT / "dro2026" / "functions" / "core" / "fn_evaluateEndgame.sqf",
    "legacy_end": ROOT / "sunday_system" / "endMission.sqf",
    "sanitize": ROOT / "dro2026" / "functions" / "core" / "fn_sanitizeLegacyPools.sqf",
}

errors: list[str] = []
texts: dict[str, str] = {}
for key, path in FILES.items():
    if not path.exists():
        errors.append(f"missing:{path.relative_to(ROOT)}")
        continue
    texts[key] = path.read_text(encoding="utf-8")

required = {
    "cfg": [
        "class normalizePositionASL {};", "class getOperationalEffects {};",
        "class launchStrategicMunition {};", "class executeStandoffAirMission {};",
        "class capabilityEffectsDirector {};", "class strategicStrikeDirector {};",
        "class missileDefenceDirector {};", "class pointDefenceDirector {};",
    ],
    "init": [
        "DRO2026_activeStrategicMunitions = [];", "DRO2026_MAX_ISKANDER_LAUNCHES = 2",
        "DRO2026_ISKANDER_COOLDOWN = 900", "DRO2026_activeEnemyAirMissions = 0",
    ],
    "position": ['case "ASL"', 'case "ATL"', 'case "AGL"', "ATLToASL", "AGLToASL", "getPosASL _fallbackObject"],
    "road": [
        '["positionATL",[]]', '["positionASL",[]]', '["roadFound",false]',
        '["fallbackReason",""]', "ATLToASL _positionATL", "ATLToASL _fallback",
        "locationPosition _x", "roadsConnectedTo [_road,_allowRoadFallback]",
    ],
    "contact": [
        'getOrDefault ["positionSpace",_defaultSpace]', "DRO2026_fnc_normalizePositionASL",
        '(_subjectNetId find "NODE_") == 0', 'if (_subjectNetId == "" && {!isNull _target}) then {_subjectNetId = netId _target}',
        '["positionSpace","ASL"]', '["stableSubjectId",_stableSubjectId]',
        '["networkOwner",_networkOwner]', '["lastKnownPosition",+_position]',
    ],
    "add_contact": [
        '["_positionSpace", "ATL"', '["positionSpace",toUpperANSI _positionSpace]',
        '["positionASL", +_fusedPos]', '["state","ACTIVE"]',
        'private _knowledgeKey = if (_normalizedOwner == "PLAYER") then {"knownByPlayer"} else {"knownByEnemy"}',
        "DRO2026_fnc_transitionContactState",
    ],
    "transition": ['"ACTIVE","STALE","LOST","DESTROYED","INVALID","EXPIRED"', '["reservationId",""]', '["status","CANCELED"]', '"STATE_TRANSITION"'],
    "roles": [
        '["RUS_MSV_2s3m1", "ARTILLERY_TUBE"]', '["pook_2S7_OPFOR", "ARTILLERY_TUBE_HEAVY"]',
        '["pook_9K720_OPFOR", "BALLISTIC_MISSILE_LAUNCHER"]', '"S300_BATTERY"', '"BM35_LAUNCH_SITE"',
    ],
    "role_resolver": ['(_hay find "9k720")', '"BALLISTIC_MISSILE_LAUNCHER"', '"EARLY_WARNING_RADAR"'],
    "role_guard": ['case "ARTILLERY_POOL"', 'case "INSERTION_POOL"', 'case "LOGISTICS_POOL"'],
    "asset_refresh": [
        '"RUS_VKS_ka52"', '"RUS_VKS_mi24p"', '"RUS_VKS_mi8amtsh"',
        'private _discoverPointDefence', '"kamaz", "урал", "ural"', 'format ["SHORAD_%1",_suffix]',
    ],
    "plan": ['"PLAN_S300_COUNT"', '"PLAN_ISKANDER_COUNT"', '"PLAN_BM35_COUNT"', '["state","VIRTUAL"]'],
    "site_select": ["ATLToASL _positionATL", 'if (!_requireRoad || {!isNull _road})', 'if (_roadPreferred) then {-700}'],
    "theater": ["DRO2026_fnc_buildStrategicPlan", '["ENEMY_AA_LONG","S300_BATTERY"]', '["ENEMY_TACTICAL_REAR","BALLISTIC_MISSILE_SITE"]', '["ENEMY_FARP","FARP"]'],
    "network": [
        '"NODE_BALLISTIC_01", "BALLISTIC_MISSILE_SITE"', '"BALLISTIC_MISSILES", 1',
        '"NODE_FARP_01", "FARP"', '"HELICOPTER_MUNITIONS", 4',
        '"EDGE_LOGISTICS_BALLISTIC"', '"EDGE_LOGISTICS_FARP"', '"EDGE_LOGISTICS_AA_LONG"',
        '"NODE_FRIENDLY_FARP"', '"EDGE_FRIENDLY_LOGISTICS_AA"',
    ],
    "node": [
        'private _defaultPlayerKnowledge = if (_side == playersSide)',
        'private _defaultEnemyKnowledge = if (_side == enemySide)',
        '["knownByPlayer", _existing getOrDefault ["knownByPlayer", _defaultPlayerKnowledge]]',
    ],
    "effects": [
        '["commandFactor",_command]', '["logisticsFactor",_logistics]', '["radarFactor",_radar]',
        '["decisionIntervalMultiplier",_decisionMultiplier]', '["dispatchIntervalMultiplier",_dispatchMultiplier]',
    ],
    "effects_director": [
        'DRO2026_enemyDecisionIntervalMultiplier', '"nominalCapacity"', '"nominalTravelTime"',
        '"SOURCE_CAPABILITY_LOST"', '"CAPABILITY_EFFECTS_UPDATED"',
    ],
    "target_select": [
        '"TRACKED",3', '"CONFIRMED",4', '"HQ","LOGISTICS_HUB","AA_LONG"',
        '"BALLISTIC_MISSILE_SITE"', '"nearestCivilianDistance"', '"NO_CONFIRMED_STRATEGIC_TARGET"',
    ],
    "munition_register": [
        'DRO2026_activeStrategicMunitions', '["state","INBOUND"]', '["radarCrossSection"',
        '"STRATEGIC_MUNITION_LAUNCHED"',
    ],
    "munition_launch": [
        'getNumber (_ammoCfg >> "manualControl") > 0', 'setMissileTargetPos (ASLToATL _targetASL)',
        'DRO2026_fnc_calculateTerrainAwareAim', 'DRO2026_fnc_registerStrategicMunition',
        'DRO2026_fnc_resolveStrategicImpact', 'triggerAmmo _object',
    ],
    "munition_impact": [
        '"stockLossFraction"', '"damagedObjects"', '"destroyedObjects"',
        '"STRATEGIC_IMPACT_RESOLVED"', 'DRO2026_fnc_syncNetworkState',
    ],
    "missile_defence": [
        '"NODE_FRIENDLY_AA_LONG"', '"AA_MISSILES",-1,"STRATEGIC_INTERCEPT_LAUNCH"',
        'private _pKill', '"MISSILE_DEFENCE_ENGAGED"', '"MISSILE_DEFENCE_MISSED"',
        'DRO2026_fnc_resolveStrategicImpact',
    ],
    "strategic_strike": [
        '"NODE_BALLISTIC_01"', 'DRO2026_MAX_ISKANDER_LAUNCHES',
        '"PREPARING"', '"READY"', '"FIRED"', '"DISPLACING"', '"HIDDEN"',
        '"BALLISTIC_MISSILES",-1', 'DRO2026_fnc_selectStrategicTarget',
    ],
    "site_components": [
        '(_typeKey find "LOGISTICS")', '"Land_Cargo20_military_green_F"',
        '(_typeKey find "BALLISTIC")', '(_typeKey find "FARP")',
        '"Land_Pod_Heli_Transport_04_fuel_F"',
    ],
    "node_site": [
        'DRO2026_fnc_createSiteComponents', '["networkNodeId",_nodeId]',
        '["physicalRefs",+_objects]', '"OPERATIONAL_SITE_MATERIALIZED"',
    ],
    "point_spawn": [
        'format ["SHORAD_%1",_suffix]', '"kamaz"', '"ural"', '"zu23"', '"zsu"',
        '"POINT_DEFENCE_AMMO"', 'addEventHandler ["Fired"',
    ],
    "point_director": [
        '"POINT_DEFENCE"', 'DRO2026_activeStrategicMunitions', 'aimedAtTarget', 'fireAtTarget',
    ],
    "standoff_weapon": [
        'allTurrets [_vehicle,true]', '_vehicle weaponsTurret _turretPath',
        '"shotmissile","shotrocket"', '"NO_STANDOFF_WEAPON"',
    ],
    "standoff_mission": [
        '"STANDOFF_INGRESS"', 'DRO2026_fnc_getStandoffWeapon', 'aimedAtTarget [_target,_muzzle]',
        'fireAtTarget [_target,_muzzle]', '"STANDOFF_FIRED"', '"EGRESS"',
    ],
    "enemy_air": [
        '"NODE_FARP_01"', '"HELICOPTER_MUNITIONS"', 'DRO2026_fnc_getStandoffWeapon',
        'DRO2026_fnc_executeStandoffAirMission', 'DRO2026_activeEnemyAirMissions',
        '(_x getOrDefault ["owner",""]) == "ENEMY"',
    ],
    "enemy_isr": [
        'DRO2026_enemySensorIntervalMultiplier', 'DRO2026_fnc_getOperationalEffects',
        '_group addVehicle _uav', 'ATLToASL (_targetPos vectorAdd [0,0,2])',
    ],
    "player_air": [
        '"NODE_FRIENDLY_FARP"', '"HELICOPTER_MUNITIONS"', '"fresh confirmed"' if False else '"Штаб: авиации нужна свежая подтверждённая физическая цель."',
        'DRO2026_fnc_executeStandoffAirMission', '"AIR_NO_RELEASE_REFUND"',
    ],
    "infrastructure": [
        '"NODE_LOGISTICS_01","LOGISTICS_HUB"', '"NODE_BALLISTIC_01","BALLISTIC_MISSILE_SITE"',
        '"NODE_FARP_01","FARP"', 'DRO2026_fnc_spawnPointDefenceGroup',
        'DRO2026_ENABLE_FRIENDLY_LONG_RANGE_AA',
    ],
    "start": [
        'DRO2026_fnc_capabilityEffectsDirector', 'DRO2026_fnc_missileDefenceDirector',
        'DRO2026_fnc_pointDefenceDirector', 'DRO2026_fnc_strategicStrikeDirector',
    ],
    "dynamic_objectives": [
        '"STRATEGIC_MUNITION_DETECTED"', '"STRATEGIC_STRIKE_ORDERED"',
        '"OTRK_HUNT"', '"DEPOT_HUNT"', '"HQ_HUNT"', '"FARP_HUNT"',
        '"DELIVERY_INTERDICTED"', '"DELIVERY_COMPLETED"',
    ],
    "aa": [
        '_launcherCount = if (_side == east && {_longClass == "S300_F_UCG"}) then {2}',
        '"launcherPairDistance"', '"radarMinLauncherDistance"',
        'private _shortAnchor = if (_withLongRange) then {_longPosition}', 'private _bearingJitter = [25,format',
    ],
    "crew": ["if (!local _vehicle)", "_group addVehicle _vehicle"],
    "artillery": [
        "local _arty", "ASLToAGL _aimASL", "getArtilleryETA",
        "doArtilleryFire [_targetPos, _mag, _rounds]", '"targetAreaAGL"',
    ],
    "logistics": [
        '[_source,250,1800,_bearing,true,false,350]', '[_cargoClass,"LOGISTICS_POOL"]',
        '_group addVehicle _vehicle', 'if (!isNull _vehicle && {local _vehicle})',
    ],
    "long_support": [
        'createHashMapFromArray [["positionSpace","ASL"]]',
        'createHashMapFromArray [["positionSpace","ATL"],["stableSubjectId",_subjectId]]',
        'toUpperANSI _type == "FP5"', 'DRO2026_fnc_launchStrategicMunition',
        '"FP-5 Flamingo"', '"BALLISTIC_MISSILE_SITE", "FARP"',
    ],
    "operation": [
        'DRO2026_fnc_getOperationalEffects', 'private _decisionMultiplier',
        '18 * _decisionMultiplier', '0.35 + 0.65 * _commandFactor',
    ],
    "seed": ["private _modulus = 65521", "251 * _state + 13849", "below 2^24"],
    "phase": [
        'switch _oldPhase do', '"DEPLOYMENT"', '"SHAPING"', '"DEEP_STRIKE"',
        '"COUNTERATTACK"', '"EXPLOITATION"', '["missingCapabilities",_missing]',
    ],
    "endgate": [
        '["ready",_ready]', '"STRATEGIC_CONDITIONS_MET"', "DRO2026_MIN_OPERATION_DURATION",
        '"REQUIRED_NETWORK_NODES_MISSING"', '["missingNodes",+_missingNodes]',
    ],
    "legacy_end": [
        "DRO2026_fnc_evaluateEndgame", '"END_REQUEST_DEFERRED"',
        "private _deferEnd = false", "if (_deferEnd) exitWith {}", '"CANCELED"',
    ],
    "sanitize": ['["startVehicles","INSERTION_POOL",true]', '"ARTILLERY_POOL"', '"BALLISTIC_MISSILE_LAUNCHER"'],
}

for key, snippets in required.items():
    text = texts.get(key, "")
    for snippet in snippets:
        if snippet not in text:
            errors.append(f"{key}:missing:{snippet}")

for forbidden in (
    "AGLToASL _positionATL",
    "AGLToASL _fallback",
    "AGLToASL _sideOffset",
):
    if forbidden in texts.get("road", ""):
        errors.append(f"road:forbidden:{forbidden}")

for key, forbidden in {
    "legacy_end": ['if !(_gate getOrDefault ["ready",false]) exitWith'],
    "add_contact": ['["state", switch _bda do'],
    "seed": ["1103515245"],
    "long_support": [
        '["PLAYER", objNull, _position, 0.76, "НАЗНАЧЕННАЯ_ТОЧКА", "PLAYER_DESIGNATION", 120]',
        '_type == "FP5", _operator, _type',
    ],
    "enemy_isr": ["AGLToASL (_targetPos vectorAdd"],
    "enemy_air": ["forEach _humanPlayers", "doMove _targetPos"],
    "strategic_strike": ["allPlayers", "selectRandom allUnits"],
}.items():
    text = texts.get(key, "")
    for snippet in forbidden:
        if snippet in text:
            errors.append(f"{key}:forbidden:{snippet}")

# Basic delimiter scanner catches malformed full-file rewrites before Arma runtime.
pairs = {")": "(", "]": "[", "}": "{"}
for key, text in texts.items():
    stack: list[str] = []
    in_string = False
    escaped = False
    for char in text:
        if char == '"' and not escaped:
            in_string = not in_string
        escaped = char == "\\" and not escaped
        if in_string:
            continue
        if char in "([{":
            stack.append(char)
        elif char in ")]}" :
            if not stack or stack.pop() != pairs[char]:
                errors.append(f"{key}:delimiter-mismatch:{char}")
                break
    if stack:
        errors.append(f"{key}:unclosed-delimiters:{''.join(stack[-8:])}")

result = {
    "validator": "strategic-operational-contracts",
    "failed": bool(errors),
    "checkedFiles": len(texts),
    "errors": errors,
}
print(json.dumps(result, ensure_ascii=False, indent=2))
sys.exit(1 if errors else 0)
