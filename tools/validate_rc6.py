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


def resolve_include(owner: Path, raw: str) -> Path | None:
    candidate = (owner.parent / Path(raw.replace("\\", "/"))).resolve()
    if candidate.is_file() and (candidate == ROOT or ROOT in candidate.parents):
        return candidate
    return None


def expand(path: Path, stack: tuple[Path, ...] = ()) -> tuple[str, list[str]]:
    path = path.resolve()
    if path in stack:
        chain = " -> ".join(relative(item) for item in (*stack, path))
        return "", [f"include cycle: {chain}"]

    source = read(path)
    errors: list[str] = []

    def replace(match: re.Match[str]) -> str:
        target = resolve_include(path, match.group(1))
        if target is None:
            errors.append(f"{relative(path)}: missing include {match.group(1)}")
            return ""
        nested, nested_errors = expand(target, (*stack, path))
        errors.extend(nested_errors)
        return f"\n// INCLUDED {relative(target)}\n{nested}\n"

    return INCLUDE_RE.sub(replace, source), errors


def strip_comments_and_strings(source: str) -> tuple[str, str]:
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
    cleaned, state = strip_comments_and_strings(source)
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1

    for char in cleaned:
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


def locate(path: Path, source: str, pattern: re.Pattern[str]) -> list[str]:
    return [
        f"{relative(path)}:{source.count(chr(10), 0, match.start()) + 1}"
        for match in pattern.finditer(source)
    ]


def require_tokens(
    bucket: list[str],
    relative_path: str,
    required: tuple[str, ...],
    forbidden: tuple[str, ...] = (),
) -> None:
    path = ROOT / relative_path
    if not path.is_file():
        bucket.append(f"{relative_path}: missing file")
        return

    source = read(path)
    missing = [token for token in required if token not in source]
    blocked = [token for token in forbidden if token in source]
    if missing:
        bucket.append(f"{relative_path}: missing {', '.join(missing)}")
    if blocked:
        bucket.append(f"{relative_path}: forbidden {', '.join(blocked)}")


def check_fly_materialization(bucket: list[str], relative_path: str) -> None:
    source = read(ROOT / relative_path)
    fly_positions = [match.start() for match in re.finditer(r'createVehicle\s*\[[^\n;]*"FLY"', source)]
    for position in fly_positions:
        window = source[position : position + 900]
        crew_at = min(
            [candidate for candidate in (window.find("createVehicleCrew"), window.find("BIS_fnc_spawnVehicle")) if candidate >= 0],
            default=-1,
        )
        set_pos_at = min(
            [candidate for candidate in (window.find("setPosATL"), window.find("setPosASL")) if candidate >= 0],
            default=-1,
        )
        if crew_at >= 0 and (set_pos_at < 0 or set_pos_at > crew_at):
            line = source.count("\n", 0, position) + 1
            bucket.append(
                f"{relative_path}:{line}: empty FLY airframe is crewed before explicit setPosATL/setPosASL"
            )


def run_hemtt_if_configured() -> dict[str, object]:
    executable = shutil.which("hemtt")
    project = ROOT / ".hemtt" / "project.toml"
    result: dict[str, object] = {
        "available": executable is not None,
        "configured": project.is_file(),
        "exit_code": None,
        "output": "",
    }
    if executable is None or not project.is_file():
        return result

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
    return result


parser = ArgumentParser(description="DRO 2026 static, semantic, and RPT validator")
parser.add_argument("--rpt", action="append", default=[])
parser.add_argument(
    "--require-hemtt",
    action="store_true",
    help="fail unless a configured HEMTT project can be checked successfully",
)
args = parser.parse_args()

all_files = sorted(
    path
    for path in ROOT.rglob("*")
    if path.is_file()
    and path.suffix.lower() in SOURCE_EXTENSIONS
    and "graphify-out" not in path.parts
    and ".git" not in path.parts
)
entry_files = [path for path in all_files if path.suffix.lower() != ".inc"]

expanded: dict[Path, str] = {}
stripped: dict[Path, str] = {}
raw_stripped = {path: strip_comments_and_strings(read(path))[0] for path in all_files}
syntax_errors: list[str] = []

for path in entry_files:
    source, include_errors = expand(path)
    syntax_errors.extend(include_errors)
    syntax_errors.extend(delimiter_errors(f"{relative(path)} [expanded]", source))
    expanded[path] = source
    stripped[path] = strip_comments_and_strings(source)[0]

cfg_path = ROOT / "dro2026" / "CfgFunctions.hpp"
cfg = read(cfg_path)
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
    *(set(re.findall(r"DRO2026_fnc_(\w+)", source)) for source in raw_stripped.values())
)
function_errors = {
    "unregistered_files": sorted(function_files - registered),
    "missing_files": sorted(registered - function_files),
    "unregistered_calls": sorted(calls - registered - {"log"}),
}

