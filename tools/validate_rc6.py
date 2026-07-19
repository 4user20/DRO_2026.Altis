from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {'.sqf', '.inc', '.hpp', '.ext', '.sqm'}
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)


def text(path: Path) -> str:
    return path.read_text(encoding='utf-8', errors='replace')


def include_target(owner: Path, raw: str) -> Path | None:
    """Resolve includes exactly from the file containing #include.

    Arma's preprocessor does not retry a missing nested include from the mission
    root. A permissive ROOT fallback previously hid broken paths in nested .inc
    files and allowed a release-blocking error into RC6.
    """
    normalized = Path(raw.replace('\\', '/'))
    candidate = (owner.parent / normalized).resolve()
    if candidate.is_file() and (candidate == ROOT or ROOT in candidate.parents):
        return candidate
    return None


def expand(path: Path, stack: tuple[Path, ...] = ()) -> tuple[str, list[str]]:
    path = path.resolve()
    if path in stack:
        cycle = ' -> '.join(str(item.relative_to(ROOT)) for item in (*stack, path))
        return '', [f'include cycle: {cycle}']
    source = text(path)
    errors: list[str] = []

    def replace(match: re.Match[str]) -> str:
        target = include_target(path, match.group(1))
        if target is None:
            errors.append(f'{path.relative_to(ROOT)}: missing include {match.group(1)}')
            return ''
        nested, nested_errors = expand(target, (*stack, path))
        errors.extend(nested_errors)
        return f'\n// INCLUDED {target.relative_to(ROOT)}\n{nested}\n'

    return INCLUDE_RE.sub(replace, source), errors


def clean(source: str) -> tuple[str, str]:
    out: list[str] = []
    i = 0
    state = 'code'
    quote = ''
    while i < len(source):
        if state == 'code':
            if source.startswith('//', i):
                state = 'line'; out.extend('  '); i += 2
            elif source.startswith('/*', i):
                state = 'block'; out.extend('  '); i += 2
            elif source[i] in {'"', "'"}:
                state = 'string'; quote = source[i]; out.append(' '); i += 1
            else:
                out.append(source[i]); i += 1
        elif state == 'line':
            if source[i] == '\n': state = 'code'; out.append('\n')
            else: out.append(' ')
            i += 1
        elif state == 'block':
            if source.startswith('*/', i): state = 'code'; out.extend('  '); i += 2
            else: out.append('\n' if source[i] == '\n' else ' '); i += 1
        else:
            if source[i] == quote:
                if i + 1 < len(source) and source[i + 1] == quote:
                    out.extend('  '); i += 2
                else:
                    state = 'code'; quote = ''; out.append(' '); i += 1
            else:
                out.append('\n' if source[i] == '\n' else ' '); i += 1
    if state == 'line': state = 'code'
    return ''.join(out), state


def delimiters(label: str, source: str) -> list[str]:
    source, state = clean(source)
    pairs = {')': '(', ']': '[', '}': '{'}
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    line = 1
    for char in source:
        if char == '\n': line += 1
        elif char in '([{': stack.append((char, line))
        elif char in ')]}':
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f'{label}:{line}: mismatched {char}')
                break
            stack.pop()
    if stack: errors.append(f'{label}: unclosed {stack[-1]}')
    if state != 'code': errors.append(f'{label}: unclosed {state}')
    return errors


def locate(path: Path, source: str, pattern: re.Pattern[str]) -> list[str]:
    return [
        f'{path.relative_to(ROOT)}:{source.count(chr(10), 0, match.start()) + 1}'
        for match in pattern.finditer(source)
    ]


def contract(bucket: list[str], raw: str, required: tuple[str, ...], forbidden: tuple[str, ...] = ()) -> None:
    path = ROOT / raw
    if not path.is_file():
        bucket.append(f'{raw}: missing file')
        return
    source = text(path)
    missing = [token for token in required if token not in source]
    blocked = [token for token in forbidden if token in source]
    if missing: bucket.append(f"{raw}: missing {', '.join(missing)}")
    if blocked: bucket.append(f"{raw}: forbidden {', '.join(blocked)}")


