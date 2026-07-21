from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "preinit": ROOT / "dro2026/functions/core/fn_preInit.sqf",
    "site_record": ROOT / "dro2026/functions/core/fn_createSiteRecord.sqf",
    "site_eval": ROOT / "dro2026/functions/core/fn_evaluateSiteComponents.sqf",
    "network_sync": ROOT / "dro2026/functions/core/fn_syncNetworkState.sqf",
    "effects": ROOT / "dro2026/functions/core/fn_getOperationalEffects.sqf",
    "infrastructure": ROOT / "dro2026/functions/core/fn_createStrategicInfrastructure.sqf",
    "aa_objective": ROOT / "dro2026/functions/objectives/fn_objectiveAirDefence.sqf",
    "aa_director": ROOT / "dro2026/functions/directors/fn_airDefenceDirector.sqf",
    "missile_defence": ROOT / "dro2026/functions/directors/fn_missileDefenceDirector.sqf",
    "strategic_strike": ROOT / "dro2026/functions/directors/fn_strategicStrikeDirector.sqf",
    "point_defence": ROOT / "dro2026/functions/directors/fn_pointDefenceDirector.sqf",
    "dynamic_tasks": ROOT / "dro2026/functions/directors/fn_dynamicObjectiveDirector.sqf",
    "long_support": ROOT / "dro2026/functions/support/fn_requestLongRangeSupport.sqf",
    "air_support": ROOT / "dro2026/functions/support/fn_requestAirSupport.sqf",
    "logistics": ROOT / "dro2026/functions/directors/fn_logisticsDirector.sqf",
    "standoff_weapon": ROOT / "dro2026/functions/core/fn_getStandoffWeapon.sqf",
    "terrain_aim": ROOT / "dro2026/functions/core/fn_calculateTerrainAwareAim.sqf",
    "fpv_controller": ROOT / "dro2026/functions/drone/fn_fpvAttackController.sqf",
    "long_strike_controller": ROOT / "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    "support_setup": ROOT / "sunday_system/player_setup/addSupports.sqf",
    "asset_discovery": ROOT / "dro2026/functions/core/fn_refreshFactionAssets.sqf",
}

errors: list[str] = []
texts: dict[str, str] = {}
for key, path in FILES.items():
    if not path.exists():
        errors.append(f"missing:{path.relative_to(ROOT)}")
    else:
        texts[key] = path.read_text(encoding="utf-8")

