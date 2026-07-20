from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED: dict[str, tuple[str, ...]] = {
    "dro2026/CfgFunctions.hpp": (
        "class isSiteOperational {};",
    ),
    "dro2026/functions/core/fn_isSiteOperational.sqf": (
        "DRO2026_sites findIf",
        '"DESTROYED", "DISABLED", "CANCELLED", "COMPLETED"',
        'pushBack "RELOCATING"',
        'getOrDefault ["operator", objNull]',
    ),
    "dro2026/functions/support/fn_requestFPV.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "DRO2026_fnc_isLiveContactSubject",
        "_siteId",
        "_unlaunched",
        "DRO2026_fnc_launchFPVStrike",
        "запрос на ручной FPV принят",
    ),
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "DRO2026_fnc_isLiveContactSubject",
        '"DRONE_LAUNCH_RESERVED"',
        "_siteId",
        "DRO2026_fnc_launchFPVStrike",
    ),
    "dro2026/functions/support/fn_launchFPVStrike.sqf": (
        '[_siteId] call DRO2026_fnc_isSiteOperational',
        "DRO2026_fnc_isLiveContactSubject",
        'setVariable ["DRO2026_siteId"',
        '"DRONE_LAUNCHED"',
        '"role", "FPV"',
        '"siteId", _siteId',
        '"reservationNodeId", _reservationNodeId',
    ),
    "dro2026/functions/support/fn_requestISR.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "_siteId",
        "DRO2026_fnc_launchISR",
        "materialization",
    ),
    "dro2026/functions/support/fn_launchISR.sqf": (
        '[_siteId] call DRO2026_fnc_isSiteOperational',
        'setVariable ["DRO2026_siteId"',
        '"DRONE_RECOVERED"',
        '"DRONE_LOST"',
        '"siteId", _siteId',
    ),
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "DRO2026_fnc_isLiveContactSubject",
        '"DRONE_LAUNCH_RESERVED"',
        "_siteId",
        "_unlaunched",
        "DRO2026_fnc_launchLongRangeStrike",
        "Фактический запуск подтверждается после materialization",
    ),
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "DRO2026_fnc_isLiveContactSubject",
        '"DRONE_LAUNCH_RESERVED"',
        "_siteId",
        "DRO2026_fnc_launchLongRangeStrike",
    ),
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf": (
        '[_siteId] call DRO2026_fnc_isSiteOperational',
        "_contactOperational",
        'setVariable ["DRO2026_siteId"',
        '"DRONE_LAUNCHED"',
        '"role", "LONG_RANGE"',
        '"projectile", _isProjectile',
        '"siteId", _siteId',
        '"reservationNodeId", _reservationNodeId',
    ),
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf": (
        "DRO2026_fnc_isSiteOperational",
        "DRO2026_fnc_isLiveContactSubject",
        '"state", "RESERVED"',
        "_siteId",
        "DRO2026_fnc_launchFPVStrike",
        "DRO2026_fnc_launchLongRangeStrike",
    ),
}

RESERVATION_ONLY_FILES = (
    "dro2026/functions/support/fn_requestFPV.sqf",
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf",
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf",
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
    "dro2026/functions/directors/fn_friendlyStrikeDirector.sqf",
)

LAUNCHERS = (
    "dro2026/functions/support/fn_launchFPVStrike.sqf",
    "dro2026/functions/support/fn_launchLongRangeStrike.sqf",
)

RESERVATION_BEFORE_LAUNCH: dict[str, str] = {
    "dro2026/functions/support/fn_requestFPV.sqf": "spawn DRO2026_fnc_launchFPVStrike",
    "dro2026/functions/directors/fn_enemyFPVDirector.sqf": "spawn DRO2026_fnc_launchFPVStrike",
    "dro2026/functions/support/fn_requestLongRangeSupport.sqf": "spawn DRO2026_fnc_launchLongRangeStrike",
    "dro2026/functions/directors/fn_longRangeDroneDirector.sqf": "spawn DRO2026_fnc_launchLongRangeStrike",
}


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8", errors="replace")


