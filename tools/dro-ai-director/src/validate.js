'use strict';
function clamp(value, min, max, fallback) { const n = Number(value); return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback; }
function clean(value, max=80) { return String(value ?? '').replace(/[^A-Za-z0-9_:\-.]/g,'_').slice(0,max); }
function validateTactical(raw, snapshot) {
  if (!raw || typeof raw !== 'object') throw new Error('Decision is not an object');
  if (Number(raw.snapshotSequence) !== snapshot.snapshotSequence) throw new Error('STALE_SEQUENCE');
  const decision = String(raw.decision || '').toUpperCase();
  if (!['EXECUTE','HOLD','USE_DETERMINISTIC'].includes(decision)) throw new Error('INVALID_DECISION');
  let candidateId = String(raw.selectedCandidateId || '');
  if (decision === 'EXECUTE' && !snapshot.candidates.some((c) => c.id === candidateId)) throw new Error('UNKNOWN_CANDIDATE');
  if (decision !== 'EXECUTE') candidateId = '';
  const m = raw.actionModifiers && typeof raw.actionModifiers === 'object' ? raw.actionModifiers : {};
  return {
    schema:1, snapshotSequence:snapshot.snapshotSequence, selectedCandidateId:candidateId, decision,
    delaySeconds:clamp(raw.delaySeconds,0,30,5), tempoModifier:clamp(raw.tempoModifier,0.7,1.3,1),
    actionModifiers:{salvoCount:Math.round(clamp(m.salvoCount,1,3,1)),relocateAfter:Boolean(m.relocateAfter),searchRadius:clamp(m.searchRadius,300,2500,900),holdSeconds:clamp(m.holdSeconds,15,90,30)},
    reasonCode:clean(raw.reasonCode || 'NO_REASON')
  };
}
function validateStrategic(raw, snapshot) {
  if (!raw || typeof raw !== 'object') throw new Error('Policy is not an object');
  if (Number(raw.snapshotSequence) !== snapshot.snapshotSequence) throw new Error('STALE_SEQUENCE');
  const doctrines = ['DRONE_HEAVY','ARTILLERY_HEAVY','DEFENSIVE_NETWORK','MOBILE_RESERVES'];
  const doctrine = doctrines.includes(String(raw.doctrine)) ? String(raw.doctrine) : snapshot.operation.doctrine;
  return {
    schema:1, snapshotSequence:snapshot.snapshotSequence, doctrine,
    desiredTempo:clamp(raw.desiredTempo,0.15,0.9,0.5), reconPressure:clamp(raw.reconPressure,0,1,0.5),
    strikePressure:clamp(raw.strikePressure,0,1,0.5), reserveCommitment:clamp(raw.reserveCommitment,0,0.85,0.45),
    logisticsPriority:clamp(raw.logisticsPriority,0,1,0.5), recoveryBias:clamp(raw.recoveryBias,0,1,0.5),
    pauseAfterMajorAttack:Math.round(clamp(raw.pauseAfterMajorAttack,30,180,60)),
    priorities:(Array.isArray(raw.priorities)?raw.priorities:[]).slice(0,6).map((x)=>clean(x,60)), reasonCode:clean(raw.reasonCode || 'NO_REASON')
  };
}
function toSqfDecision(result, meta) {
  const m = result.actionModifiers || {};
  return ['TACTICAL_INTENT', result.snapshotSequence, 'READY', result.selectedCandidateId, result.decision, result.delaySeconds, result.tempoModifier, m.salvoCount || 1, Boolean(m.relocateAfter), m.searchRadius || 900, m.holdSeconds || 30, result.reasonCode, meta.latencyMs, meta.provider, meta.model];
}
function toSqfPolicy(result, meta) {
  return ['STRATEGIC_POLICY',result.snapshotSequence,'READY',result.doctrine,result.desiredTempo,result.reconPressure,result.strikePressure,result.reserveCommitment,result.logisticsPriority,result.recoveryBias,result.pauseAfterMajorAttack,result.priorities,result.reasonCode,meta.latencyMs,meta.provider,meta.model];
}
module.exports = { validateTactical, validateStrategic, toSqfDecision, toSqfPolicy };