parser = ArgumentParser(description='DRO 2026 RC6 static and semantic validator')
parser.add_argument('--rpt', action='append', default=[])
args = parser.parse_args()

files = sorted(
    path for path in ROOT.rglob('*')
    if path.is_file() and path.suffix.lower() in EXTENSIONS
    and 'graphify-out' not in path.parts and '.git' not in path.parts
)
expanded: dict[Path, str] = {}
stripped: dict[Path, str] = {}
syntax_errors: list[str] = []
for path in files:
    source, include_errors = expand(path)
    syntax_errors.extend(include_errors)
    syntax_errors.extend(delimiters(f'{path.relative_to(ROOT)} [expanded]', source))
    expanded[path] = source
    stripped[path] = clean(source)[0]

cfg = text(ROOT / 'dro2026/CfgFunctions.hpp')
registered = set(re.findall(r'\bclass\s+(\w+)\s*\{(?:\s*(?:preInit|postInit)\s*=\s*1\s*;)?\s*\};', cfg))
function_files = {path.stem[3:] for path in (ROOT / 'dro2026/functions').rglob('fn_*.sqf')}
calls = set().union(*(set(re.findall(r'DRO2026_fnc_(\w+)', source)) for source in expanded.values()))
function_errors = {
    'unregistered_files': sorted(function_files - registered),
    'missing_files': sorted(registered - function_files),
    'unregistered_calls': sorted(calls - registered - {'log'}),
}

patterns = {
    'Bo_Mk82': re.compile(r'\bBo_Mk82\b', re.I),
    'Titan injection': re.compile(r'\bM_Titan_(?:AT|AP)\b', re.I),
    'Pook direct create': re.compile(r'createVehicle\s*\[\s*["\'][^"\']*pook', re.I),
    'object checkVisibility': re.compile(r'\b_[A-Za-z0-9_]+\s+checkVisibility\s*\[', re.I),
    'single fireAtTarget': re.compile(r'fireAtTarget\s*\[\s*[^,\]\n]+\s*\]', re.I),
    'unsupported orderBy': re.compile(r'\borderBy\b', re.I),
    'chained HashMap get': re.compile(r'DRO2026_networkNodes\s+get\s+_[A-Za-z0-9_]+\s+getOrDefault', re.I),
}
critical = {name: [] for name in patterns}
for path, source in stripped.items():
    if 'dro2026' in path.parts or path.name in {'defineFactionClasses.sqf', 'initPlayerLocal.sqf'}:
        for name, pattern in patterns.items(): critical[name].extend(locate(path, source, pattern))

semantic = {name: [] for name in (
    'faction safety', 'support authority', 'respawn sentinel', 'world state',
    'persistent history', 'contact v2', 'state objectives', 'artillery causality',
    'node logistics', 'EW and AA', 'support ROE'
)}
warnings = {name: [] for name in ('unused constants', 'server player', 'large files', 'legacy enemy resources')}

alias = re.compile(r'(?<!_)(?:pInfClassesUnarmedForWeights|pInfClassUnarmedWeights|eInfClassesUnarmedForWeights|eInfClassUnarmedWeights)\b')
broad_pook = re.compile(r'["\']pook_["\']\s*[,\]}]|find\s+["\']pook_["\']\s*\)?\s*==\s*0', re.I)
for path, source in stripped.items(): semantic['faction safety'].extend(locate(path, source, alias))
for path, source in expanded.items(): semantic['faction safety'].extend(locate(path, source, broad_pook))

for raw in ('fn_requestFPV.sqf', 'fn_requestISR.sqf', 'fn_requestLongRangeSupport.sqf', 'fn_requestArtillery.sqf', 'fn_requestAirSupport.sqf'):
    contract(semantic['support authority'], f'dro2026/functions/support/{raw}', ('if (!isServer)', 'serverRequestSupport'))