critical_patterns = {
    "Bo_Mk82 injection": re.compile(r"\bBo_Mk82\b", re.I),
    "Titan injection": re.compile(r"\bM_Titan_(?:AT|AP)\b", re.I),
    "Pook direct create": re.compile(
        r'createVehicle\s*\[\s*["\'][^"\']*pook',
        re.I,
    ),
    "object checkVisibility": re.compile(
        r"\b_[A-Za-z0-9_]+\s+checkVisibility\s*\[",
        re.I,
    ),
    "unsupported orderBy": re.compile(r"\borderBy\b", re.I),
    "chained HashMap get": re.compile(
        r"DRO2026_networkNodes\s+get\s+_[A-Za-z0-9_]+\s+getOrDefault",
        re.I,
    ),
}
critical = {name: [] for name in critical_patterns}
for path, source in stripped.items():
    if "dro2026" in path.parts or path.name in {
        "defineFactionClasses.sqf",
        "initPlayerLocal.sqf",
    }:
        for name, pattern in critical_patterns.items():
            critical[name].extend(locate(path, source, pattern))

semantic_names = (
    "faction safety",
    "support authority",
    "respawn sentinel",
    "world state",
    "persistent history",
    "contact v2",
    "state objectives",
    "artillery causality",
    "node logistics",
    "EW and AA",
    "support ROE",
    "resource accounting",
    "side isolation",
    "air materialization",
    "flight vectors",
    "virtual clients",
    "exact class routing",
    "crew cleanup",
)
semantic = {name: [] for name in semantic_names}

alias = re.compile(
    r"(?<!_)(?:pInfClassesUnarmedForWeights|pInfClassUnarmedWeights|"
    r"eInfClassesUnarmedForWeights|eInfClassUnarmedWeights)\b"
)
broad_pook = re.compile(
    r'["\']pook_["\']\s*[,}\]]|find\s+["\']pook_["\']\s*\)?\s*==\s*0',
    re.I,
)
for path, source in raw_stripped.items():
    semantic["faction safety"].extend(locate(path, source, alias))
for path, source in expanded.items():
    semantic["faction safety"].extend(locate(path, source, broad_pook))

for name in (
    "fn_requestFPV.sqf",
    "fn_requestISR.sqf",
    "fn_requestLongRangeSupport.sqf",
    "fn_requestArtillery.sqf",
    "fn_requestAirSupport.sqf",
):
    require_tokens(
        semantic["support authority"],
        f"dro2026/functions/support/{name}",
        ("if (!isServer)", "serverRequestSupport"),
    )
require_tokens(
    semantic["support authority"],
    "dro2026/functions/support/fn_serverRequestSupport.sqf",
    (
        "isPlayer _requester",
        'isKindOf "VirtualMan_F"',
        "remoteExecutedOwner",
        "isDedicated",
        "_remoteOwner <= 2",
        "owner _requester",
    ),
)

start = read(ROOT / "start.sqf")
server_init = read(ROOT / "initServer.sqf")
if re.search(r"case\s+3\s*:\s*\{\s*nil\s*\}", start) and not (
    "DRO2026_respawnDisabled" in server_init and "respawnTime = -1" in server_init
):
    semantic["respawn sentinel"].append(
        "start.sqf nil respawn mode lacks initServer sentinel"
    )

for relative_path, tokens in {
    "dro2026/functions/core/fn_initState.sqf": (
        "DRO2026_networkNodes",
        "DRO2026_networkEdges",
        "DRO2026_eventLog",
        "DRO2026_operationState",
    ),
    "dro2026/functions/core/fn_buildCapabilityNetwork.sqf": (
        "NODE_LOGISTICS_01",
        "NODE_ARTILLERY_01",
        "EDGE_LOGISTICS_ARTILLERY",
    ),
    "dro2026/functions/directors/fn_operationDirector.sqf": (
        "DRO2026_currentIntent",
        "INTENT_PROPOSED",
        "doctrine",
    ),
}.items():
    require_tokens(semantic["world state"], relative_path, tokens)

