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
args = parser.parse_args()

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
errors: list[str] = []
validator_output: dict[str, str] = {}
if base.returncode != 0:
    errors.append("base validate_rc6.py failed")
    validator_output["validate_rc6.py"] = base.stdout

for validator in (
    "validate_arma_wiki_contracts.py",
    "validate_side_contracts.py",
    "validate_orientation_contracts.py",
):
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / validator)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if result.returncode != 0:
        errors.append(f"{validator} failed")
        validator_output[validator] = result.stdout

contracts = {
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
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf": (
        'if (_requestUpper == "FP5") then {"friendlyFP5Stock"}',
        "_costPool",
        "_unlaunched",
    ),
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf": (
        "_canUseFP5",
        "_strategicAvailable",
        'isKindOf "VirtualMan_F"',
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        "_isLiveStrategicContact",
        "LONG_RANGE_SALVO_ABORT",
        'isKindOf "VirtualMan_F"',
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
    "dro2026/functions/directors/fn_logisticsDirector.sqf": (
        "_setActiveConvoyStatus",
        '"INTERDICTED"',
        '"DELIVERED"',
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
}
for relative, tokens in forbidden.items():
    source = read(relative)
    found = [token for token in tokens if token in source]
    if found:
        errors.append(f"{relative}: forbidden {', '.join(found)}")

rpt_patterns = {
    "faction/locality undefined": re.compile(
        r"Undefined variable in expression: _(?:thisFac|isPlayerFaction|"
        r"isEnemyFaction|spawnDirection|applyFlightVector)",
        re.I,
    ),
    "type mismatch": re.compile(
        r"Error Тип (?:Массив|Объект|Группа), ожидался",
        re.I,
    ),
    "legacy TOS support": re.compile(r"_artyVeh\s*=.*pook_TOS1A", re.I),
    "fire handler spam": re.compile(r"\[DEBUG\] FIRED", re.I),
    "watchdog freeze": re.compile(r"No alive in \d+ ms", re.I),
}
rpt_findings = {name: [] for name in rpt_patterns}
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        errors.append(f"RPT not found: {path}")
        continue
    source = path.read_text(encoding="utf-8", errors="replace")
    for name, pattern in rpt_patterns.items():
        for match in pattern.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            rpt_findings[name].append(f"{path}:{line}")

report = {
    "validator": "rc6-rpt-stabilization",
    "base_validator_exit": base.returncode,
    "validator_output": validator_output,
    "errors": errors,
    "rpt_findings": rpt_findings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors or any(rpt_findings.values()) else 0)
