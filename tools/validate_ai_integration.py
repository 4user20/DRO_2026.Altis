from pathlib import Path
import json, re, sys

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    target = ROOT / path
    return target.read_text(encoding='utf-8', errors='replace') if target.is_file() else ''

def check(report, group, path, required=(), forbidden=()):
    source = read(path)
    if not source:
        report[group].append(f'{path}: missing file'); return
    missing = [x for x in required if x not in source]
    blocked = [x for x in forbidden if x in source]
    if missing: report[group].append(f"{path}: missing {', '.join(missing)}")
    if blocked: report[group].append(f"{path}: forbidden {', '.join(blocked)}")

def main():
    names = ['registration','intent ownership','fallback','snapshot','validation','transport','strategy','leases','fpv','secrets','sidecar']
    errors = {name: [] for name in names}
    cfg = read('dro2026/CfgFunctions.hpp')
    functions = ('initAITransport','writeAIRequest','readAIResponses','buildIntentCandidates','buildAISnapshot',
        'validateAIDecision','commitIntent','applyStrategicPolicy','aiResponseListener','aiOperationDirector',
        'strategicAIDirector','assignManagedGroupIds','claimGroupLease','isFPVExternallyControlled','calculateFPVLeadPoint')
    for name in functions:
        if not re.search(rf'\bclass\s+{re.escape(name)}\s*\{{', cfg): errors['registration'].append(name)

    start = read('dro2026/functions/directors/fn_startDirectors.sqf')
    if 'spawn DRO2026_fnc_aiOperationDirector' not in start: errors['intent ownership'].append('AI director is not started')
    if 'spawn DRO2026_fnc_operationDirector' in start: errors['intent ownership'].append('legacy director is started in parallel')

    check(errors,'fallback','dro2026/functions/core/fn_preInit.sqf',('DRO2026_AI_MODE = "OBSERVE"','DRO2026_AI_TACTICAL_TIMEOUT'))
    check(errors,'fallback','dro2026/functions/ai/fn_aiOperationDirector.sqf',('"OFF"','"OBSERVE"','"HYBRID"','DETERMINISTIC_AI_TIMEOUT','DETERMINISTIC_INVALID_AI'))
    check(errors,'snapshot','dro2026/functions/ai/fn_buildAISnapshot.sqf',('uncertaintyRadius','velocityEstimate','bdaState','DRO2026_networkNodes','DRO2026_networkEdges','DRO2026_eventLog','_candidateRows'),('allUnits','allPlayers'))
    check(errors,'validation','dro2026/functions/ai/fn_validateAIDecision.sqf',('STALE_SEQUENCE','UNKNOWN_CANDIDATE','EXECUTE','HOLD','USE_DETERMINISTIC'))
    check(errors,'validation','dro2026/functions/ai/fn_commitIntent.sqf',('selectionSource','aiModifiers','DRO2026_currentIntent'),('createVehicle','addWaypoint'))

    check(errors,'transport','dro2026/functions/ai/fn_initAITransport.sqf',('isNil "OO_INIDBI"','deterministic fallback','DRO2026_aiTransportReady'))
    check(errors,'transport','dro2026/functions/ai/fn_writeAIRequest.sqf',('"DROAI_out"','OO_INIDBI'),('http://','https://','Authorization','apiKey'))
    check(errors,'transport','dro2026/functions/ai/fn_readAIResponses.sqf',('"DROAI_in"','"ack-out"','"decision"','"strategic-policy"'))

    check(errors,'strategy','dro2026/functions/ai/fn_applyStrategicPolicy.sqf',('DRO2026_aiPendingStrategicSequence','"OBSERVE"','"HYBRID"','desiredTempo','reserveCommitment','expiresAt'),('createVehicle','addWaypoint','setPos'))
    check(errors,'strategy','dro2026/functions/ai/fn_strategicAIDirector.sqf',('PHASE_CHANGED','NETWORK_NODE_DESTROYED','DELIVERY_INTERDICTED','DRO2026_AI_STRATEGIC_INTERVAL'))
    check(errors,'leases','dro2026/functions/maneuver/fn_claimGroupLease.sqf',('DRO2026_commandOwner','DRO2026_commandLeaseUntil','DRO2026_commandRevision'))
    check(errors,'leases','dro2026/functions/directors/fn_orderEncirclement.sqf',('DRO2026_commandLeaseUntil','claimGroupLease','positionMean'))

    check(errors,'fpv','dro2026/functions/support/fn_isFPVExternallyControlled.sqf',('DRO2026_manualControl','isUAVConnected','bis_fnc_moduleRemoteControl_owner'))
    check(errors,'fpv','dro2026/functions/support/fn_calculateFPVLeadPoint.sqf',('velocityEstimate','uncertaintyRadius','_leadTime','_leadFactor'),('allUnits','vehicles','doMove','forceSpeed','attachTo'))
    check(errors,'fpv','dro2026/functions/support/fn_launchFPVStrike.sqf',('isFPVExternallyControlled','calculateFPVLeadPoint','calculateTerrainAwareAim','DRO2026_PHYSICAL_DRONE_LIMIT'),('forceSpeed 150','allUnits','attachTo'))
    check(errors,'fpv','dro2026/functions/directors/fn_enemyFPVDirector.sqf',('selectionSource','salvoCount','relocateAfter','DRO2026_MAX_DRONES_PER_SALVO','changeNetworkNodeStock'))

    mission = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in (ROOT/'dro2026').rglob('*') if p.is_file() and p.suffix.lower() in {'.sqf','.hpp','.inc'})
    for pattern, label in ((r'sk-[\w-]{16,}','OpenAI key'),(r'nvapi-[\w-]{12,}','NVIDIA key'),(r'Authorization\s*:\s*Bearer','Authorization header'),(r'https?://','external URL')):
        if re.search(pattern, mission, re.I): errors['secrets'].append(label)

    check(errors,'sidecar','tools/dro-ai-director/src/index.js',('void drain()','maxQueue','maxSnapshotAgeSeconds','circuitOpenUntil','appendAudit'))
    check(errors,'sidecar','tools/dro-ai-director/src/validate.js',('UNKNOWN_CANDIDATE','STALE_SEQUENCE','toSqfDecision','toSqfPolicy'))
    check(errors,'sidecar','tools/dro-ai-director/src/provider.js',('/chat/completions','response_format','AbortController','fallbackProfile'))

    warnings = ['INIDBI2 under Proton, real provider APIs and FPV in-engine behavior require Arma runtime verification.']
    print(json.dumps({'version':'rc6-ai-director','errors':errors,'warnings':warnings},ensure_ascii=False,indent=2))
    return 1 if any(errors.values()) else 0

if __name__ == '__main__': sys.exit(main())