contract(semantic['support authority'], 'dro2026/functions/support/fn_showStatus.sqf', ('remoteExecCall',))

start = text(ROOT / 'start.sqf')
server_init = text(ROOT / 'initServer.sqf')
if re.search(r'case\s+3\s*:\s*\{\s*nil\s*\}', start) and not ('DRO2026_respawnDisabled' in server_init and 'respawnTime = -1' in server_init):
    semantic['respawn sentinel'].append('start.sqf nil mode lacks initServer sentinel')

for raw, tokens in {
    'dro2026/functions/core/fn_initState.sqf': ('DRO2026_networkNodes', 'DRO2026_networkEdges', 'DRO2026_eventLog', 'DRO2026_operationState'),
    'dro2026/functions/core/fn_buildCapabilityNetwork.sqf': ('NODE_LOGISTICS_01', 'NODE_ARTILLERY_01', 'EDGE_LOGISTICS_ARTILLERY'),
    'dro2026/functions/directors/fn_operationDirector.sqf': ('DRO2026_currentIntent', 'INTENT_PROPOSED', 'doctrine'),
}.items(): contract(semantic['world state'], raw, tokens)

contract(semantic['persistent history'], 'dro2026/functions/directors/fn_performanceGovernor.sqf', ('syncNetworkState', 'lastCompactedAt'), ('DRO2026_sites = DRO2026_sites select', 'DRO2026_sites deleteAt'))
contract(semantic['persistent history'], 'dro2026/functions/core/fn_syncNetworkState.sqf', ('SITE_DESTROYED', 'NETWORK_NODE_DESTROYED', 'destroyedAt'))
contract(semantic['contact v2'], 'dro2026/functions/core/fn_createContactRecord.sqf', ('positionMean', 'uncertaintyRadius', 'sources', 'velocityEstimate', 'bdaState', 'falseContactProbability'))
contract(semantic['contact v2'], 'dro2026/functions/directors/fn_sensorDirector.sqf', ('PROBABLY_DESTROYED', 'CONFIRMED_DESTROYED', 'BDA_UPDATED'))
contract(semantic['contact v2'], 'dro2026/functions/core/fn_syncContactMarker.sqf', ('ELLIPSE', '_uncertaintyRadius', '_bdaState'))
contract(semantic['state objectives'], 'dro2026/functions/objectives/fn_selectObjective.sqf', ('selectObjectiveOpportunity', 'OBJECTIVE_EXPOSED'), ('selectRandom DRO2026_OPERATION_PACKAGES',))
contract(semantic['state objectives'], 'dro2026/functions/core/fn_selectObjectiveOpportunity.sqf', ('activeOpportunities', 'DRO2026_networkNodes', '_phase'))
contract(semantic['artillery causality'], 'dro2026/functions/objectives/fn_artilleryLoop.sqf', ('ARTILLERY_FIRE', 'observerContact', 'COUNTERBATTERY'), ('getPosATL player', 'getPos player'))
contract(semantic['artillery causality'], 'dro2026/functions/support/fn_requestArtillery.sqf', ('uncertaintyRadius', '_friendlyRisk', '_civilianRisk'))
contract(semantic['node logistics'], 'dro2026/functions/directors/fn_logisticsDirector.sqf', ('DELIVERY_STARTED', 'DELIVERY_MATERIALIZED', 'DELIVERY_COMPLETED', 'DELIVERY_INTERDICTED', 'virtualPosition', 'changeNetworkNodeStock'))
contract(semantic['node logistics'], 'dro2026/functions/objectives/fn_objectiveConvoy.sqf', ('edgeId', 'cargoType', 'toNode', 'DELIVERY_INTERDICTED'), ('["enemySupply", -28]', '["enemyDroneStock", -7]'))
contract(semantic['EW and AA'], 'dro2026/functions/core/fn_getJammingAtPosition.sqf', ('emissionState', 'terrainIntersectASL', 'jammingRadius'))
contract(semantic['EW and AA'], 'dro2026/functions/directors/fn_airDefenceDirector.sqf', ('trackingChannels', 'AA_MISSILE_LAUNCHED', 'AA_EMISSION_CHANGED'))
contract(semantic['EW and AA'], 'dro2026/functions/support/fn_launchISR.sqf', ('EMISSION_DETECTED', 'BURST', '_lastFalseContact', 'getJammingAtPosition'))
contract(semantic['support ROE'], 'dro2026/functions/core/fn_getAirWindow.sqf', ('PERMISSIVE', 'CONTESTED', 'CLOSED', 'civiliansClose', 'friendliesClose'))
contract(semantic['support ROE'], 'dro2026/functions/support/fn_requestAirSupport.sqf', ('getAirWindow', 'AA_ACTIVE', 'TARGET_LOST', 'CIVILIAN_RISK', 'FRIENDLIES_CLOSE'))

