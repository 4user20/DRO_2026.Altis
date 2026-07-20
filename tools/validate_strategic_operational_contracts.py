from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "cfg": ROOT / "dro2026" / "CfgFunctions.hpp",
    "road": ROOT / "dro2026" / "functions" / "core" / "fn_findRoadAwarePosition.sqf",
    "contact": ROOT / "dro2026" / "functions" / "core" / "fn_createContactRecord.sqf",
    "transition": ROOT / "dro2026" / "functions" / "core" / "fn_transitionContactState.sqf",
    "roles": ROOT / "dro2026" / "functions" / "core" / "fn_initStrategicOperationData.sqf",
    "role_resolver": ROOT / "dro2026" / "functions" / "core" / "fn_getAssetPrimaryRole.sqf",
    "role_guard": ROOT / "dro2026" / "functions" / "core" / "fn_isAssetAllowedForRole.sqf",
    "plan": ROOT / "dro2026" / "functions" / "core" / "fn_buildStrategicPlan.sqf",
    "theater": ROOT / "dro2026" / "functions" / "core" / "fn_buildTheaterGraph.sqf",
    "aa": ROOT / "dro2026" / "functions" / "core" / "fn_spawnLayeredAA.sqf",
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
        "class initStrategicOperationData {};",
        "class registerStrategicAssets {};",
        "class transitionContactState {};",
        "class evaluateEndgame {};",
    ],
    "road": [
        '["positionATL",[]]', '["positionASL",[]]', '["roadFound",false]',
        '["fallbackReason",""]', "AGLToASL _positionATL",
    ],
    "contact": [
        '["stableSubjectId",_stableSubjectId]', '["networkOwner",_networkOwner]',
        '["lastKnownPosition",+_position]', '["terminalReason",""]',
    ],
    "transition": [
        '"ACTIVE","STALE","LOST","DESTROYED","INVALID","EXPIRED"',
        '["reservationId",""]', '"STATE_TRANSITION"',
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
    "theater": ["DRO2026_fnc_buildStrategicPlan", '["ENEMY_AA_LONG","S300_BATTERY"]', '["ENEMY_TACTICAL_REAR","BALLISTIC_MISSILE_SITE"]'],
    "aa": ['_launcherCount = if (_side == east && {_longClass == "S300_F_UCG"}) then {2}', '["formationTemplate","S300_BATTERY"]'],
    "phase": ['"DEPLOYMENT"', '"SHAPING"', '"DEEP_STRIKE"', '"COUNTERATTACK"', '"EXPLOITATION"', '"ENDGAME"'],
    "endgate": ['["ready",_ready]', '"STRATEGIC_CONDITIONS_MET"', 'DRO2026_MIN_OPERATION_DURATION'],
    "legacy_end": ["DRO2026_fnc_evaluateEndgame", '"END_REQUEST_DEFERRED"'],
    "sanitize": ['["startVehicles","INSERTION_POOL",true]', '"ARTILLERY_POOL"', '"BALLISTIC_MISSILE_LAUNCHER"'],
}
for key, snippets in required.items():
    text = texts.get(key, "")
    for snippet in snippets:
        if snippet not in text:
            errors.append(f"{key}:missing:{snippet}")

if "AGLToASL _sideOffset" in texts.get("road", ""):
    errors.append("road:forbidden:AGLToASL _sideOffset")

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
