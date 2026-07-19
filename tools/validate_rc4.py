from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TEXT_EXTENSIONS = {".sqf", ".inc", ".hpp", ".ext", ".sqm"}
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def resolve_include(owner: Path, raw_path: str) -> Path | None:
    normalized = Path(raw_path.replace("\\", "/"))
    candidates = [owner.parent / normalized, ROOT / normalized]
    for candidate in candidates:
        candidate = candidate.resolve()
        if candidate.is_file() and (candidate == ROOT or ROOT in candidate.parents):
            return candidate
    return None


def expand_includes(path: Path, stack: tuple[Path, ...] = ()) -> tuple[str, list[str]]:
    resolved = path.resolve()
    if resolved in stack:
        cycle = " -> ".join(str(item.relative_to(ROOT)) for item in (*stack, resolved))
        return "", [f"include cycle: {cycle}"]

    source = read_text(resolved)
    errors: list[str] = []

    def replace(match: re.Match[str]) -> str:
        include_path = resolve_include(resolved, match.group(1))
        if include_path is None:
            errors.append(f"{resolved.relative_to(ROOT)}: missing include {match.group(1)}")
            return ""
        expanded, nested_errors = expand_includes(include_path, (*stack, resolved))
        errors.extend(nested_errors)
        return (
            f"\n// BEGIN INCLUDED {include_path.relative_to(ROOT)}\n"
            f"{expanded}\n"
            f"// END INCLUDED {include_path.relative_to(ROOT)}\n"
        )

    return INCLUDE_RE.sub(replace, source), errors


def strip_comments_and_strings(source: str) -> tuple[str, str]:
    output: list[str] = []
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        if state == "code":
            if source.startswith("//", index):
                state = "line_comment"
                output.extend("  ")
                index += 2
            elif source.startswith("/*", index):
                state = "block_comment"
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
        elif state == "line_comment":
            if source[index] == "\n":
                state = "code"
                output.append("\n")
            else:
                output.append(" ")
            index += 1
        elif state == "block_comment":
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

    if state == "line_comment":
        state = "code"
    return "".join(output), state