def main() -> int:
    errors: list[str] = []

    for relative, tokens in REQUIRED.items():
        path = ROOT / relative
        if not path.is_file():
            errors.append(f"{relative}: missing")
            continue
        source = read(relative)
        for token in tokens:
            if token not in source:
                errors.append(f"{relative}: missing contract {token!r}")

    for relative in RESERVATION_ONLY_FILES:
        source = read(relative)
        if '"DRONE_LAUNCHED"' in source:
            errors.append(f"{relative}: emits DRONE_LAUNCHED before materialization")

    for relative, launch_token in RESERVATION_BEFORE_LAUNCH.items():
        source = read(relative)
        reservation_at = source.find('["DRONE_LAUNCH_RESERVED"')
        launch_at = source.find(launch_token)
        if reservation_at < 0 or launch_at < 0 or reservation_at > launch_at:
            errors.append(f"{relative}: reservation event must precede launcher spawn")

    friendly = read("dro2026/functions/directors/fn_friendlyStrikeDirector.sqf")
    reservation_positions = [
        match.start()
        for match in re.finditer(r'"state"\s*,\s*"RESERVED"', friendly)
    ]
    launch_positions = sorted(
        position
        for token in (
            "spawn DRO2026_fnc_launchFPVStrike",
            "spawn DRO2026_fnc_launchLongRangeStrike",
        )
        if (position := friendly.find(token)) >= 0
    )
    if len(reservation_positions) != len(launch_positions) or any(
        reserved_at > launch_at
        for reserved_at, launch_at in zip(reservation_positions, launch_positions)
    ):
        errors.append(
            "fn_friendlyStrikeDirector.sqf: RESERVED event must precede each launcher spawn"
        )

    for relative in LAUNCHERS:
        source = read(relative)
        if source.count('"DRONE_LAUNCHED"') != 1:
            errors.append(f"{relative}: must emit DRONE_LAUNCHED exactly once")
        event_at = source.find('["DRONE_LAUNCHED"')
        create_at = source.find("createVehicle [")
        null_guard_at = source.find("if (isNull _drone) exitWith")
        site_tag_at = source.find('setVariable ["DRO2026_siteId"')
        active_at = source.find("DRO2026_activeDrones pushBack")
        materialization_points = (create_at, null_guard_at, site_tag_at, active_at)
        if event_at < 0 or any(
            point < 0 or event_at < point for point in materialization_points
        ):
            errors.append(
                f"{relative}: launch event precedes confirmed physical materialization"
            )
        if relative.endswith("fn_launchFPVStrike.sqf"):
            crew_at = source.find("createVehicleCrew")
            if crew_at < 0 or event_at < crew_at:
                errors.append(f"{relative}: FPV launch event precedes compatible crew")

    track = read("dro2026/functions/support/fn_trackIncomingDrone.sqf")
    if '"DRONE_LAUNCHED"' in track:
        errors.append("fn_trackIncomingDrone.sqf: duplicates launch event")

    for relative in (
        "dro2026/functions/support/fn_requestFPV.sqf",
        "dro2026/functions/directors/fn_enemyFPVDirector.sqf",
    ):
        source = read(relative)
        calls = re.findall(
            r"\[[^;]+\]\s+spawn\s+DRO2026_fnc_launchFPVStrike",
            source,
            re.DOTALL,
        )
        if not calls or not all("_siteId" in call for call in calls):
            errors.append(f"{relative}: FPV call does not pass stable siteId")

    for relative in (
        "dro2026/functions/support/fn_requestLongRangeSupport.sqf",
        "dro2026/functions/directors/fn_longRangeDroneDirector.sqf",
    ):
        source = read(relative)
        calls = re.findall(
            r"\[[^;]+\]\s+spawn\s+DRO2026_fnc_launchLongRangeStrike",
            source,
            re.DOTALL,
        )
        if not calls or not all("_siteId" in call for call in calls):
            errors.append(f"{relative}: long-range call does not pass stable siteId")

    if errors:
        print("Launch materialization contract validation failed:")
        for error in sorted(set(errors)):
            print(f" - {error}")
        return 1

    print("Launch materialization contract validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())