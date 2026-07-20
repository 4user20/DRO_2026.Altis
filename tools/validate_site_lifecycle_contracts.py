from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
OBJECTIVES = ROOT / "dro2026" / "functions" / "objectives"

CANONICAL_OBJECTIVES = (
    "fn_objectiveDroneSite.sqf",
    "fn_objectiveEWHunt.sqf",
    "fn_objectiveUAVTeam.sqf",
    "fn_objectiveLogisticsHub.sqf",
    "fn_objectiveArtilleryHunt.sqf",
    "fn_objectiveCutRear.sqf",
    "fn_objectiveLogisticsRun.sqf",
    "fn_objectiveISRRecon.sqf",
    "fn_objectiveConvoy.sqf",
)

RAW_SITE_PUSH = re.compile(
    r"DRO2026_sites\s+pushBack\s+(?:\(?\s*)?createHashMapFromArray\b",
    re.IGNORECASE,
)


def require(
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


def main() -> int:
    errors: list[str] = []
    raw_pushes: list[str] = []

    if not OBJECTIVES.is_dir():
        errors.append("dro2026/functions/objectives: missing")
    else:
        for path in sorted(OBJECTIVES.glob("*.sqf")):
            source = path.read_text(encoding="utf-8", errors="replace")
            for match in RAW_SITE_PUSH.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                raw_pushes.append(f"{path.relative_to(ROOT).as_posix()}:{line}")

    if raw_pushes:
        errors.extend(f"{item}: raw site map bypasses createSiteRecord" for item in raw_pushes)

    for filename in CANONICAL_OBJECTIVES:
        relative = f"dro2026/functions/objectives/{filename}"
        required = (
            "DRO2026_fnc_createSiteRecord",
            "DRO2026_fnc_validateSiteRecord",
            "DRO2026_sites pushBack",
        )
        if filename != "fn_objectiveConvoy.sqf":
            required += ('"critical"',)
        require(errors, relative, required)

    require(
        errors,
        "dro2026/functions/objectives/fn_objectiveConvoy.sqf",
        ('"deliveryId"', "_siteRecord"),
    )
    require(
        errors,
        "dro2026/functions/core/fn_syncNetworkState.sqf",
        (
            "_terminalSiteStatuses",
            '"COMPLETED"',
            '"CANCELLED"',
            "_nodeHasActive",
            "_nodeHasDegraded",
            "_nodeHasDisabled",
            '"NETWORK_NODE_DISABLED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_completeObjective.sqf",
        (
            "_siteId",
            "_deliveryId",
            "_matchesIdentity",
            "_hasExactSelector",
            "_matchedSites",
            '"terminalReason"',
            '"OBJECTIVE_COMPLETED"',
        ),
    )
    require(
        errors,
        "dro2026/functions/core/fn_resolveContactSubject.sqf",
        ('"DESTROYED","DISABLED","CANCELLED","COMPLETED"', "objectFromNetId"),
    )
    require(
        errors,
        "dro2026/functions/directors/fn_logisticsDirector.sqf",
        (
            "_setSiteState",
            '"COMPLETE"',
            '"DESTROYED"',
            '"DISABLED"',
            "DRO2026_fnc_transferLogisticsCargo",
        ),
    )

    report = {
        "validator": "site-lifecycle-contracts",
        "objective_files_scanned": len(list(OBJECTIVES.glob("*.sqf"))) if OBJECTIVES.is_dir() else 0,
        "canonical_objectives": list(CANONICAL_OBJECTIVES),
        "raw_site_pushes": raw_pushes,
        "errors": sorted(set(errors)),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