require_tokens(
    semantic["persistent history"],
    "dro2026/functions/directors/fn_performanceGovernor.sqf",
    ("syncNetworkState", "lastCompactedAt"),
    ("DRO2026_sites = DRO2026_sites select", "DRO2026_sites deleteAt"),
)
require_tokens(
    semantic["persistent history"],
    "dro2026/functions/core/fn_syncNetworkState.sqf",
    ("SITE_DESTROYED", "NETWORK_NODE_DESTROYED", "destroyedAt"),
)
require_tokens(
    semantic["contact v2"],
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
    semantic["contact v2"].append(
        "dro2026/CfgFunctions.hpp: createContactRecord is not registered"
    )
require_tokens(
    semantic["contact v2"],
    "dro2026/functions/directors/fn_sensorDirector.sqf",
    ("PROBABLY_DESTROYED", "CONFIRMED_DESTROYED", "BDA_UPDATED"),
)
require_tokens(
    semantic["contact v2"],
    "dro2026/functions/core/fn_syncContactMarker.sqf",
    ("ELLIPSE", "_uncertaintyRadius", "_bdaState"),
)

require_tokens(
    semantic["state objectives"],
    "dro2026/functions/objectives/fn_selectObjective.sqf",
    ("selectObjectiveOpportunity", "OBJECTIVE_EXPOSED"),
    ("selectRandom DRO2026_OPERATION_PACKAGES",),
)
require_tokens(
    semantic["state objectives"],
    "dro2026/functions/core/fn_selectObjectiveOpportunity.sqf",
    ("activeOpportunities", "DRO2026_networkNodes", "_phase"),
)
require_tokens(
    semantic["artillery causality"],
    "dro2026/functions/objectives/fn_artilleryLoop.sqf",
    ("ARTILLERY_FIRE", "observerContact", "COUNTERBATTERY"),
    ("getPosATL player", "getPos player"),
)
require_tokens(
    semantic["artillery causality"],
    "dro2026/functions/support/fn_requestArtillery.sqf",
    ("uncertaintyRadius", "_friendlyRisk", "_civilianRisk"),
)
require_tokens(
    semantic["node logistics"],
    "dro2026/functions/directors/fn_logisticsDirector.sqf",
    (
        "DELIVERY_STARTED",
        "DELIVERY_MATERIALIZED",
        "DELIVERY_COMPLETED",
        "DELIVERY_INTERDICTED",
        "virtualPosition",
        "changeNetworkNodeStock",
    ),
)
require_tokens(
    semantic["node logistics"],
    "dro2026/functions/objectives/fn_objectiveConvoy.sqf",
    ("edgeId", "cargoType", "toNode", "DELIVERY_INTERDICTED"),
    ('["enemySupply", -28]', '["enemyDroneStock", -7]'),
)
require_tokens(
    semantic["EW and AA"],
    "dro2026/functions/core/fn_getJammingAtPosition.sqf",
    ("emissionState", "terrainIntersectASL", "jammingRadius"),
)
require_tokens(
    semantic["EW and AA"],
    "dro2026/functions/directors/fn_airDefenceDirector.sqf",
    ("trackingChannels", "AA_MISSILE_LAUNCHED", "AA_EMISSION_CHANGED"),
)
require_tokens(
    semantic["EW and AA"],
    "dro2026/functions/support/fn_launchISR.sqf",
    ("EMISSION_DETECTED", "BURST", "_lastFalseContact", "getJammingAtPosition"),
)
require_tokens(
    semantic["support ROE"],
    "dro2026/functions/core/fn_getAirWindow.sqf",
    ("PERMISSIVE", "CONTESTED", "CLOSED", "civiliansClose", "friendliesClose"),
)
require_tokens(
    semantic["support ROE"],
    "dro2026/functions/support/fn_requestAirSupport.sqf",
    ("getAirWindow", "AA_ACTIVE", "TARGET_LOST", "CIVILIAN_RISK", "FRIENDLIES_CLOSE"),
)

require_tokens(
    semantic["resource accounting"],
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    (
        "_reservationNodeId",
        "LONG_RANGE_LAUNCH_REFUND",
        "friendlyFP5Stock",
        "enemyLongRangeStock",
    ),
)
require_tokens(
    semantic["resource accounting"],
    "dro2026/functions/support/fn_launchISR.sqf",
    ("_refundReservation", "DRO2026_lastISRRequest = -999"),
)
require_tokens(
    semantic["resource accounting"],
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
    ("_isLiveStrategicContact", "LONG_RANGE_SALVO_ABORT", "true, _nodeId"),
)
for relative_path in (
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf",
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf",
):
    source = read(ROOT / relative_path)
    if re.search(
        r'DRO2026_resources\s+set\s*\[\s*["\']friendlyFP5Stock["\']',
        source,
    ):
        semantic["resource accounting"].append(
            f"{relative_path}: direct FP5 deduction bypasses selected reservation pool"
        )

for relative_path in (
    "dro2026/functions/core/fn_refreshFactionAssets.sqf",
    "dro2026/functions/core/fn_publishSupportCatalog.sqf",
    "dro2026/functions/support/fn_launchISR.sqf",
):
    source = read(ROOT / relative_path)
    if re.search(r"\bin\s*\[\s*_[A-Za-z0-9_]*sideNumber\s*,\s*2\s*\]", source, re.I):
        semantic["side isolation"].append(
            f"{relative_path}: INDEPENDENT side leaks into another side pool"
        )
require_tokens(
    semantic["side isolation"],
    "dro2026/functions/core/fn_refreshFactionAssets.sqf",
    ("ENEMY_CAS_AIR", "ePlaneClasses", "eHeliClasses", "_cfgSide == _sideNumber"),
)
require_tokens(
    semantic["side isolation"],
    "dro2026/functions/directors/fn_enemyAirDirector.sqf",
    ("ENEMY_CAS_AIR", 'getNumber (_cfg >> "side") == _enemySideNumber'),
    ('getOrDefault ["AIR_EAST"',),
)

for relative_path in (
    "dro2026/functions/directors/fn_enemyAirDirector.sqf",
    "dro2026/functions/directors/fn_enemyISRDirector.sqf",
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    "dro2026/functions/support/fn_launchISR.sqf",
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    "dro2026/functions/support/fn_requestAirSupport.sqf",
):
    check_fly_materialization(semantic["air materialization"], relative_path)

for relative_path in (
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
):
    require_tokens(
        semantic["flight vectors"],
        relative_path,
        ("vectorCrossProduct", "_applyFlightVector", "setVectorDirAndUp"),
    )
    source = read(ROOT / relative_path)
    if re.search(
        r"setVectorDirAndUp\s*\[\s*_[A-Za-z0-9_]+\s*,\s*\[\s*0\s*,\s*0\s*,\s*1\s*\]\s*\]",
        source,
    ):
        semantic["flight vectors"].append(
            f"{relative_path}: pitched direction still uses fixed world-up vector"
        )

for relative_path in (
    "dro2026/functions/directors/fn_enemyAirDirector.sqf",
    "dro2026/functions/directors/fn_enemyISRDirector.sqf",
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf",
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
):
    source = read(ROOT / relative_path)
    if "allPlayers" in source and 'isKindOf "VirtualMan_F"' not in source:
        semantic["virtual clients"].append(
            f"{relative_path}: allPlayers is used without excluding VirtualMan_F"
        )

require_tokens(
    semantic["exact class routing"],
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    ("_requestedClass != \"\"", "side-correct registry"),
)
require_tokens(
    semantic["exact class routing"],
    "dro2026/functions/support/fn_launchISR.sqf",
    ("_selectionValid", "_class == \"\"", 'getNumber (_classCfg >> "side")'),
)
require_tokens(
    semantic["exact class routing"],
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    ("_selectionValid", "_exactClass in _pool"),
    ("nearestObjects",),
)

for relative_path in (
    "dro2026/functions/directors/fn_enemyAirDirector.sqf",
    "dro2026/functions/directors/fn_enemyISRDirector.sqf",
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    "dro2026/functions/support/fn_launchISR.sqf",
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
    "dro2026/functions/support/fn_requestAirSupport.sqf",
):
    require_tokens(
        semantic["crew cleanup"],
        relative_path,
        ("deleteVehicleCrew", "deleteGroup"),
    )

warnings = {
    "unused constants": [],
    "server player": [],
    "large files": [],
    "legacy enemy resources": [],
}
preinit = read(ROOT / "dro2026/functions/core/fn_preInit.sqf")
constants = set(re.findall(r"^\s*(DRO2026_[A-Z0-9_]+)\s*=", preinit, re.MULTILINE))
all_source = "\n".join(raw_stripped.values())
for name in sorted(constants):
    if len(re.findall(rf"\b{re.escape(name)}\b", all_source)) <= 1:
        warnings["unused constants"].append(name)

for path, source in raw_stripped.items():
    if path.suffix.lower() == ".sqf":
        guard = re.search(r"if\s*\(\s*!isServer\s*\)\s*exitWith\s*\{", source[:700])
        if guard is not None:
            close = source.find("};", guard.end())
            server_body = source[close + 2 :] if close >= 0 else source
            if re.search(r"\bplayer\b", server_body):
                warnings["server player"].append(relative(path))
        line_count = read(path).count("\n") + 1
        if line_count > 1000:
            warnings["large files"].append(f"{relative(path)}:{line_count}")
    if (
        "dro2026" in path.parts
        and re.search(r'DRO2026_resources\s+set\s*\[\s*["\']enemy', source)
        and path.name
        not in {
            "fn_logisticsDirector.sqf",
            "fn_enemyFPVDirector.sqf",
            "fn_longRangeDroneDirector.sqf",
            "fn_reactionDirector.sqf",
            "fn_launchLongRangeStrike.sqf",
        }
    ):
        warnings["legacy enemy resources"].append(relative(path))

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

hemtt = run_hemtt_if_configured()
hemtt_failed = bool(
    (args.require_hemtt and (not hemtt["available"] or not hemtt["configured"]))
    or (
        hemtt["configured"]
        and hemtt["available"]
        and hemtt["exit_code"] not in (None, 0)
    )
)

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
    "semantic_warnings": warnings,
    "rpt_regressions": rpt,
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