def delimiter_errors(label: str, source: str) -> list[str]:
    clean, state = strip_comments_and_strings(source)
    errors: list[str] = []
    stack: list[tuple[str, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    line = 1
    for char in clean:
        if char == "\n":
            line += 1
        elif char in "([{":
            stack.append((char, line))
        elif char in ")]}":
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f"{label}:{line}: mismatched {char}; stack={stack[-3:]}")
                break
            stack.pop()
    else:
        if stack:
            errors.append(f"{label}: unclosed delimiter {stack[-1]}")
        if state != "code":
            errors.append(f"{label}: unclosed {state}")
    return errors


def locations(path: Path, source: str, pattern: re.Pattern[str]) -> list[str]:
    result: list[str] = []
    for match in pattern.finditer(source):
        line = source.count("\n", 0, match.start()) + 1
        result.append(f"{path.relative_to(ROOT)}:{line}")
    return result


def parse_args() -> object:
    parser = ArgumentParser(description="Static and semantic validation for DRO 2026")
    parser.add_argument(
        "--rpt",
        action="append",
        default=[],
        help="Optional Arma 3 RPT file to scan. May be supplied multiple times.",
    )
    return parser.parse_args()


args = parse_args()
files = sorted(
    path
    for path in ROOT.rglob("*")
    if path.is_file()
    and path.suffix.lower() in TEXT_EXTENSIONS
    and "graphify-out" not in path.parts
)

errors: list[str] = []
expanded_sources: dict[Path, str] = {}
clean_sources: dict[Path, str] = {}
for path in files:
    expanded, include_errors = expand_includes(path)
    errors.extend(include_errors)
    expanded_sources[path] = expanded
    clean_sources[path] = strip_comments_and_strings(expanded)[0]
    errors.extend(delimiter_errors(f"{path.relative_to(ROOT)} [expanded]", expanded))

cfg = read_text(ROOT / "dro2026/CfgFunctions.hpp")
registered = set(
    re.findall(
        r"\bclass\s+(\w+)\s*\{(?:\s*(?:preInit|postInit)\s*=\s*1\s*;)?\s*\};",
        cfg,
    )
)
function_files = {
    path.stem[3:]
    for path in (ROOT / "dro2026/functions").rglob("fn_*.sqf")
}
calls: set[str] = set()
for source in expanded_sources.values():
    calls.update(re.findall(r"DRO2026_fnc_(\w+)", source))

function_errors = {
    "unregistered_files": sorted(function_files - registered),
    "missing_files": sorted(registered - function_files),
    "unregistered_calls": sorted(calls - registered - {"log"}),
}

critical_patterns = {
    "Bo_Mk82 in DRO2026 code": re.compile(r"\bBo_Mk82\b", re.I),
    "Titan injection in DRO2026 code": re.compile(r"\bM_Titan_(?:AT|AP)\b", re.I),
    "Pook class direct creation": re.compile(r'createVehicle\s*\[\s*["\'][^"\']*pook', re.I),
    "old tokenList findIf bug": re.compile(r"_tokenList\s+findIf", re.I),
    "object-form checkVisibility": re.compile(r"\b_[A-Za-z0-9_]+\s+checkVisibility\s*\[", re.I),
    "single-argument fireAtTarget": re.compile(r"fireAtTarget\s*\[\s*[^,\]\n]+\s*\]", re.I),
}
findings: dict[str, list[str]] = {name: [] for name in critical_patterns}
for path, clean in clean_sources.items():
    if "dro2026" not in path.parts and path.name not in {
        "defineFactionClasses.sqf",
        "generateEnemies.sqf",
        "initPlayerLocal.sqf",
        "addTaskExtras.sqf",
    }:
        continue
    for name, pattern in critical_patterns.items():
        findings[name].extend(locations(path, clean, pattern))

semantic_errors: dict[str, list[str]] = {
    "unscoped unarmed infantry aliases": [],
    "broad Pook denylist": [],
    "support authority contract": [],
    "client delivery contract": [],
    "respawn disabled sentinel": [],
}
semantic_warnings: dict[str, list[str]] = {
    "unused constants": [],
    "server-only global player usage": [],
    "large orchestrators": [],
}

unarmed_alias_pattern = re.compile(
    r"(?<!_)(?:pInfClassesUnarmedForWeights|pInfClassUnarmedWeights|"
    r"eInfClassesUnarmedForWeights|eInfClassUnarmedWeights)\b"
)
for path, clean in clean_sources.items():
    semantic_errors["unscoped unarmed infantry aliases"].extend(
        locations(path, clean, unarmed_alias_pattern)
    )

broad_pook_pattern = re.compile(
    r"[\"']pook_[\"']\s*[,\]}]|find\s+[\"']pook_[\"']\s*\)?\s*==\s*0",
    re.I,
)
for path, source in expanded_sources.items():
    semantic_errors["broad Pook denylist"].extend(
        locations(path, source, broad_pook_pattern)
    )

support_contracts = {
    "dro2026/functions/support/fn_requestFPV.sqf": ("if (!isServer)", "serverRequestSupport"),
    "dro2026/functions/support/fn_requestISR.sqf": ("if (!isServer)", "serverRequestSupport"),
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf": ("if (!isServer)", "serverRequestSupport"),
    "dro2026/functions/support/fn_requestArtillery.sqf": ("if (!isServer)", "serverRequestSupport"),
    "dro2026/functions/support/fn_requestAirSupport.sqf": ("if (!isServer)", "serverRequestSupport"),
}
for raw_path, required_tokens in support_contracts.items():
    path = ROOT / raw_path
    source = read_text(path) if path.is_file() else ""
    missing = [token for token in required_tokens if token not in source]
    if missing:
        semantic_errors["support authority contract"].append(
            f"{raw_path}: missing {', '.join(missing)}"
        )

client_delivery_contracts = {
    "dro2026/functions/core/fn_hqVoice.sqf": "remoteExecCall",
    "dro2026/functions/support/fn_trackIncomingDrone.sqf": "remoteExec",
    "dro2026/functions/support/fn_offerFPVControl.sqf": "hasInterface",
}
for raw_path, token in client_delivery_contracts.items():
    path = ROOT / raw_path
    source = read_text(path) if path.is_file() else ""
    if token not in source:
        semantic_errors["client delivery contract"].append(f"{raw_path}: missing {token}")

start_source = read_text(ROOT / "start.sqf")
init_server_source = read_text(ROOT / "initServer.sqf")
legacy_nil_respawn = bool(re.search(r"case\s+3\s*:\s*\{\s*nil\s*\}", start_source))
sentinel_ready = (
    "DRO2026_respawnDisabled" in init_server_source
    and "respawnTime = -1" in init_server_source
)
if legacy_nil_respawn and not sentinel_ready:
    semantic_errors["respawn disabled sentinel"].append(
        "start.sqf still returns nil for mode 3 without initServer sentinel normalization"
    )

preinit_path = ROOT / "dro2026/functions/core/fn_preInit.sqf"
preinit_source = read_text(preinit_path)
constant_names = set(
    re.findall(r"^\s*(DRO2026_[A-Z0-9_]+)\s*=", preinit_source, re.MULTILINE)
)
all_clean = "\n".join(clean_sources.values())
for constant in sorted(constant_names):
    if len(re.findall(rf"\b{re.escape(constant)}\b", all_clean)) <= 1:
        semantic_warnings["unused constants"].append(constant)

for path, clean in clean_sources.items():
    head = clean[:500]
    if re.search(r"if\s*\(\s*!isServer\s*\)\s*exitWith", head) and re.search(r"\bplayer\b", clean):
        semantic_warnings["server-only global player usage"].append(str(path.relative_to(ROOT)))

for path in files:
    if path.suffix.lower() == ".sqf":
        line_count = read_text(path).count("\n") + 1
        if line_count > 1000:
            semantic_warnings["large orchestrators"].append(
                f"{path.relative_to(ROOT)}:{line_count} lines"
            )

rpt_patterns = {
    "undefined variable": re.compile(r"Undefined variable(?: in expression)?:?\s*([^\r\n]*)", re.I),
    "error in expression": re.compile(r"Error in expression", re.I),
    "generic expression error": re.compile(r"Generic error in expression", re.I),
    "known faction regression": re.compile(
        r"(?:_thisFac|pInfClassesUnarmedForWeights|pInfClassUnarmedWeights|"
        r"eInfClassesUnarmedForWeights|eInfClassUnarmedWeights|pook_SAMSite_class)",
        re.I,
    ),
}
rpt_regressions: dict[str, list[str]] = {name: [] for name in rpt_patterns}
for raw_rpt in args.rpt:
    rpt_path = Path(raw_rpt).expanduser().resolve()
    if not rpt_path.is_file():
        rpt_regressions["missing RPT file"] = [str(rpt_path)]
        continue
    rpt_source = read_text(rpt_path)
    for name, pattern in rpt_patterns.items():
        for match in pattern.finditer(rpt_source):
            line = rpt_source.count("\n", 0, match.start()) + 1
            rpt_regressions[name].append(f"{rpt_path}:{line}")

report = {
    "expanded_entry_files": len(files),
    "registered_count": len(registered),
    "function_file_count": len(function_files),
    "delimiter_or_include_errors": errors,
    "functions": function_errors,
    "critical_findings": findings,
    "semantic_errors": semantic_errors,
    "semantic_warnings": semantic_warnings,
    "rpt_regressions": rpt_regressions,
}
print(json.dumps(report, ensure_ascii=False, indent=2))

failed = (
    bool(errors)
    or any(function_errors.values())
    or any(findings.values())
    or any(semantic_errors.values())
    or any(rpt_regressions.values())
)
sys.exit(1 if failed else 0)
