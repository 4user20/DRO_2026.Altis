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


def require(checks: list[str], condition: bool, message: str) -> None:
    if not condition:
        checks.append(message)


parser = ArgumentParser(
    description="DRO 2026 RC6 RPT/support/objective stabilization checks"
)
parser.add_argument("--rpt", action="append", default=[])
args = parser.parse_args()

errors: list[str] = []
warnings: list[str] = []

base = subprocess.run(
    [sys.executable, str(ROOT / "tools/validate_rc6.py")],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
if base.returncode != 0:
    errors.append("base validate_rc6.py failed")

try:
    faction1 = read("sunday_system/fnc_lib/defineFactionClasses_rc4_part1.inc")
    faction3 = read("sunday_system/fnc_lib/defineFactionClasses_rc4_part3.inc")
    client = read("dro2026/functions/core/fn_clientInit.sqf")
    add_supports = read("sunday_system/player_setup/addSupports.sqf")
    catalog = read("dro2026/functions/core/fn_publishSupportCatalog.sqf")
    cfg = read("dro2026/CfgFunctions.hpp")
    contact_record = read("dro2026/functions/core/fn_createContactRecord.sqf")
    console = read("dro2026/functions/support/fn_openSupportConsole.sqf")
    targeting = read("dro2026/functions/support/fn_beginSupportTargeting.sqf")
    server_support = read("dro2026/functions/support/fn_serverRequestSupport.sqf")
    request_isr = read("dro2026/functions/support/fn_requestISR.sqf")
    request_long = read("dro2026/functions/support/fn_requestLongRangeSupport.sqf")
    launch_fpv = read("dro2026/functions/support/fn_launchFPVStrike.sqf")
    launch_isr = read("dro2026/functions/support/fn_launchISR.sqf")
    launch_long = read("dro2026/functions/support/fn_launchLongRangeStrike.sqf")
    selector = read("dro2026/functions/core/fn_selectObjectiveOpportunity.sqf")
    materializer = read("dro2026/functions/objectives/fn_selectObjective.sqf")
    recon = read("dro2026/functions/objectives/fn_objectiveISRRecon.sqf")
    enemy_isr = read("dro2026/functions/directors/fn_enemyISRDirector.sqf")
    enemy_air = read("dro2026/functions/directors/fn_enemyAirDirector.sqf")
    operation = read("dro2026/functions/directors/fn_operationDirector.sqf")
    enemy_strike = read("dro2026/functions/directors/fn_longRangeDroneDirector.sqf")
    friendly_strike = read("dro2026/functions/directors/fn_friendlyStrikeDirector.sqf")
    artillery = read("dro2026/functions/support/fn_requestArtillery.sqf")
    air = read("dro2026/functions/support/fn_requestAirSupport.sqf")
    base_validator = read("tools/validate_rc6.py")
except FileNotFoundError as exc:
    errors.append(f"missing file: {exc}")
else:
    require(
        errors,
        'private _thisFac = getText' in faction1,
        "faction scan must read faction with getText",
    )
    require(
        errors,
        not re.search(r'_thisFac\s*=.*BIS_fnc_GetCfgData', faction1),
        "nil-prone _thisFac BIS_fnc_GetCfgData assignment returned",
    )
    require(
        errors,
        'private _isPlayerFaction' in faction1
        and 'private _isEnemyFaction' in faction1,
        "per-class faction flags must be local",
    )
    require(
        errors,
        'count _pInfEditorSubcats' in faction3
        and 'count _eInfEditorSubcats' in faction3,
        "faction pool summary must count arrays directly",
    )
    require(
        errors,
        not re.search(r'\{\s*_x\s*\}\s*count\s+_[pe]InfEditorSubcats', faction3),
        "array-valued count predicate returned",
    )

    require(errors, 'DRO2026_supportCatalogReady' in client, "clientInit must wait for support catalog")
    require(errors, 'DRO2026_missionEnding' in client, "clientInit lobby wait must abort only on mission end")
    require(errors, 'playersReady timeout' not in client, "fixed-duration playersReady timeout returned")
    require(errors, 'Панель поддержки штаба' in client, "reliable support player action missing")

    require(errors, 'createVehicle' not in add_supports, "legacy addSupports still creates a random physical support asset")
    require(errors, 'uavPatrol.sqf' not in add_supports, "legacy random UAV patrol still starts from addSupports")
    require(errors, 'pook_TOS1A' not in add_supports, "legacy TOS-1A support selection returned")
    require(errors, 'class publishSupportCatalog' in cfg, "support catalog publisher is not registered")
    require(errors, 'class createContactRecord {};' in cfg, "contact record constructor is not registered")
    require(
        errors,
        all(token in contact_record for token in [
            'positionMean', 'uncertaintyRadius', 'sources',
            'velocityEstimate', 'bdaState', 'falseContactProbability',
        ]),
        "contact record schema v2 is incomplete",
    )
    require(
        errors,
        'DRO2026_supportCatalog' in catalog
        and 'STRIKE_CLASS:' in catalog
        and 'ISR_CLASS:' in catalog,
        "concrete support catalog is incomplete",
    )
    require(errors, 'pook_tos1a' in catalog.lower(), "known unstable TOS class is not explicitly denied")
    require(
        errors,
        'DRO2026_supportCatalog' in console
        and 'RscCombo' in console
        and 'Класс:' in console,
        "support UI does not consume concrete server catalog",
    )
    require(
        errors,
        'FPV_CLASS_AUTO:' in targeting
        and 'STRIKE_CLASS:' in targeting
        and 'ARTY:' in targeting
        and 'AIR:' in targeting,
        "targeting router lacks concrete class modes",
    )
    require(errors, 'onMapSingleClick ""' in targeting, "map targeting cancel does not clear stale handler")
    click_handler = re.search(r'onMapSingleClick "([^"]+)"', targeting)
    require(
        errors,
        click_handler is not None
        and click_handler.group(1).find("setVariable ['DRO2026_pendingSupport', []]")
        < click_handler.group(1).find("openMap false"),
        "map click must clear pending request before closing the map",
    )

    require(errors, 'remoteExecutedOwner' in server_support, "support authority does not bind requester to remote owner")
    require(errors, 'isPlayer _requester' in server_support and 'owner _requester' in server_support, "support authority does not validate a real requester")
    require(errors, '_catalogContains' in server_support, "server support dispatcher does not validate published catalog entries")
    require(
        errors,
        all(token in server_support for token in [
            'FPV_CLASS_MANUAL:', 'ISR_CLASS:', 'STRIKE_CLASS:',
            'ARTY:%1', 'AIR:%1',
        ]),
        "server catalog validation is incomplete",
    )
    require(
        errors,
        all(token in server_support for token in [
            'isEqualType true', 'isEqualType 0', 'isEqualType ""',
        ]),
        "support payload type validation is incomplete",
    )
    require(
        errors,
        '_knownTypes = ["AUTO", "MICRO", "RQ7", "MQ4A", "TACTICAL", "HALE"]' in request_isr,
        "ISR request accepts unknown named profiles",
    )
    require(
        errors,
        'private _classAllowed = true;' in request_isr
        and 'if (!_classAllowed) exitWith' in request_isr,
        "ISR exact-class rejection can fall through nested scope",
    )
    require(
        errors,
        '_knownTypes = ["AUTO", "FP1", "FP2", "BM35", "BULAVA", "FP5", "SHAHED"]' in request_long,
        "long-range request accepts unknown named profiles",
    )
    require(
        errors,
        'case "AUTO"' in request_long and 'default {false}' in request_long,
        "long-range availability falls back to arbitrary request types",
    )
    require(errors, '_decoy && {_requestUpper != "AUTO"}' in request_long, "decoy flag can be combined with a concrete strike profile")
    require(
        errors,
        not re.search(r'DRO2026_resources\s+set\s*\[\s*"friendlyFP5Stock"', request_long),
        "manual FP5 request bypasses the selected reservation pool",
    )
    require(errors, 'if (_requestUpper == "FP5") then {"friendlyFP5Stock"}' in request_long, "FP5 does not use its dedicated reservation pool")
    require(errors, '_refundReservation' in launch_isr and 'DRO2026_lastISRRequest = -999' in launch_isr, "failed ISR materialization does not restore stock and cooldown")
    require(errors, 'isNull driver _uav' not in launch_isr and 'isNull (driver _uav)' in launch_isr, "ISR crew null check still relies on implicit command precedence")
    require(errors, '_reservationNodeId' in launch_long and 'LONG_RANGE_LAUNCH_REFUND' in launch_long, "long-range per-airframe refund contract is missing")
    require(errors, 'isNull driver _drone' not in launch_long and 'isNull (driver _drone)' in launch_long, "long-range crew null check still relies on implicit command precedence")
    require(errors, 'nearestObjects' not in launch_fpv and 'последнюю подтверждённую точку' in launch_fpv, "FPV guidance can still hunt arbitrary nearby targets")

    require(errors, 'DRO2026_usedObjectiveNodes' in selector and 'DRO2026_usedObjectiveTypes' in selector, "selector does not suppress repeated type/node")
    require(errors, 'selectRandom DRO2026_OPERATION_PACKAGES' not in selector, "random objective packages returned")
    require(
        errors,
        'last-resort command objective' in selector
        and 'missionNamespace setVariable ["DRO2026_selectedOpportunity", _fallback]' in selector,
        "objective fallback can reuse stale selected opportunity",
    )
    require(errors, 'ISR_RELAY' in recon and 'Land_TTowerSmall_1_F' in recon and 'relatedNodeId' in recon, "ISR objective is still an empty observation sector")
    require(errors, 'OBJECTIVE_MATERIALIZATION_FAILED' in materializer and '_maxAttempts = 4' in materializer, "objective adapter failure is not retried")

    require(errors, 'allPlayers' in enemy_isr and 'FRIENDLY_HQ' in enemy_isr and 'FRIENDLY_LOGISTICS' in enemy_isr, "enemy ISR does not search player strategic sites")
    require(errors, 'RUS_VKS_forpostru' in enemy_isr and 'subjectId' in enemy_isr, "enemy long-range ISR/subject identity chain incomplete")
    require(errors, not re.search(r'\bplayer\b', re.sub(r'allPlayers', '', enemy_isr)), "server-only enemy ISR still depends on global player")
    require(errors, 'forEach allPlayers' in enemy_air and 'doFire _target' in enemy_air, "enemy air director lacks dedicated-safe targeting")
    require(errors, 'fireAtTarget' not in enemy_air and 'alive player' not in enemy_air and 'vehicle player' not in enemy_air, "enemy air director still uses invalid fire syntax or global player")
    require(errors, 'LONG_RANGE_ATTACK' in operation and 'FPV_ATTACK' in operation and 'LOGISTICS' in operation, "operation director target priority is incomplete")
    require(errors, 'private _validTarget = true;' in operation and 'if (!_validTarget) exitWith' in operation and 'alive _target' in operation, "FPV intent target rejection can fall through nested scope")
    require(errors, 'subjectId' in enemy_strike and 'DRO2026_MAX_ENEMY_LONG_RANGE_SALVO' in enemy_strike, "enemy ISR-to-strike chain or salvo cap missing")
    require(errors, '_isLiveStrategicContact' in enemy_strike and 'true, _nodeId' in enemy_strike, "enemy long-range strike can consume stock for a stale subject or cannot refund a failed airframe")
    require(
        errors,
        not re.search(r'DRO2026_resources\s+set\s*\[\s*"friendlyFP5Stock"', friendly_strike),
        "automated FP5 launch bypasses the selected reservation pool",
    )

    require(errors, 'DRO2026_supportFireLockUntil' in artillery and 'DRO2026_activeHeavySupport' in artillery, "artillery is outside shared heavy-fire budget")
    require(errors, 'DRO2026_supportFireLockUntil' in air and 'DRO2026_activeHeavySupport' in air, "CAS is outside shared heavy-fire budget")
    require(errors, 'pook_tos1a' in artillery.lower(), "artillery request does not reject unstable TOS class")

    require(errors, "path.suffix.lower() != '.inc'" in base_validator, "base validator still parses include fragments as standalone SQF")
    require(errors, 'resource accounting' in base_validator and 'enemy air locality' in base_validator, "base validator lacks audit regression contracts")

rpt_patterns = {
    "mission undefined faction variable": re.compile(
        r"Undefined variable in expression: _(?:thisFac|isPlayerFaction|isEnemyFaction)",
        re.I,
    ),
    "mission faction bool error": re.compile(r"Error Тип Массив, ожидался Булево", re.I),
    "support lobby timeout": re.compile(r"clientInit: playersReady timeout", re.I),
    "repeated empty ISR tasks": re.compile(
        r"taskIDs\s*=\s*\[\s*\"D26_ISR_[^\"]+\"\s*,\s*\"D26_ISR_[^\"]+\"\s*,\s*\"D26_ISR_",
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
    "validator": "rc6-rpt-stabilization",
    "base_validator_exit": base.returncode,
    "base_validator_output": base.stdout if base.returncode != 0 else "",
    "errors": errors,
    "warnings": warnings,
    "rpt_findings": rpt_findings,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(1 if errors else 0)
