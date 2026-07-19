'use strict';
function text(value, max = 160) { return String(value ?? '').replace(/[\r\n\t]/g, ' ').slice(0, max); }
function number(value, fallback = 0) { const n = Number(value); return Number.isFinite(n) ? n : fallback; }
function vec3(value) { return Array.isArray(value) ? [number(value[0]), number(value[1]), number(value[2])] : [0,0,0]; }
function pairs(value) {
  const out = {};
  for (const row of Array.isArray(value) ? value : []) if (Array.isArray(row) && row.length >= 2) out[text(row[0], 80)] = row[1];
  return out;
}
function normalizeSnapshot(raw) {
  if (!Array.isArray(raw) || raw.length < 12) throw new Error('Unsupported DROAI snapshot shape');
  const [protocol, jobType, missionId, sequence, generatedAt, operationRaw, perfRaw, nodesRaw, edgesRaw, contactsRaw, eventsRaw, candidatesRaw, policyRaw] = raw;
  const operation = pairs(operationRaw); const performance = pairs(perfRaw); const currentPolicy = pairs(policyRaw);
  return {
    protocol: text(protocol, 24), jobType: text(jobType, 32).toUpperCase(), missionId: text(missionId, 100),
    sequence: Math.trunc(number(sequence)), generatedAt: number(generatedAt),
    operation: {
      phase: text(operation.phase, 40), doctrine: text(operation.doctrine, 60), alert: number(operation.alert),
      networkHealth: number(operation.networkHealth, 1), intelQuality: number(operation.intelQuality), civilianTrust: number(operation.civilianTrust, 50),
      operationScore: number(operation.operationScore), playerNoise: number(operation.playerNoise)
    },
    performance: {
      fpsAverage: number(performance.fpsAverage, 30), activeEnemyAI: Math.trunc(number(performance.activeEnemyAI)),
      activeDrones: Math.trunc(number(performance.activeDrones)), activeConvoys: Math.trunc(number(performance.activeConvoys)),
      managedGroups: Math.trunc(number(performance.managedGroups))
    },
    nodes: (nodesRaw || []).slice(0, 20).map((n) => ({id:text(n[0],80), type:text(n[1],60), status:text(n[2],40), knownByPlayer:text(n[3],40), health:number(n[4],1), stocks:pairs(n[5]), capabilities:(n[6] || []).map((x)=>text(x,60))})),
    edges: (edgesRaw || []).slice(0, 20).map((e) => ({id:text(e[0],80), from:text(e[1],80), to:text(e[2],80), status:text(e[3],30), risk:number(e[4]), interdictionPressure:number(e[5]), escortLevel:number(e[6]), nextDeliveryIn:number(e[7]), cargo:(e[8] || []).map((x)=>text(x,60))})),
    contacts: (contactsRaw || []).slice(0, 12).map((c) => ({id:text(c[0],100), classification:text(c[1],60), confidence:number(c[2]), uncertaintyRadius:number(c[3]), age:number(c[4]), bdaState:text(c[5],40), subjectId:text(c[6],80), velocityEstimate:vec3(c[7]), value:number(c[8],0.5)})),
    recentEvents: (eventsRaw || []).slice(-30).map((e) => ({sequence:text(e[0],100), type:text(e[1],80), age:number(e[2]), source:text(e[3],80), data:pairs(e[4])})),
    candidates: (candidatesRaw || []).slice(0,20).map((c) => ({id:text(c[0],100), action:text(c[1],60), actor:text(c[2],80), contactId:text(c[3],100), utility:number(c[4]), resourceCost:number(c[5]), constraints:pairs(c[6])})),
    currentPolicy
  };
}
function compactForPrompt(snapshot) {
  return {
    schema: 1, missionId: snapshot.missionId, snapshotSequence: snapshot.sequence, generatedAt: snapshot.generatedAt,
    operation: snapshot.operation, performance: snapshot.performance, nodes: snapshot.nodes, edges: snapshot.edges,
    contacts: snapshot.contacts, recentEvents: snapshot.recentEvents, currentPolicy: snapshot.currentPolicy,
    candidates: snapshot.candidates
  };
}
module.exports = { normalizeSnapshot, compactForPrompt, pairs };
