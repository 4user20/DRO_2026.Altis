from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE_EXTENSIONS = {".sqf", ".inc", ".hpp", ".ext", ".sqm"}
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def include_target(owner: Path, raw: str) -> Path | None:
    candidate = (owner.parent / Path(raw.replace("\\", "/"))).resolve()
    if candidate.is_file() and (candidate == ROOT or ROOT in candidate.parents):
        return candidate
    return None


def expand(path: Path, stack: tuple[Path, ...] = ()) -> tuple[str, list[str]]:
    path = path.resolve()
    if path in stack:
        cycle = " -> ".join(relative(item) for item in (*stack, path))
        return "", [f"include cycle: {cycle}"]

    source = read(path)
    errors: list[str] = []

    def replace(match: re.Match[str]) -> str:
        target = include_target(path, match.group(1))
        if target is None:
            errors.append(f"{relative(path)}: missing include {match.group(1)}")
            return ""
        nested, nested_errors = expand(target, (*stack, path))
        errors.extend(nested_errors)
        return f"\n// INCLUDED {relative(target)}\n{nested}\n"

    return INCLUDE_RE.sub(replace, source), errors


def clean(source: str) -> tuple[str, str]:
    output: list[str] = []
    index = 0
    state = "code"
    quote = ""

    while index < len(source):
        if state == "code":
            if source.startswith("//", index):
                state = "line"
                output.extend("  ")
                index += 2
            elif source.startswith("/*", index):
                state = "block"
                output.extend("  ")
                index += 2
            elif source[index] in {'"', "'"}:
                state = "string"
                quote = source[index]
                output.append(" ")
                index += 1
            else:
                output.append(source[index])
                index += 1
        elif state == "line":
            if source[index] == "\n":
                state = "code"
                output.append("\n")
            else:
                output.append(" ")
            index += 1
        elif state == "block":
            if source.startswith("*/", index):
                state = "code"
                output.extend("  ")
                index += 2
            else:
                output.append("\n" if source[index] == "\n" else " ")
                index += 1
        else:
            if source[index] == quote:
                if index + 1 < len(source) and source[index + 1] == quote:
                    output.extend("  ")
                    index += 2
                else:
                    state = "code"
                    quote = ""
                    output.append(" ")
                    index += 1
            else:
                output.append("\n" if source[index] == "\n" else " ")
                index += 1

    if state == "line":
        state = "code"
    return "".join(output), state


def delimiter_errors(label: str, source: str) -> list[str]:
    source, state = clean(source)
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1

    for char in source:
        if char == "\n":
            line += 1
        elif char in "([{" :
            stack.append((char, line))
        elif char in ")]}" :
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f"{label}:{line}: mismatched {char}")
                break
            stack.pop()

    if stack:
        errors.append(f"{label}: unclosed {stack[-1]}")
    if state != "code":
        errors.append(f"{label}: unclosed {state}")
    return errors


def contract(
    errors: list[str],
    relative_path: str,
    required: tuple[str, ...],
    forbidden: tuple[str, ...] = (),
) -> None:
    path = ROOT / relative_path
    if not path.is_file():
        errors.append(f"{relative_path}: missing file")
        return
    source = read(path)
    missing = [token for token in required if token not in source]
    blocked = [token for token in forbidden if token in source]
    if missing:
        errors.append(f"{relative_path}: missing {', '.join(missing)}")
    if blocked:
        errors.append(f"{relative_path}: forbidden {', '.join(blocked)}")


