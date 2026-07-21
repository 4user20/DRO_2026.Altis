from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="replace")


def summarize_hits(lines: list[str], pattern: re.Pattern[str], *, limit: int = 4) -> dict[str, object]:
    hits: list[dict[str, object]] = []
    count = 0
    first_line = None
    last_line = None
    for index, line in enumerate(lines, 1):
        if not pattern.search(line):
            continue
        count += 1
        first_line = index if first_line is None else first_line
        last_line = index
        if len(hits) < limit:
            hits.append({"line": index, "text": line[:280]})
    return {
        "count": count,
        "firstLine": first_line,
        "lastLine": last_line,
        "examples": hits,
    }


parser = ArgumentParser(description="DRO 2026 RPT/support/objective stabilization checks")
parser.add_argument("--rpt", action="append", default=[])
parser.add_argument("--require-hemtt", action="store_true")
parser.add_argument(
    "--skip-base",
    action="store_true",
    help="Skip validate_rc6.py when an outer canonical runner already executed it.",
)
args = parser.parse_args()

errors: list[str] = []
validator_output: dict[str, str] = {}
base_exit = 0
if not args.skip_base:
    base_args = [sys.executable, str(ROOT / "tools" / "validate_rc6.py")]
    if args.require_hemtt:
        base_args.append("--require-hemtt")
    for rpt in args.rpt:
        base_args.extend(["--rpt", rpt])
    base = subprocess.run(
        base_args,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    base_exit = base.returncode
    if base.returncode != 0:
        errors.append("base validate_rc6.py failed")
        validator_output["validate_rc6.py"] = base.stdout[-12000:]

contracts = {
    "tools/arma_source_manifest.json": (
        '"acemod-arma3-wiki"',
        '"stokys-scripting-guide"',
        '"offlineValidation": true',
    ),
    "dro2026/functions/core/fn_publishSupportCatalog.sqf": (
        "DRO2026_supportCatalog",
        "STRIKE_CLASS:",
        "ISR_CLASS:",
        "DRO2026_SUPPORT_EXPOSE_ALL_INSTALLED",
    ),
    "dro2026/functions/core/fn_getStandoffWeapon.sqf": (
        "_vehicle weaponsTurret _turretPath",
        "allTurrets",
    ),
    "dro2026/functions/support/fn_openSupportConsole.sqf": (
        "_availableCategories",
        "DRO2026_supportCatalog",
        "RscCombo",
    ),
    "dro2026/functions/support/fn_beginSupportTargeting.sqf": (
        "FPV_CLASS_AUTO:",
        "STRIKE_CLASS:",
        "ARTY:",
        "AIR:",
    ),
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        "targetASL",
        "FPV_MISSION_RESULT",
        "_requestedClassAllowed",
    ),
    "dro2026/functions/drone/fn_fpvAttackController.sqf": (
        "getPosASL",
        "ASLToAGL _targetASL",
        "FPV_MAX_TURN_RATE",
        '"TARGET_LOST"',
    ),
    "dro2026/functions/support/fn_requestFPV.sqf": (
        "_unlaunched",
        "FPV salvo aborted",
        'DRO2026_resources set ["friendlyFPVStock"',
        "_requestedClassAllowed",
    ),
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf": (
        "FPV_SALVO_ABORT",
        "_unlaunched",
        "DRO2026_fnc_launchFPVStrike",
        "DRO2026_heavySystemsPaused",
    ),
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf": (
        'if (_requestUpper == "FP5") then {"friendlyFP5Stock"}',
        "_costPool",
        "_unlaunched",
    ),
    "dro2026/functions/support/fn_requestAirSupport.sqf": (
        "_refundTail",
        "TARGETS_LOST_BEFORE_LAUNCH",
        "AIR_WINDOW_CLOSED_BEFORE_LAUNCH",
    ),
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf": (
        "_catalogHasMode",
        '"STRIKE_FP5"',
        '"STRIKE_AUTO"',
        'isKindOf "VirtualMan_F"',
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        "DRO2026_fnc_isLiveContactSubject",
        "LONG_RANGE_SALVO_ABORT",
        '"CANCELLED"',
        "DRO2026_heavySystemsPaused",
    ),
    "dro2026/functions/objectives/fn_selectObjective.sqf": (
        "_maxAttempts = 4",
        "OBJECTIVE_MATERIALIZATION_FAILED",
    ),
    "dro2026/functions/objectives/fn_objectiveISRRecon.sqf": (
        "ISR_RELAY",
        "Land_TTowerSmall_1_F",
        'isKindOf "VirtualMan_F"',
    ),
    "dro2026/functions/objectives/fn_objectiveConvoy.sqf": (
        "validateSiteRecord",
        "OBJECTIVE_CONVOY_REFUND",
        "OBJECTIVE_CONVOY_CANCELLED",
        '"CANCELLED"',
    ),
    "dro2026/functions/directors/fn_logisticsDirector.sqf": (
        "_setSiteState",
        '"siteRecord"',
        '"DELIVERY_INTERDICTED"',
        '"DELIVERY_COMPLETED"',
        '"CANCELED"',
        "DRO2026_heavySystemsPaused",
    ),
    "dro2026/functions/directors/fn_performanceGovernor.sqf": (
        "diag_fps",
        "DRO2026_heavySystemsPaused",
        "DRO2026_fnc_syncNetworkState",
        '"PERF","SNAPSHOT"',
    ),
}

