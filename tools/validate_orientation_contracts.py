from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"

VECTOR_OBJECT = re.compile(
    r"\b(_[A-Za-z][A-Za-z0-9_]*)\s+setVectorDirAndUp\b"
)
FIXED_UP = re.compile(
    r"setVectorDirAndUp\s*\[\s*_[A-Za-z0-9_]+\s*,\s*"
    r"\[\s*0\s*,\s*0\s*,\s*1\s*\]\s*\]"
)

REQUIRED = {
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        "_applyFlightVector",
        "vectorCrossProduct",
        "setVectorDirAndUp",
        "setPosATL _spawnPosition",
    ),
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf": (
        "_applyFlightVector",
        "vectorCrossProduct",
        "setVectorDirAndUp",
        "setPosASL _spawnASL",
    ),
}


def main() -> int:
    errors: list[str] = []

    for relative, required in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative}: missing")
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for token in required:
            if token not in source:
                errors.append(f"{relative}: missing {token!r}")
        for match in FIXED_UP.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            errors.append(f"{relative}:{line}: fixed world-up used for pitched flight")

        vector_objects = {match.group(1) for match in VECTOR_OBJECT.finditer(source)}
        for variable in sorted(vector_objects):
            set_dir = re.compile(rf"\b{re.escape(variable)}\s+setDir\b")
            for match in set_dir.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                errors.append(
                    f"{relative}:{line}: {variable} mixes setDir with setVectorDirAndUp"
                )

    for path in DRO.rglob("*.sqf"):
        source = path.read_text(encoding="utf-8", errors="replace")
        for match in FIXED_UP.finditer(source):
            relative = path.relative_to(ROOT).as_posix()
            line = source.count("\n", 0, match.start()) + 1
            errors.append(f"{relative}:{line}: fixed world-up used for pitched flight")

    if errors:
        print("Orientation contract validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Orientation contract validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
