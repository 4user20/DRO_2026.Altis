from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def explicit_fly_before_crew(source: str) -> bool:
    for match in re.finditer(r'createVehicle\s*\[[^\n;]*"FLY"', source):
        window = source[match.start() : match.start() + 900]
        crew_positions = [
            value
            for value in (
                window.find("createVehicleCrew"),
                window.find("BIS_fnc_spawnVehicle"),
            )
            if value >= 0
        ]
        if not crew_positions:
            continue
        crew_at = min(crew_positions)
        set_positions = [
            value
            for value in (window.find("setPosATL"), window.find("setPosASL"))
            if value >= 0
        ]
        if not set_positions or min(set_positions) > crew_at:
            return False
    return True


parser = ArgumentParser(
    description="DRO 2026 Arma Wiki / Context7 stabilization checks"
)
parser.add_argument("--rpt", action="append", default=[])
args = parser.parse_args()

errors: list[str] = []
warnings: list[str] = []

base_args = [sys.executable, str(ROOT / "tools/validate_rc6.py")]
for item in args.rpt:
    base_args.extend(["--rpt", item])
base = subprocess.run(
    base_args,
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
if base.returncode != 0:
    errors.append("base validate_rc6.py failed")

try:
    cfg = read("dro2026/CfgFunctions.hpp")
    refresh = read("dro2026/functions/core/fn_refreshFactionAssets.sqf")
    catalog = read("dro2026/functions/core/fn_publishSupportCatalog.sqf")
    server_support = read("dro2026/functions/support/fn_serverRequestSupport.sqf")
    launch_fpv = read("dro2026/functions/support/fn_launchFPVStrike.sqf")
    launch_isr = read("dro2026/functions/support/fn_launchISR.sqf")
    launch_long = read("dro2026/functions/support/fn_launchLongRangeStrike.sqf")
    request_long = read("dro2026/functions/support/fn_requestLongRangeSupport.sqf")
    request_air = read("dro2026/functions/support/fn_requestAirSupport.sqf")
    enemy_air = read("dro2026/functions/directors/fn_enemyAirDirector.sqf")
    enemy_isr = read("dro2026/functions/directors/fn_enemyISRDirector.sqf")
    enemy_long = read("dro2026/functions/directors/fn_longRangeDroneDirector.sqf")
    friendly_strike = read("dro2026/functions/directors/fn_friendlyStrikeDirector.sqf")
    console = read("dro2026/functions/support/fn_openSupportConsole.sqf")
    selector = read("dro2026/functions/core/fn_selectObjectiveOpportunity.sqf")
    materializer = read("dro2026/functions/objectives/fn_selectObjective.sqf")
    recon = read("dro2026/functions/objectives/fn_objectiveISRRecon.sqf")
    validator = read("tools/validate_rc6.py")
except FileNotFoundError as exc:
    errors.append(f"missing file: {exc}")
else:
    require(
        errors,
        "class createContactRecord {};" in cfg,
        "createContactRecord is not registered",
    )

    require(
        errors,
        all(
            token in server_support
            for token in (
                "isPlayer _requester",
                'isKindOf "VirtualMan_F"',
                "remoteExecutedOwner",
                "isDedicated",
                "_remoteOwner <= 2",
                "owner _requester",
            )
        ),
        "support authority does not reject virtual/zero-owner callers",
    )

    require(
        errors,
        "_cfgSide == _sideNumber" in refresh
        and "ENEMY_CAS_AIR" in refresh
        and "ePlaneClasses" in refresh
        and "eHeliClasses" in refresh,
        "faction refresh does not construct exact-side enemy CAS pools",
    )
    require(
        errors,
        "in [_sideNumber, 2]" not in refresh
        and "in [_sideNumber, 2]" not in catalog
        and "in [_sideNumber, 2]" not in launch_isr,
        "INDEPENDENT side still leaks into WEST/EAST pools",
    )
    require(
        errors,
        "ENEMY_CAS_AIR" in enemy_air and 'getOrDefault ["AIR_EAST"' not in enemy_air,
        "enemy air remains hardcoded to EAST assets",
    )

    for label, source in (
        ("enemy air", enemy_air),
        ("enemy ISR", enemy_isr),
        ("friendly ISR", launch_isr),
        ("FPV", launch_fpv),
        ("long range", launch_long),
        ("friendly CAS", request_air),
    ):
        require(
            errors,
            explicit_fly_before_crew(source),
            f"{label}: empty FLY airframe lacks explicit position before crew",
        )
        require(
            errors,
            "deleteVehicleCrew" in source and "deleteGroup" in source,
            f"{label}: crew/group cleanup contract incomplete",
        )

    require(
        errors,
        all(
            token in launch_fpv
            for token in ("_applyFlightVector", "vectorCrossProduct", "setVectorDirAndUp")
        ),
        "FPV guidance does not build an orthogonal flight frame",
    )
    require(
        errors,
        all(
            token in launch_long
            for token in ("_applyFlightVector", "vectorCrossProduct", "setVectorDirAndUp")
        ),
        "long-range guidance does not build an orthogonal flight frame",
    )
    fixed_up = re.compile(
        r"setVectorDirAndUp\s*\[\s*_[A-Za-z0-9_]+\s*,\s*"
        r"\[\s*0\s*,\s*0\s*,\s*1\s*\]\s*\]"
    )
    require(
        errors,
        not fixed_up.search(launch_fpv) and not fixed_up.search(launch_long),
        "pitched flight still uses fixed [0,0,1] vectorUp",
    )

    require(
        errors,
        "nearestObjects" not in launch_fpv and "nearestObjects" not in launch_long,
        "guided strike can still reacquire an arbitrary nearby target",
    )
    require(
        errors,
        '_requestedClass != ""' in launch_fpv and "side-correct registry" in launch_fpv,
        "FPV exact class can silently fall back",
    )
    require(
        errors,
        "_selectionValid" in launch_isr
        and '_class == ""' in launch_isr
        and 'getNumber (_classCfg >> "side")' in launch_isr,
        "ISR named/exact profile can silently cross side or fall back",
    )
    require(
        errors,
        "_selectionValid" in launch_long
        and "_exactClass in _pool" in launch_long,
        "long-range exact class can silently become AUTO",
    )

    require(
        errors,
        "_refundReservation" in launch_isr
        and "DRO2026_lastISRRequest = -999" in launch_isr,
        "failed ISR materialization does not restore stock/cooldown",
    )
    require(
        errors,
        "_reservationNodeId" in launch_long
        and "LONG_RANGE_LAUNCH_REFUND" in launch_long,
        "long-range per-airframe refund is missing",
    )
    require(
        errors,
        "LONG_RANGE_SALVO_ABORT" in enemy_long
        and "_isLiveStrategicContact" in enemy_long,
        "enemy salvo abort/stale-contact accounting is incomplete",
    )
    require(
        errors,
        not re.search(
            r'DRO2026_resources\s+set\s*\[\s*"friendlyFP5Stock"',
            request_long,
        )
        and not re.search(
            r'DRO2026_resources\s+set\s*\[\s*"friendlyFP5Stock"',
            friendly_strike,
        ),
        "FP-5 bypasses its selected reservation pool",
    )

    for label, source in (
        ("enemy air", enemy_air),
        ("enemy ISR", enemy_isr),
        ("friendly strike", friendly_strike),
        ("enemy long range", enemy_long),
    ):
        require(
            errors,
            "allPlayers" not in source or 'isKindOf "VirtualMan_F"' in source,
            f"{label}: allPlayers includes virtual clients",
        )

    require(
        errors,
        "_canUseFP5" in friendly_strike and "_strategicAvailable" in friendly_strike,
        "automated strike recommendation ignores usable stock/profile",
    )
    require(
        errors,
        "_availableCategories" in console,
        "support console still shows unpublished empty categories",
    )

    require(
        errors,
        "last-resort command objective" in selector
        and 'missionNamespace setVariable ["DRO2026_selectedOpportunity", _fallback]' in selector,
        "objective fallback can reuse stale opportunity state",
    )
    require(
        errors,
        "OBJECTIVE_MATERIALIZATION_FAILED" in materializer and "_maxAttempts = 4" in materializer,
        "objective materialization failures are not retried",
    )
    require(
        errors,
        "ISR_RELAY" in recon and "Land_TTowerSmall_1_F" in recon,
        "ISR objective is not physically materialized",
    )

    require(
        errors,
        "single fireAtTarget" not in validator,
        "validator still treats valid fireAtTarget [target] syntax as an error",
    )
    require(
        errors,
        "run_hemtt_if_configured" in validator and "--require-hemtt" in validator,
        "validator lacks optional HEMTT integration",
    )
    require(
        errors,
        "air materialization" in validator
        and "side isolation" in validator
        and "flight vectors" in validator
        and "virtual clients" in validator,
        "base validator lacks Arma Wiki regression contracts",
    )

rpt_patterns = {
    "undefined faction/locality variable": re.compile(
        r"Undefined variable in expression: _(?:thisFac|isPlayerFaction|"
        r"isEnemyFaction|spawnDirection|applyFlightVector)",
        re.I,
    ),
    "generic expression error": re.compile(
        r"(?:Error in expression|Generic error in expression)",
        re.I,
    ),
    "type mismatch": re.compile(
        r"Error Тип (?:Массив|Объект|Группа), ожидался",
        re.I,
    ),
    "legacy TOS support": re.compile(r"_artyVeh\s*=.*pook_TOS1A", re.I),
    "fire handler spam": re.compile(r"\[DEBUG\] FIRED", re.I),
    "watchdog freeze": re.compile(r"No alive in \d+ ms", re.I),
}
rpt_findings: dict[str, list[str]] = {name: [] for name in rpt_patterns}
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        errors.append(f"RPT not found: {path}")
        continue
    source = path.read_text(encoding="utf-8", errors="replace")
    for name, pattern in rpt_patterns.items():
        for match in pattern.finditer(source):
            line = source.count("\n", 0, match.start()) + 1
            rpt_findings[name].append(f"{path}:{line}")

report = {
    "validator": "rc6-arma-wiki-stabilization",
    "base_validator_exit": base.returncode,
    "base_validator_output": base.stdout if base.returncode != 0 else "",
    "errors": errors,
    "warnings": warnings,
    "rpt_findings": rpt_findings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors or any(rpt_findings.values()) else 0)