preinit = text(ROOT / 'dro2026/functions/core/fn_preInit.sqf')
constants = set(re.findall(r'^\s*(DRO2026_[A-Z0-9_]+)\s*=', preinit, re.MULTILINE))
all_source = '\n'.join(stripped.values())
for name in sorted(constants):
    if len(re.findall(rf'\b{re.escape(name)}\b', all_source)) <= 1: warnings['unused constants'].append(name)
for path, source in stripped.items():
    if re.search(r'if\s*\(\s*!isServer\s*\)\s*exitWith', source[:700]) and re.search(r'\bplayer\b', source): warnings['server player'].append(str(path.relative_to(ROOT)))
    if path.suffix.lower() == '.sqf' and text(path).count('\n') + 1 > 1000: warnings['large files'].append(f'{path.relative_to(ROOT)}:{text(path).count(chr(10)) + 1}')
    if 'dro2026' in path.parts and re.search(r'DRO2026_resources\s+set\s*\[\s*["\']enemy', source) and path.name not in {'fn_logisticsDirector.sqf', 'fn_enemyFPVDirector.sqf', 'fn_longRangeDroneDirector.sqf', 'fn_reactionDirector.sqf'}: warnings['legacy enemy resources'].append(str(path.relative_to(ROOT)))

rpt_patterns = {
    'undefined variable': re.compile(r'Undefined variable(?: in expression)?:?\s*([^\r\n]*)', re.I),
    'expression error': re.compile(r'(?:Error in expression|Generic error in expression)', re.I),
    'network regression': re.compile(r'(?:DRO2026_networkNodes|DRO2026_networkEdges|DRO2026_operationState|DRO2026_currentIntent|DRO2026_eventLog|DRO2026_supplyLanes)', re.I),
}
rpt = {name: [] for name in rpt_patterns}
for raw in args.rpt:
    path = Path(raw).expanduser().resolve()
    if not path.is_file():
        rpt.setdefault('missing file', []).append(str(path)); continue
    source = text(path)
    for name, pattern in rpt_patterns.items():
        rpt[name].extend(f'{path}:{source.count(chr(10), 0, match.start()) + 1}' for match in pattern.finditer(source))

report = {
    'version': 'rc6-capability-network',
    'expanded_entry_files': len(files),
    'registered_count': len(registered),
    'function_file_count': len(function_files),
    'delimiter_or_include_errors': syntax_errors,
    'functions': function_errors,
    'critical_findings': critical,
    'semantic_errors': semantic,
    'semantic_warnings': warnings,
    'rpt_regressions': rpt,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
failed = bool(syntax_errors) or any(function_errors.values()) or any(critical.values()) or any(semantic.values()) or any(rpt.values())
sys.exit(1 if failed else 0)
