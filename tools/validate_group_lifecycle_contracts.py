from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DRO = ROOT / "dro2026"

CREATE_GROUP_RE = re.compile(
    r"(?:private\s+)?(?P<variable>_[A-Za-z0-9_]+)\s*=\s*createGroup\b"
)


def line_at(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def require_tokens(
    errors: list[str],
    relative: str,
    required: tuple[str, ...],
    forbidden: tuple[str, ...] = (),
) -> None:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"{relative}: missing")
        return
    source = path.read_text(encoding="utf-8", errors="replace")
    for token in required:
        if token not in source:
            errors.append(f"{relative}: missing contract {token!r}")
    for token in forbidden:
        if token in source:
            errors.append(f"{relative}: forbidden contract {token!r}")


def check_create_group(path: Path, source: str, errors: list[str]) -> None:
    for match in CREATE_GROUP_RE.finditer(source):
        variable = match.group("variable")
        window = source[match.end() : match.end() + 1400]
        create_unit_at = window.find(f"{variable} createUnit")
        if create_unit_at < 0:
            continue
        null_positions = [
            position
            for pattern in (f"isNull {variable}", f"isNull ({variable})")
            if (position := window.find(pattern)) >= 0
        ]
        if not null_positions or min(null_positions) > create_unit_at:
            errors.append(
                f"{path.relative_to(ROOT).as_posix()}:{line_at(source, match.start())}: "
                f"{variable} createUnit is reachable before a grpNull guard"
            )


def main() -> int:
    errors: list[str] = []
    scanned = 0
    create_group_sites = 0

    for path in sorted(DRO.rglob("*.sqf")):
        source = path.read_text(encoding="utf-8", errors="replace")
        matches = list(CREATE_GROUP_RE.finditer(source))
        if matches:
            scanned += 1
            create_group_sites += len(matches)
            check_create_group(path, source, errors)

    require_tokens(
        errors,
        "dro2026/functions/core/fn_spawnGuard.sqf",
        (
            "if (isNull _group) exitWith {grpNull};",
            "({alive _x} count units _group) == 0",
            "deleteGroup _group",
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/core/fn_createFriendlyPositions.sqf",
        (
            "switch (playersSide)",
            'default {["O_Soldier_F", "O_Soldier_AR_F", "O_medic_F"]};',
            "if (!isNull _unit)",
            "deleteGroup _group",
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/core/fn_createFriendlyLogisticsSite.sqf",
        (
            "[playersSide] call DRO2026_fnc_getSideNumber",
            'getNumber (_cfg >> "side") == _sideNumber',
            "DRO2026_fnc_isSafeInfantryClass",
            "validateSiteRecord",
            "deleteGroup _group",
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/objectives/fn_objectiveISRRecon.sqf",
        (
            "if (isNull _group) exitWith",
            "deleteMarker _marker",
            "validateSiteRecord",
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/directors/fn_civilTrafficDirector.sqf",
        (
            "if (isNull _group)",
            "objectParent _driver == _vehicle",
            "_vehicle deleteVehicleCrew _driver",
            "deleteVehicleCrew _vehicle",
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/directors/fn_orderEncirclement.sqf",
        (
            'getOrDefault ["positionMean"',
            "alive _leader",
            '"DRO2026_reactionUntil"',
        ),
    )
    require_tokens(
        errors,
        "dro2026/functions/directors/fn_reactionDirector.sqf",
        (
            '"pausedUntil"',
            '"ROUTE_RESUMED"',
            "DRO2026_fnc_isLiveContactSubject",
            '"MATERIALIZATION_FAILED_OR_MISSION_ENDING"',
            "alive _leader",
        ),
    )

    report = {
        "validator": "group-lifecycle-contracts",
        "sqf_files_with_create_group": scanned,
        "create_group_sites": create_group_sites,
        "errors": sorted(set(errors)),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
