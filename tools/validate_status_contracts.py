from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED: dict[str, tuple[str, ...]] = {
    "dro2026/functions/core/fn_buildAAR.sqf": (
        'case "CANCELLED"',
        '"cancelledNodes"',
        '"deliveriesCancelled"',
        '"DRONE_RECOVERED"',
        '"DRONE_LOST"',
        '"droneRecoveries"',
        '"droneLosses"',
        '"objectiveMaterializationFailures"',
        '"objectiveSelectionExhausted"',
        '"schema", 2',
    ),
    "dro2026/functions/support/fn_showStatus.sqf": (
        "isRemoteExecuted",
        "remoteExecutedOwner",
        "owner _requester",
        'isKindOf "VirtualMan_F"',
        'side (group _requester) != playersSide',
        'remoteExecCall ["DRO2026_fnc_showStatus", owner _requester',
        '"CANCELLED", "отменён / выведен из контура"',
        '"deliveriesCancelled"',
        '"droneRecoveries"',
        '"droneLosses"',
        '"objectiveSelectionExhausted"',
    ),
    "dro2026/functions/core/fn_syncNetworkState.sqf": (
        'private _terminalSiteStatuses = ["DESTROYED", "DISABLED", "CANCELLED", "COMPLETED"]',
        'case "CANCELLED": {"DISABLED"}',
        'case "COMPLETED": {"COMPLETED"}',
        '"NETWORK_NODE_DISABLED"',
        '"NETWORK_NODE_DESTROYED"',
    ),
    "dro2026/functions/core/fn_evaluateOperationPhase.sqf": (
        "if (count _node == 0)",
        'case "CANCELLED"',
        '"destroyedCapabilities"',
        '"networkHealth"',
    ),
    "dro2026/functions/core/fn_selectObjectiveOpportunity.sqf": (
        'missionNamespace setVariable ["DRO2026_selectedOpportunity", createHashMap]',
        '"NO_OBJECTIVE_OPPORTUNITY"',
        '"deterministic active-node fallback"',
        '"deterministic vanilla materialization fallback"',
    ),
    "dro2026/functions/objectives/fn_selectObjective.sqf": (
        "_attemptedTypes",
        '"OBJECTIVE_MATERIALIZATION_FAILED"',
        '"OBJECTIVE_SELECTION_EXHAUSTED"',
    ),
}

FORBIDDEN: dict[str, tuple[str, ...]] = {
    "dro2026/functions/support/fn_showStatus.sqf": (
        'remoteExecCall ["DRO2026_fnc_showStatus", _requester',
    ),
    "dro2026/functions/objectives/fn_selectObjective.sqf": (
        '_selectedType = "CUT_REAR"',
    ),
    "dro2026/functions/core/fn_buildAAR.sqf": (
        'default {_active = _active + 1}',
    ),
}


def main() -> int:
    errors: list[str] = []
    for relative, tokens in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative}: missing")
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for token in tokens:
            if token not in source:
                errors.append(f"{relative}: missing contract {token!r}")

    for relative, tokens in FORBIDDEN.items():
        path = ROOT / relative
        if not path.is_file():
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for token in tokens:
            if token in source:
                errors.append(f"{relative}: forbidden contract {token!r}")

    if errors:
        print("Status/AAR contract validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Status/AAR contract validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
