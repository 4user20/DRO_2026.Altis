from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TEXT_EXTENSIONS = {".sqf", ".hpp", ".ext", ".sqm"}
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
        return f"\n// BEGIN INCLUDED {include_path.relative_to(ROOT)}\n{expanded}\n// END INCLUDED {include_path.relative_to(ROOT)}\n"

    return INCLUDE_RE.sub(replace, source), errors


def strip_comments_and_strings(source: str) -> tuple[str, str]:
    output: list[str] = []
    index = 0
    state = "code"
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
            elif source[index] == '"':
                state = "string"
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
            if source[index] == '"':
                if index + 1 < len(source) and source[index + 1] == '"':
                    output.extend("  ")
                    index += 2
                else:
                    state = "code"
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


files = sorted(
    path for path in ROOT.rglob("*")
    if path.is_file()
    and path.suffix.lower() in TEXT_EXTENSIONS
    and "graphify-out" not in path.parts
)

errors: list[str] = []
expanded_sources: dict[Path, str] = {}
for path in files:
    expanded, include_errors = expand_includes(path)
    errors.extend(include_errors)
    expanded_sources[path] = expanded
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
    "Pook class direct creation": re.compile(r'createVehicle\s*\[\s*"[^"]*pook', re.I),
    "old tokenList findIf bug": re.compile(r"_tokenList\s+findIf", re.I),
}
findings: dict[str, list[str]] = {name: [] for name in critical_patterns}
for path, source in expanded_sources.items():
    if "dro2026" not in path.parts and path.name not in {
        "defineFactionClasses.sqf",
        "generateEnemies.sqf",
        "initPlayerLocal.sqf",
        "addTaskExtras.sqf",
    }:
        continue
    clean, _ = strip_comments_and_strings(source)
    for name, pattern in critical_patterns.items():
        for match in pattern.finditer(clean):
            line = clean.count("\n", 0, match.start()) + 1
            findings[name].append(f"{path.relative_to(ROOT)}:{line}")

report = {
    "expanded_entry_files": len(files),
    "registered_count": len(registered),
    "function_file_count": len(function_files),
    "delimiter_or_include_errors": errors,
    "functions": function_errors,
    "critical_findings": findings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))

failed = bool(errors) or any(function_errors.values()) or any(findings.values())
sys.exit(1 if failed else 0)
