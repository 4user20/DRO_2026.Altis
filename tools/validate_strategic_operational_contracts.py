from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "cfg": ROOT / "dro2026" / "CfgFunctions.hpp",
    "position": ROOT / "dro2026" / "functions" / "core" / "fn_normalizePositionASL.sqf",
    "road": ROOT / "dro2026" / "functions" / "core" / "fn_findRoadAwarePosition.sqf",
    "contact": ROOT / "dro2026" / "functions" / "core" / "fn_createContactRecord.sqf",
    "add_contact": ROOT / "dro2026" / "functions" / "directors" / "fn_addContact.sqf",
    "transition": ROOT / "dro2026" / "functions" / "core" / "fn_transitionContactState.sqf",
    "roles": ROOT / "dro2026" / "functions" / "core" / "fn_initStrategicOperationData.sqf",
    "role_resolver": ROOT / "dro2026" / "functions" / "core" / "fn_getAssetPrimaryRole.sqf",
    "role_guard": ROOT / "dro2026" / "functions" / "core" / "fn_isAssetAllowedForRole.sqf",
    "plan": ROOT / "dro2026" / "functions" / "core" / "fn_buildStrategicPlan.sqf",
    "site_select": ROOT / "dro2026" / "functions" / "core" / "fn_selectStrategicSite.sqf",
    "theater": ROOT / "dro2026" / "functions" / "core" / "fn_buildTheaterGraph.sqf",
    "aa": ROOT / "dro2026" / "functions" / "core" / "fn_spawnLayeredAA.sqf",
    "crew": ROOT / "dro2026" / "functions" / "core" / "fn_crewManagedVehicle.sqf",
    "artillery": ROOT / "dro2026" / "functions" / "objectives" / "fn_artilleryLoop.sqf",
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
        "class normalizePositionASL {};",
        "class initStrategicOperationData {};",
        "class transitionContactState {};",
        "class evaluateEndgame {};",
    ],
    "position": [
        'case "ASL"', 'case "ATL"', 'case "AGL"',
        "ATLToASL", "AGLToASL", "getPosASL _fallbackObject",
    ],
    "road": [
        '["positionATL",[]]', '["positionASL",[]]', '["roadFound",false]',
        '["fallbackReason",""]', "ATLToASL _positionATL", "ATLToASL _fallback",
        "locationPosition _x", "roadsConnectedTo [_road,_allowRoadFallback]",
    ],
    "contact": [
        'getOrDefault ["positionSpace","ASL"]', "DRO2026_fnc_normalizePositionASL",
        '["positionSpace","ASL"]', '["stableSubjectId",_stableSubjectId]',
        '["networkOwner",_networkOwner]', '["lastKnownPosition",+_position]',
    ],
    "add_contact": [
        '["_positionSpace", "ATL"', '["positionSpace",toUpperANSI _positionSpace]',
        '["positionASL", +_fusedPos]', '["state","ACTIVE"]',
        "DRO2026_fnc_transitionContactState",
    ],
    "transition": [
        '"ACTIVE","STALE","LOST","DESTROYED","INVALID","EXPIRED"',
        '["reservationId",""]', '["status","CANCELED"]', '"STATE_TRANSITION"',
    ],
    "roles": [
        '["RUS_MSV_2s3m1", "ARTILLERY_TUBE"]',
        '["pook_2S7_OPFOR", "ARTILLERY_TUBE_HEAVY"]',
        '["pook_9K720_OPFOR", "BALLISTIC_MISSILE_LAUNCHER"]',
        '"S300_BATTERY"', '"BM35_LAUNCH_SITE"',
    ],
    "role_resolver": ['(_hay find "9k720")', '"BALLISTIC_MISSILE_LAUNCHER"', '"EARLY_WARNING_RADAR"'],
    "role_guard": ['case "ARTILLERY_POOL"', 'case "INSERTION_POOL"', 'case "LOGISTICS_POOL"'],
    "plan": ['"PLAN_S300_COUNT"', '"PLAN_ISKANDER_COUNT"', '"PLAN_BM35_COUNT"', '["state","VIRTUAL"]'],
    "site_select": ["ATLToASL _positionATL", 'if (!_requireRoad || {!isNull _road})', 'if (_roadPreferred) then {-700}'],
    "theater": ["DRO2026_fnc_buildStrategicPlan", '["ENEMY_AA_LONG","S300_BATTERY"]', '["ENEMY_TACTICAL_REAR","BALLISTIC_MISSILE_SITE"]'],
    "aa": [
        '_launcherCount = if (_side == east && {_longClass == "S300_F_UCG"}) then {2}',
        '"launcherPairDistance"', '"radarMinLauncherDistance"',
        'private _shortAnchor = if (_withLongRange) then {_longPosition}',
    ],
    "crew": ["if (!local _vehicle)", "_group addVehicle _vehicle"],
    "artillery": [
        "local _arty", "ASLToAGL _aimASL", "getArtilleryETA",
        "doArtilleryFire [_targetPos, _mag, _rounds]", '"targetAreaAGL"',
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

if 'if !(_gate getOrDefault ["ready",false]) exitWith' in texts.get("legacy_end", ""):
    errors.append("legacy_end:forbidden:nested-exitWith-endgame-gate")
if '["state", switch _bda do' in texts.get("add_contact", ""):
    errors.append("add_contact:forbidden:bda-as-lifecycle-state")
if "1103515245" in texts.get("seed", ""):
    errors.append("seed:forbidden:large-imprecise-lcg")

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
