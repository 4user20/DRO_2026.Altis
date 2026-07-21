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
        validator_output["validate_rc6.py"] = base.stdout

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
    "dro2026/functions/support/fn_requestFPV.sqf": (
        "_unlaunched",
        "FPV salvo aborted",
        'DRO2026_resources set ["friendlyFPVStock"',
    ),
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf": (
        "FPV_SALVO_ABORT",
        "_unlaunched",
        "DRO2026_fnc_launchFPVStrike",
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
        '"siteRecord"',
        '"DELIVERY_INTERDICTED"',
        '"DELIVERY_COMPLETED"',
        '"DELIVERY_MATERIALIZATION_REFUND"',
        '"RETURNING"',
        '"TRANSFERRING"',
        '"CANCELED"',
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
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        "nearestObjects",
        "_drone setDir",
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
}
for relative, tokens in forbidden.items():
    source = read(relative)
    found = [token for token in tokens if token in source]
    if found:
        errors.append(f"{relative}: forbidden {', '.join(found)}")

mission_rpt_patterns = {
    "mission expression error": re.compile(
        r"Error in expression[\s\S]{0,650}?File .*?DRO_2026\.Altis\\dro2026\\functions\\",
        re.I,
    ),
    "faction/locality undefined": re.compile(
        r"Undefined variable in expression: _(?:thisFac|isPlayerFaction|"
        r"isEnemyFaction|spawnDirection|applyFlightVector|sideSuffix|"
        r"reservationNodeId|cleanupDeliveryVehicles|setDeliverySiteStatus)",
        re.I,
    ),
    "type mismatch": re.compile(r"Error Тип (?:Массив|Объект|Группа|Строка|Число), ожидался", re.I),
    "legacy TOS support": re.compile(r"_artyVeh\s*=.*pook_TOS1A", re.I),
    "watchdog freeze": re.compile(r"No alive in \d+ ms", re.I),
}
external_rpt_patterns = {
    "external PiR expression error": re.compile(r"File PiR\\Functions\\.*?\.sqf", re.I),
    "external ARI_AO missing script": re.compile(r"Script ARI_AO\\.*? not found", re.I),
    "external particle expression": re.compile(r"Неопределенная переменная в выражении: speed[xyz]", re.I),
    "external fired debug spam": re.compile(r"\[DEBUG\] FIRED", re.I),
}

def collect_findings(source: str, patterns: dict[str, re.Pattern[str]], path: Path) -> dict[str, dict[str, object]]:
    findings: dict[str, dict[str, object]] = {}
    for name, pattern in patterns.items():
        samples: list[str] = []
        count = 0
        for match in pattern.finditer(source):
            count += 1
            if len(samples) < 20:
                line = source.count("\n", 0, match.start()) + 1
                samples.append(f"{path}:{line}")
        findings[name] = {"count": count, "samples": samples}
    return findings

mission_rpt_findings: dict[str, dict[str, object]] = {
    name: {"count": 0, "samples": []} for name in mission_rpt_patterns
}
external_rpt_findings: dict[str, dict[str, object]] = {
    name: {"count": 0, "samples": []} for name in external_rpt_patterns
}
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        errors.append(f"RPT not found: {path}")
        continue
    source = path.read_text(encoding="utf-8", errors="replace")
    for destination, patterns in ((mission_rpt_findings, mission_rpt_patterns), (external_rpt_findings, external_rpt_patterns)):
        fresh = collect_findings(source, patterns, path)
        for name, item in fresh.items():
            destination[name]["count"] = int(destination[name]["count"]) + int(item["count"])
            remaining = 20 - len(destination[name]["samples"])
            if remaining > 0:
                destination[name]["samples"].extend(item["samples"][:remaining])

mission_failed = any(int(item["count"]) > 0 for item in mission_rpt_findings.values())
external_performance_blocker = int(external_rpt_findings["external fired debug spam"]["count"]) >= 100
report = {
    "validator": "rc6-rpt-stabilization",
    "base_validator_skipped": args.skip_base,
    "base_validator_exit": base_exit,
    "validator_output": validator_output,
    "errors": errors,
    "mission_rpt_findings": mission_rpt_findings,
    "external_rpt_findings": external_rpt_findings,
    "mission_failed": mission_failed,
    "external_performance_blocker": external_performance_blocker,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors or mission_failed or external_performance_blocker else 0)