def run_optional_hemtt(require_hemtt: bool) -> tuple[dict[str, object], bool]:
    executable = shutil.which("hemtt")
    configured = (ROOT / ".hemtt" / "project.toml").is_file()
    result: dict[str, object] = {
        "available": executable is not None,
        "configured": configured,
        "exit_code": None,
        "output": "",
    }

    if executable is None or not configured:
        return result, require_hemtt

    process = subprocess.run(
        [executable, "check"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=180,
    )
    result["exit_code"] = process.returncode
    result["output"] = process.stdout[-12000:]
    return result, process.returncode != 0


parser = ArgumentParser(description="DRO 2026 RC6 static and semantic validator")
parser.add_argument("--rpt", action="append", default=[])
parser.add_argument("--require-hemtt", action="store_true")
args = parser.parse_args()

all_files = sorted(
    path
    for path in ROOT.rglob("*")
    if path.is_file()
    and path.suffix.lower() in SOURCE_EXTENSIONS
    and ".git" not in path.parts
    and "graphify-out" not in path.parts
)
entry_files = [path for path in all_files if path.suffix.lower() != ".inc"]

syntax_errors: list[str] = []
expanded: dict[Path, str] = {}
raw_cleaned = {path: clean(read(path))[0] for path in all_files}
for path in entry_files:
    source, include_errors = expand(path)
    syntax_errors.extend(include_errors)
    syntax_errors.extend(delimiter_errors(f"{relative(path)} [expanded]", source))
    expanded[path] = source

cfg = read(ROOT / "dro2026" / "CfgFunctions.hpp")
registered = set(
    re.findall(
        r"\bclass\s+(\w+)\s*\{(?:\s*(?:preInit|postInit)\s*=\s*1\s*;)?\s*\};",
        cfg,
    )
)
function_files = {
    path.stem[3:] for path in (ROOT / "dro2026" / "functions").rglob("fn_*.sqf")
}
calls = set().union(
    *(set(re.findall(r"DRO2026_fnc_(\w+)", source)) for source in raw_cleaned.values())
)
function_errors = {
    "unregistered_files": sorted(function_files - registered),
    "missing_files": sorted(registered - function_files),
    "unregistered_calls": sorted(calls - registered - {"log"}),
}

critical_patterns = {
    "Bo_Mk82 injection": re.compile(r"\bBo_Mk82\b", re.I),
    "Titan injection": re.compile(r"\bM_Titan_(?:AT|AP)\b", re.I),
    "unsupported orderBy": re.compile(r"\borderBy\b", re.I),
    "object checkVisibility": re.compile(
        r"\b_[A-Za-z0-9_]+\s+checkVisibility\s*\[",
        re.I,
    ),
    "chained HashMap get": re.compile(
        r"DRO2026_networkNodes\s+get\s+_[A-Za-z0-9_]+\s+getOrDefault",
        re.I,
    ),
}
critical = {name: [] for name in critical_patterns}
for path, source in raw_cleaned.items():
    if "dro2026" not in path.parts:
        continue
    for name, pattern in critical_patterns.items():
        for match in pattern.finditer(source):
            critical[name].append(
                f"{relative(path)}:{source.count(chr(10), 0, match.start()) + 1}"
            )

semantic: dict[str, list[str]] = {
    "contact model": [],
    "support authority": [],
    "state objectives": [],
    "node logistics": [],
    "EW and AA": [],
    "support ROE": [],
    "resource accounting": [],
    "Arma Wiki contracts": [],
}

contract(
    semantic["contact model"],
    "dro2026/functions/core/fn_createContactRecord.sqf",
    (
        "positionMean",
        "uncertaintyRadius",
        "sources",
        "velocityEstimate",
        "bdaState",
        "falseContactProbability",
    ),
)
if "class createContactRecord {};" not in cfg:
    semantic["contact model"].append("CfgFunctions: createContactRecord is not registered")
contract(
    semantic["contact model"],
    "dro2026/functions/directors/fn_sensorDirector.sqf",
    ("PROBABLY_DESTROYED", "CONFIRMED_DESTROYED", "BDA_UPDATED"),
)

contract(
    semantic["support authority"],
    "dro2026/functions/support/fn_serverRequestSupport.sqf",
    (
        "isPlayer _requester",
        'isKindOf "VirtualMan_F"',
        "remoteExecutedOwner",
        "owner _requester",
        "_catalogContains",
    ),
)
for name in (
    "fn_requestFPV.sqf",
    "fn_requestISR.sqf",
    "fn_requestLongRangeSupport.sqf",
    "fn_requestArtillery.sqf",
    "fn_requestAirSupport.sqf",
):
    contract(
        semantic["support authority"],
        f"dro2026/functions/support/{name}",
        ("if (!isServer)", "serverRequestSupport"),
    )

contract(
    semantic["state objectives"],
    "dro2026/functions/objectives/fn_selectObjective.sqf",
    ("selectObjectiveOpportunity", "OBJECTIVE_EXPOSED", "OBJECTIVE_MATERIALIZATION_FAILED"),
    ("selectRandom DRO2026_OPERATION_PACKAGES",),
)
contract(
    semantic["state objectives"],
    "dro2026/functions/core/fn_selectObjectiveOpportunity.sqf",
    ("activeOpportunities", "DRO2026_networkNodes", "DRO2026_selectedOpportunity"),
)
contract(
    semantic["state objectives"],
    "dro2026/functions/objectives/fn_objectiveISRRecon.sqf",
    ("ISR_RELAY", "Land_TTowerSmall_1_F", 'isKindOf "VirtualMan_F"'),
)

contract(
    semantic["node logistics"],
    "dro2026/functions/directors/fn_logisticsDirector.sqf",
    (
        "DELIVERY_STARTED",
        "DELIVERY_MATERIALIZED",
        "DELIVERY_COMPLETED",
        "DELIVERY_INTERDICTED",
        "_setActiveConvoyStatus",
        "changeNetworkNodeStock",
    ),
)
contract(
    semantic["node logistics"],
    "dro2026/functions/objectives/fn_objectiveConvoy.sqf",
    ("edgeId", "cargoType", "toNode", "DELIVERY_INTERDICTED"),
)

contract(
    semantic["EW and AA"],
    "dro2026/functions/core/fn_getJammingAtPosition.sqf",
    ("emissionState", "terrainIntersectASL", "jammingRadius"),
)
contract(
    semantic["EW and AA"],
    "dro2026/functions/directors/fn_airDefenceDirector.sqf",
    ("trackingChannels", "AA_MISSILE_LAUNCHED", "AA_EMISSION_CHANGED"),
)
contract(
    semantic["support ROE"],
    "dro2026/functions/core/fn_getAirWindow.sqf",
    ("PERMISSIVE", "CONTESTED", "CLOSED", "civiliansClose", "friendliesClose"),
)
contract(
    semantic["support ROE"],
    "dro2026/functions/support/fn_requestAirSupport.sqf",
    ("getAirWindow", "AA_ACTIVE", "TARGET_LOST", "CIVILIAN_RISK", "FRIENDLIES_CLOSE"),
)

contract(
    semantic["resource accounting"],
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    ("LONG_RANGE_LAUNCH_REFUND", "friendlyFP5Stock", "enemyLongRangeStock"),
)
contract(
    semantic["resource accounting"],
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
    ("LONG_RANGE_SALVO_ABORT", "_isLiveStrategicContact"),
)
contract(
    semantic["resource accounting"],
    "dro2026/functions/support/fn_launchISR.sqf",
    ("_refundReservation", "DRO2026_lastISRRequest = -999"),
)

wiki_process = subprocess.run(
    [sys.executable, str(ROOT / "tools" / "validate_arma_wiki_contracts.py")],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
if wiki_process.returncode != 0:
    semantic["Arma Wiki contracts"].append(wiki_process.stdout[-12000:])

rpt_patterns = {
    "undefined variable": re.compile(
        r"Undefined variable(?: in expression)?:?\s*([^\r\n]*)",
        re.I,
    ),
    "expression error": re.compile(
        r"(?:Error in expression|Generic error in expression)",
        re.I,
    ),
    "network regression": re.compile(
        r"(?:DRO2026_networkNodes|DRO2026_networkEdges|DRO2026_operationState|"
        r"DRO2026_currentIntent|DRO2026_eventLog|DRO2026_supplyLanes)",
        re.I,
    ),
    "watchdog freeze": re.compile(r"No alive in \d+ ms", re.I),
}
rpt = {name: [] for name in rpt_patterns}
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        rpt.setdefault("missing file", []).append(str(path))
        continue
    source = read(path)
    for name, pattern in rpt_patterns.items():
        rpt[name].extend(
            f"{path}:{source.count(chr(10), 0, match.start()) + 1}"
            for match in pattern.finditer(source)
        )

hemtt, hemtt_failed = run_optional_hemtt(args.require_hemtt)

report = {
    "version": "rc6-arma-wiki-audit",
    "expanded_entry_files": len(entry_files),
    "include_fragments": len(all_files) - len(entry_files),
    "registered_count": len(registered),
    "function_file_count": len(function_files),
    "delimiter_or_include_errors": syntax_errors,
    "functions": function_errors,
    "critical_findings": critical,
    "semantic_errors": semantic,
    "rpt_regressions": rpt,
    "arma_wiki_validator_output": wiki_process.stdout if wiki_process.returncode != 0 else "",
    "hemtt": hemtt,
}
print(json.dumps(report, ensure_ascii=False, indent=2))

failed = (
    bool(syntax_errors)
    or any(function_errors.values())
    or any(critical.values())
    or any(semantic.values())
    or any(rpt.values())
    or hemtt_failed
)
sys.exit(1 if failed else 0)