required = {
    "preinit": [
        'DRO2026_ENABLE_FRIENDLY_LONG_RANGE_AA = true',
        'DRO2026_MAX_LONG_RANGE_AA_SITES_PER_SIDE = 1',
        'DRO2026_MAX_ENEMY_POINT_DEFENCE_SITES = 2',
        'DRO2026_MAX_ISKANDER_LAUNCHES = 2',
    ],
    "site_record": [
        '["schema",3]', '["positionATL",+_positionATL]', '["positionASL",+_positionASL]',
        'private _positionASL = ATLToASL _positionATL',
    ],
    "site_eval": [
        '"componentHealth"', '"stockHealth"', '"launch"', '"control"', '"detect"', '"resupply"',
    ],
    "network_sync": [
        'case "FRIENDLY_LAYERED_AA": {"NODE_FRIENDLY_AA_LONG"}',
        'case "BALLISTIC_MISSILE_SITE": {"NODE_BALLISTIC_01"}',
        '"PHYSICAL_STOCKS_DESTROYED"', '"lossFraction"',
        '_nodeComponents set ["radar"', '_nodeComponents set ["commandLink"',
    ],
    "effects": [
        '["commandFactor",_command]', '["logisticsFactor",_logistics]', '["radarFactor",_radar]',
        '["warehouse","commandLink"]', '["launcher","commandLink","mobility"]',
    ],
    "infrastructure": [
        '"NODE_BALLISTIC_01","BALLISTIC_MISSILE_SITE"',
        '"NODE_FARP_01","FARP"',
        'DRO2026_fnc_spawnPointDefenceGroup',
    ],
    "aa_objective": [
        'private _existingSites', '"reusedStrategicBattery"',
        'отдельная вторая батарея для этой задачи не создаётся',
    ],
    "aa_director": [
        '"NODE_FRIENDLY_AA_LONG"', '"AA_MISSILES", -1, "AA_LAUNCH"',
        '_asset setVehicleAmmo 1', '_asset setVehicleAmmo 0',
        '"AA_LAUNCH_REJECTED"',
    ],
    "missile_defence": [
        'private _physicalLaunchers', 'canFire _x',
        '"STRATEGIC_INTERCEPT_LAUNCH"', 'private _pKill',
        '"MISSILE_DEFENCE_MISSED"', 'private _launcher =',
    ],
    "strategic_strike": [
        'private _physicalLaunchers', '"BALLISTIC_MISSILE_LAUNCHER"',
        'private _originATL = getPosATL _launcher',
        'DRO2026_fnc_findRoadAwarePosition', 'forceFollowRoad true',
        '"BALLISTIC_LAUNCHER_DISPLACED"', '"BALLISTIC_LAUNCHER_RELOCATION_FAILED"',
    ],
    "point_defence": [
        '_air isKindOf "Air"', 'doTarget objNull', 'disableAI "AUTOTARGET"',
        '_vehicle setVehicleAmmo 0', '_vehicle setVehicleAmmo 1',
    ],
    "dynamic_tasks": [
        'private _defender = _payload getOrDefault ["defender",""]',
        'if (_defender == str playersSide)', '"OTRK_HUNT"', '"DEPOT_HUNT"', '"FARP_HUNT"',
    ],
    "long_support": [
        'toUpperANSI _type == "FP5"', 'DRO2026_fnc_launchStrategicMunition', '"FP-5 Flamingo"',
    ],
    "air_support": [
        '"NODE_FRIENDLY_FARP"', 'DRO2026_fnc_executeStandoffAirMission',
        '"TARGETS_LOST_BEFORE_LAUNCH"', '"AIR_WINDOW_CLOSED_BEFORE_LAUNCH"',
        '"AIR_NO_RELEASE_REFUND"',
    ],
    "logistics": [
        'DRO2026_fnc_findRoadAwarePosition', '"DELIVERY_MATERIALIZATION_REFUND"',
        'DRO2026_MAX_ACTIVE_LOGISTICS_JOBS_PER_SIDE',
    ],
    "standoff_weapon": [
        '_vehicle weaponsTurret _turretPath', '"NO_STANDOFF_WEAPON"',
    ],
    "terrain_aim": [
        '"_destinationASL"', 'private _destinationATL = ASLToATL _destinationASL',
        'private _aimASL = ATLToASL _noiseATL',
    ],
    "fpv_controller": [
        'private _targetPositionASL', 'getPosASL _target', '"FPV_GUIDANCE_FINISHED"',
    ],
    "long_strike_controller": [
        'private _targetPosASL', 'getPosASL _target', '_targetPosASL vectorDiff _spawnASL',
    ],
    "support_setup": [
        'private _enabled = ["UAV", "ARTY", "CAS", "SUPPLY"]',
        'DRO2026_fnc_publishSupportCatalog',
    ],
    "asset_discovery": [
        'private _discoverLoadedPlayerSupport', 'private _discoverLoadedStrikeAmmo',
        '"PLAYER_CAS_AIR"', 'format ["FPV_%1",_playerSuffix]', 'format ["LONG_RANGE_%1",_playerSuffix]',
    ],
}


def compact(value: str) -> str:
    return "".join(value.split())


for key, snippets in required.items():
    text = texts.get(key, "")
    compact_text = compact(text)
    for snippet in snippets:
        if snippet not in text and compact(snippet) not in compact_text:
            errors.append(f"{key}:missing:{snippet}")

for key, forbidden in {
    "site_record": ["AGLToASL _positionATL"],
    "strategic_strike": ["DRO2026_assetRegistry getOrDefault [_role", "selectRandom allUnits", "allPlayers"],
    "point_defence": ["doMove"],
    "dynamic_tasks": ['case "STRATEGIC_MUNITION_DETECTED": { private _munitionId'],
    "standoff_weapon": ['weaponsTurret [_vehicle,_turretPath]'],
    "terrain_aim": ['AGLToASL _destinationASL', '"_destinationAGL"'],
    "fpv_controller": ['getPosATL _target) vectorAdd'],
    "support_setup": ['if (random 1 > 0.30)', 'if (random 1 > 0.42)', 'if (random 1 > 0.48)'],
}.items():
    text = texts.get(key, "")
    compact_text = compact(text)
    for snippet in forbidden:
        if snippet in text or compact(snippet) in compact_text:
            errors.append(f"{key}:forbidden:{snippet}")

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
    "validator": "interactive-operational-contracts",
    "failed": bool(errors),
    "checkedFiles": len(texts),
    "errors": errors,
}
print(json.dumps(result, ensure_ascii=False, indent=2))
sys.exit(1 if errors else 0)