for relative, tokens in contracts.items():
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing file: {relative}")
        continue
    source = read(relative)
    missing = [token for token in tokens if token not in source]
    if missing:
        errors.append(f"{relative}: missing {', '.join(missing)}")

forbidden = {
    "dro2026/functions/core/fn_getStandoffWeapon.sqf": (
        "weaponsTurret [_vehicle",
    ),
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        "nearestObjects",
        "_drone setDir",
        "AGLToASL _targetASL",
    ),
    "dro2026/functions/drone/fn_fpvAttackController.sqf": (
        "doMove",
        "AGLToASL _targetASL",
    ),
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf": (
        "nearestObjects",
        "_drone setDir",
    ),
    "dro2026/functions/directors/fn_enemyAirDirector.sqf": (
        'getOrDefault ["AIR_EAST"',
        "alive player",
        "vehicle player",
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        "private _isLiveStrategicContact",
    ),
    "dro2026/functions/directors/fn_logisticsDirector.sqf": (
        "[] call DRO2026_fnc_syncNetworkState",
    ),
}
for relative, tokens in forbidden.items():
    source = read(relative)
    found = [token for token in tokens if token in source]
    if found:
        errors.append(f"{relative}: forbidden {', '.join(found)}")

# RPT findings are separated by ownership. Mission-owned expression failures and
# severe runtime/performance regressions fail the gate. Add-on/config defects are
# still reported, but they are not falsely attributed to mission SQF.
mission_patterns = {
    "mission source error reference": re.compile(
        r"File .*?dro2026\\.*?\.sqf",
        re.I,
    ),
    "mission undefined variable": re.compile(
        r"Undefined variable in expression: _(?:thisFac|isPlayerFaction|isEnemyFaction|spawnDirection|"
        r"applyFlightVector|sideSuffix|reservationNodeId|cleanupDeliveryVehicles|setDeliverySiteStatus)",
        re.I,
    ),
    "legacy TOS support": re.compile(r"_artyVeh\s*=.*pook_TOS1A", re.I),
    "wrong weapon selection": re.compile(r"Wrong weapon selection", re.I),
}
external_patterns = {
    "PiR script errors": re.compile(r"PiR\\Functions\\UnconditionFind\.sqf", re.I),
    "ARI_AO missing scripts": re.compile(r"ARI_AO\\scripts\\nuclear\\fnc\\(?:getDamageMultiplier|checkNukeDropped)\.sqf", re.I),
    "add-on cloudlet expressions": re.compile(r"CfgCloudlets|Undefined variable in expression: (?:speed[xyz]|position[xyz])", re.I),
    "config No entry": re.compile(r"Warning Message: No entry ", re.I),
    "config slash value": re.compile(r"Warning Message: '/' is not a value", re.I),
    "model SelectionID": re.compile(r"SelectionID .* is wrong for shape", re.I),
    "model shadow geometry": re.compile(r"shadow geometry is not closed|Warnings in .*:shadow", re.I),
    "missing add-on sound": re.compile(r"Cannot load sound .*rocket_1\.wss|Sound .*rocket_1\.wss not found", re.I),
}
performance_patterns = {
    "fire handler log spam": re.compile(r"\[DEBUG\] FIRED", re.I),
    "slow shape generation": re.compile(r"Generating ST on the fly is very slow", re.I),
    "watchdog freeze": re.compile(r"No alive in \d+ ms", re.I),
}

rpt_reports: list[dict[str, object]] = []
rpt_gate_failed = False
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        errors.append(f"RPT not found: {path}")
        continue
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    mission = {name: summarize_hits(lines, pattern) for name, pattern in mission_patterns.items()}
    external = {name: summarize_hits(lines, pattern) for name, pattern in external_patterns.items()}
    performance = {name: summarize_hits(lines, pattern) for name, pattern in performance_patterns.items()}

    mission_count = sum(int(item["count"]) for item in mission.values())
    fire_spam_count = int(performance["fire handler log spam"]["count"])
    watchdog_count = int(performance["watchdog freeze"]["count"])
    severe_runtime = mission_count > 0 or watchdog_count > 0 or fire_spam_count >= 250
    rpt_gate_failed = rpt_gate_failed or severe_runtime
    rpt_reports.append(
        {
            "path": str(path),
            "lineCount": len(lines),
            "gateFailed": severe_runtime,
            "missionFindings": mission,
            "externalAddonFindings": external,
            "performanceFindings": performance,
            "notes": [
                "Old RPTs remain failed after source fixes; rerun the patched mission to clear mission-owned findings.",
                "External add-on findings are reported separately and require updating/removing the owning mod.",
                "Fire-handler spam cannot be safely removed with removeAllEventHandlers; the owning add-on must be identified or fixed.",
            ],
        }
    )

report = {
    "validator": "rc6-rpt-stabilization",
    "base_validator_skipped": args.skip_base,
    "base_validator_exit": base_exit,
    "validator_output": validator_output,
    "errors": errors,
    "rpt_gate_failed": rpt_gate_failed,
    "rpt_reports": rpt_reports,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors or rpt_gate_failed else 0)
