'use strict';
class DirectorMemory {
  constructor() { this.decisions = []; this.events = []; }
  recordDecision(snapshot, result, meta = {}) {
    this.decisions.push({sequence: snapshot.sequence, at: snapshot.generatedAt, selectedCandidateId: result.selectedCandidateId || '', decision: result.decision, reasonCode: result.reasonCode || '', ...meta});
    if (this.decisions.length > 24) this.decisions.splice(0, this.decisions.length - 24);
  }
  ingestEvents(events) {
    for (const event of Array.isArray(events) ? events : []) this.events.push(event);
    if (this.events.length > 100) this.events.splice(0, this.events.length - 100);
  }
  view() { return {recentDecisions: this.decisions.slice(-8), recentEvents: this.events.slice(-30)}; }
}
module.exports = { DirectorMemory };
