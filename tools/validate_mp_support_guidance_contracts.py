from __future__ import annotations

from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


checks: list[tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str) -> None:
    checks.append((name, condition, detail))


contact = read("dro2026/functions/core/fn_createContactRecord.sqf")
resolver = read("dro2026/functions/core/fn_resolveContactSubject.sqf")
fpv_request = read("dro2026/functions/support/fn_requestFPV.sqf")
long_request = read("dro2026/functions/support/fn_requestLongRangeSupport.sqf")
server_request = read("dro2026/functions/support/fn_serverRequestSupport.sqf")
long_launch = read("dro2026/functions/support/fn_launchLongRangeStrike.sqf")
terrain = read("dro2026/functions/core/fn_calculateTerrainAwareAim.sqf")
fpv_controller = read("dro2026/functions/drone/fn_fpvAttackController.sqf")
sanitation = read("dro2026/functions/core/fn_sanitizeLegacyPools.sqf")
layered_aa = read("dro2026/functions/core/fn_spawnLayeredAA.sqf")
launcher_ammo = read("dro2026/functions/core/fn_resolveLauncherAmmo.sqf")

check(
    "position-only contact schema",
    all(token in contact for token in ['"subjectMode"', '"POSITION_ONLY"', '"positionOnly"', '"expiresAt"']),
    "map designations must be represented explicitly and expire",
)
check(
    "position-only has no fake resolvable subject",
    '_subjectNetId = "";' in contact and '_stableSubjectId = "";' in contact and '"designationId"' in contact,
    "designation ID must be separate from subjectId/netId",
)
check(
    "position-only resolver",
    all(token in resolver for token in ['"POSITION_ONLY_ACTIVE"', '"POSITION_EXPIRED"', '"positionASL"']),
    "valid map points must not become SUBJECT_UNRESOLVED",
)
check(
    "FPV MAP_POINT fallback",
    all(token in fpv_request for token in ['"PLAYER_DESIGNATION"', '["subjectMode","POSITION_ONLY"]', '"FPV_REQUEST_REJECTED"']),
    "FPV map clicks must create a transient positional target and structured rejection",
)
check(
    "FPV source fallback",
    'in ["FRIENDLY_FPV_SITE","FRIENDLY_DRONE_SITE"]' in fpv_request and 'DRO2026_FPV_SUPPORT_RADIUS' in fpv_request,
    "rear drone sites may execute map-point FPV when a forward team is absent",
)
check(
    "long-range position target",
    '"subjectMode","POSITION_ONLY"' in long_request and '"Long-range package reserved and launch sequence started"' in long_request,
    "long-range map points must be first-class and return a structured reservation result",
)
check(
    "long-range real handler result",
    'call DRO2026_fnc_requestLongRangeSupport' in server_request and '[true, "ACCEPTED", "Long-range strike request accepted for processing"' not in server_request,
    "server dispatcher must not fabricate ACCEPTED after handler failure",
)
check(
    "single-owner terminal handoff",
    all(f'disableAI "{feature}"' in long_launch for feature in ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM"])
    and 'for "_waypointIndex" from ((count waypoints _crewGroup) - 1) to 0 step -1 do' in long_launch
    and 'deleteWaypoint [_crewGroup, _waypointIndex]' in long_launch,
    "terminal vector guidance must clear a bounded waypoint snapshot in reverse order and disable conflicting AI features",
)
check(
    "terminal progress watchdog",
    all(token in long_launch for token in ['"LONG_RANGE_TERMINAL_RECOVERY"', '"NO_TERMINAL_PROGRESS"', '"LONG_RANGE_GUIDANCE_FINISHED"']),
    "terminal loops must have bounded recovery and a terminal result",
)
check(
    "stable terminal aim",
    '[250,500,800], 650, 0, false' in long_launch,
    "terminal ingress must not recalculate lateral detours with dynamic noise",
)
check(
    "terrain avoidance hysteresis",
    'DRO2026_terrainAvoidanceSide' in terrain and '_allowLateralAvoidance' in terrain,
    "macro guidance may avoid terrain, but terminal guidance must be able to disable side switching",
)
check(
    "vector-only FPV recovery",
    'doMove' not in fpv_controller and '"FPV_VECTOR_RECOVERY"' in fpv_controller,
    "FPV_TERMINAL authority must not issue AI movement commands while MOVE/PATH are disabled",
)
check(
    "broken insertion class quarantined",
    'B_UAArmy_CAT1A2_01' in sanitation and 'DRO2026_runtimeBlockedVehicleClasses' in sanitation,
    "the class producing one CBA invalid-turret warning per second must not enter legacy pools",
)
check(
    "S-300 fire-control radar contract",
    all(token in layered_aa for token in ['"S300_RS_F_UCG"', '"FIRE_CONTROL_RADAR"', '"COMPONENT_VALIDATION_FAILED"', '"radarValidated"']),
    "S-300 must prefer its fire-control radar and explain component-level rollback",
)
check(
    "runtime launcher ammo probe",
    all(token in launcher_ammo for token in ['magazinesAllTurrets', 'weaponsTurret', 'DRO2026_managedVehicles', '_runtimeAmmoCount']),
    "physical turret magazines with positive ammo are stronger evidence than class-only config traversal",
)
check(
    "ordinary launcher ammo remains blocked",
    all(token in launcher_ammo for token in ['"smoke"', '"countermeasure"', '"horn"', '"fake"']),
    "runtime probing must remain fail-closed against non-strategic ammo",
)

payload = {
    "validator": "mp-support-guidance-contracts",
    "passed": sum(1 for _, ok, _ in checks if ok),
    "total": len(checks),
    "checks": [
        {"name": name, "ok": ok, "detail": detail}
        for name, ok, detail in checks
    ],
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
sys.exit(0 if all(ok for _, ok, _ in checks) else 1)
