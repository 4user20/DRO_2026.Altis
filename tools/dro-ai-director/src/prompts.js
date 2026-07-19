'use strict';
const TACTICAL_SCHEMA = {
  schema: 1,
  snapshotSequence: 42,
  selectedCandidateId: 'CAND_42_1',
  decision: 'EXECUTE',
  delaySeconds: 8,
  tempoModifier: 1.0,
  actionModifiers: {salvoCount: 1, relocateAfter: false, searchRadius: 900, holdSeconds: 0},
  reasonCode: 'EXPLOIT_FRESH_CONTACT'
};
const STRATEGIC_SCHEMA = {
  schema: 1,
  snapshotSequence: 42,
  doctrine: 'DRONE_HEAVY',
  desiredTempo: 0.55,
  reconPressure: 0.6,
  strikePressure: 0.5,
  reserveCommitment: 0.45,
  logisticsPriority: 0.65,
  recoveryBias: 0.5,
  pauseAfterMajorAttack: 75,
  priorities: ['PROTECT_LOGISTICS'],
  reasonCode: 'PRESERVE_NETWORK_AND_REGAIN_CONTACT'
};
function system(jobType) {
  if (jobType === 'STRATEGIC_POLICY') return `You are the operational staff planner for an Arma 3 scenario. You receive a compact, incomplete belief-state. Return only strict JSON matching the requested schema. Never invent entity IDs, coordinates, classnames, game commands or SQF. You set bounded policy values only. Preserve reserves, account for contacts uncertainty, BDA, stocks, civilian risk, network health and server FPS. The goal is plausible adaptive opposition, not maximum lethality.`;
  return `You are a bounded tactical intent ranker for an Arma 3 operational simulation. Return only strict JSON. Select only a candidate ID present in candidates, or choose HOLD/USE_DETERMINISTIC. Never invent actions, actors, contacts, coordinates, classnames, SQF or orders. Treat contacts as uncertain beliefs. Respect stocks, BDA, cooldown constraints, civilian risk, recent repeated attacks and server FPS. HOLD is valid. Do not provide chain-of-thought; use a short reasonCode.`;
}
function user(jobType, snapshot, memory) {
  const shape = jobType === 'STRATEGIC_POLICY' ? STRATEGIC_SCHEMA : TACTICAL_SCHEMA;
  return `Required output example/shape (values are illustrative):\n${JSON.stringify(shape)}\n\nRecent bounded memory:\n${JSON.stringify(memory)}\n\nCurrent state:\n${JSON.stringify(snapshot)}`;
}
module.exports = { system, user, TACTICAL_SCHEMA, STRATEGIC_SCHEMA };
