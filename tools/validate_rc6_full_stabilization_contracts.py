from __future__ import annotations
from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
errors=[]
def read(path:str)->str:
    p=ROOT/path
    if not p.is_file(): errors.append(f"{path}: missing"); return ""
    return p.read_text(encoding='utf-8',errors='replace')
def require(path:str,*tokens:str)->str:
    s=read(path)
    for token in tokens:
        if token not in s: errors.append(f"{path}: missing contract {token!r}")
    return s
require('dro2026/functions/core/fn_normalizeSupportRequest.sqf','requestId','targetPositionASL','sourceMode','controlMode','COUNT_OUT_OF_RANGE')
require('dro2026/functions/core/fn_resolveRemoteRequester.sqf','remoteExecutedOwner','owner _x','getPlayerUID','REQUESTER_UID_MISMATCH','VirtualMan_F')
require('dro2026/functions/support/fn_serverRequestSupport.sqf','DRO2026_fnc_resolveRemoteRequester','DRO2026_processedSupportRequests','RATE_LIMITED','DRO2026_fnc_makeResult')
for f in ('fn_requestFPV.sqf','fn_requestISR.sqf','fn_requestLongRangeSupport.sqf','fn_requestArtillery.sqf','fn_requestAirSupport.sqf'):
    require(f'dro2026/functions/support/{f}','DRO2026_fnc_submitSupportRequest')
require('dro2026/functions/core/fn_createContactRecord.sqf','subjectNetId','subjectObject','uncertaintyGrowthPerMinute','positionASL','confidence')
require('dro2026/functions/core/fn_resolveContactSubject.sqf','objectFromNetId','PLAYER:','PROBABLY_DESTROYED','SUBJECT_UNRESOLVED')
require('dro2026/functions/core/fn_quarantineContact.sqf','INVALID_RECORD','DRO2026_contactQuarantine')
require('dro2026/functions/core/fn_setFlightAuthority.sqf','ARMA_AI','DRONE_TWEAKS','FPV_TERMINAL','PLAYER','NONE','DRO2026_flightAuthorityRevision')
writers=[]
for path in (ROOT/'dro2026').rglob('*.sqf'):
    src=path.read_text(encoding='utf-8',errors='replace')
    if re.search(r'setVariable\s*\[\s*"DRO2026_flightAuthority"',src): writers.append(path.relative_to(ROOT).as_posix())
if writers != ['dro2026/functions/core/fn_setFlightAuthority.sqf']:
    errors.append(f'flightAuthority writers must be canonical only, got {writers}')
require('dro2026/functions/core/fn_buildWaypointFlightPlan.sqf','"MOVE"','"LOITER"','"DESTROY"','_waypoint setWaypointType _type','setCurrentWaypoint')
require(
    'dro2026/functions/support/fn_launchLongRangeStrike.sqf',
    'DRO2026_fnc_buildWaypointFlightPlan','ARMA_AI','FPV_TERMINAL',
    'LONG_RANGE_TERMINAL_STARTED','NO_TERMINAL_PROGRESS','LONG_RANGE_GUIDANCE_FINISHED'
)
require('dro2026/functions/support/fn_launchISR.sqf','DRO2026_fnc_buildWaypointFlightPlan','LOITER','setCurrentWaypoint')
logistics=require('dro2026/functions/directors/fn_logisticsDirector.sqf','DRO2026_fnc_findRoadAwarePosition','DRO2026_fnc_transferLogisticsCargo','DELIVERY_MATERIALIZATION_REFUND','RETURNING','reservationSettled','DRO2026_MAX_ACTIVE_LOGISTICS_JOBS_PER_SIDE')
if re.search(r'now\s*>=\s*_eta[\s\S]{0,350}changeNetworkNodeStock',logistics,re.I): errors.append('logistics: virtual ETA must not mutate stock')
require('dro2026/functions/core/fn_createSiteRecord.sqf','schema",3','positionASL','roadAnchorNetId','componentManaged','capabilities')
require('dro2026/functions/core/fn_evaluateSiteComponents.sqf','componentManaged','launch','control','relay','resupply','relocate')
require('dro2026/functions/support/fn_requestInterceptor.sqf','airMuzzles','fireAtTarget','aimedAtTarget','canFire','NO_COMPATIBLE_WEAPON','AA_MISSILES')
require('dro2026/functions/core/fn_buildAssetDescriptors.sqf','vehicleClass','launcherClass','weaponClass','muzzleName','magazineClass','ammoClass','airMuzzles')
require('dro2026/functions/core/fn_applyReserveMultiplier.sqf','DRO2026_ReserveMultiplier','DRO2026_reserveMultiplierApplied')
require('start.sqf','DRO2026_PrimaryObjectiveCount','min 5')
require('sunday_system/dialogs/populateStartupMenu.sqf','lbAdd [2106, "4"]','lbAdd [2106, "5"]')
require('dro2026/functions/directors/fn_dynamicObjectiveDirector.sqf','DRO2026_MAX_DYNAMIC_TASKS','BIS_fnc_taskCreate','uncertaintyRadius','CONTACT_UPDATED')
objselect=read('sunday_system/objectives/objSelect.sqf')
for token in ('pushBackUnique "POW"','case "POW"','objectives\\pow.sqf'):
    if token in objselect: errors.append(f'objSelect: forbidden hostage path {token!r}')
civs=read('sunday_system/civilians/generateCivilians.sqf')
for token in ('hostileCivilians.sqf','_createHostileCivUnit','ISHOSTILE'):
    if token in civs: errors.append(f'generateCivilians: forbidden hostile path {token!r}')
require('sunday_system/civilians/generateCivilians.sqf','ModuleCivilianPresence_F','enableDynamicSimulation','hostileCivsEnabled = false')
require('Description.ext','#include "dro2026\\CfgRemoteExec.hpp"')
remote_cfg=require('dro2026/CfgRemoteExec.hpp','class CfgRemoteExec','mode = 1;','class DRO2026_fnc_serverRequestSupport { allowedTargets = 2;','class DRO2026_fnc_confirmUAVControl { allowedTargets = 2;','class DRO2026_fnc_offerFPVControl { allowedTargets = 1;','class DRO2026_fnc_receiveSupportResult { allowedTargets = 1;')
if re.search(r'\bmode\s*=\s*2\s*;',remote_cfg): errors.append('CfgRemoteExec: unrestricted mode = 2 is forbidden')
# RC6 remote execution must use literal named endpoints, never remote call/spawn strings.
for path in (ROOT/'dro2026').rglob('*.sqf'):
    src=path.read_text(encoding='utf-8',errors='replace')
    for match in re.finditer(r'remoteExec(?:Call)?\s*\[\s*([^,\]]+)',src):
        target=match.group(1).strip()
        if not (target.startswith('"') or target.startswith("'")):
            errors.append(f'{path.relative_to(ROOT)}: dynamic remoteExec target {target}')
report={'validator':'rc6-full-stabilization-contracts','errors':sorted(set(errors)),'flightAuthorityWriters':writers}
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(1 if errors else 0)
