'use strict';
const path = require('node:path');
const { loadConfig, redacted } = require('./config');
const { IniTransport } = require('./transport');
const { normalizeSnapshot, compactForPrompt } = require('./snapshot');
const { callModel } = require('./provider');
const { validateTactical, validateStrategic, toSqfDecision, toSqfPolicy } = require('./validate');
const { DirectorMemory } = require('./memory');
const { appendAudit } = require('./audit');

const VERSION = '0.1.0';
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const stamp = () => new Date().toISOString();

async function main() {
  const root = path.resolve(__dirname, '..');
  const config = loadConfig(root);
  if (!config.iniFolder) throw new Error('INIDBI2 db folder not found. Set iniFolder or DROAI_INI_FOLDER.');
  const transport = new IniTransport(config.iniFolder, console);
  const memory = new DirectorMemory();
  const queue = [];
  const known = new Set();
  let running = false;
  let lastHeartbeat = 0;
  let consecutiveFailures = 0;
  let circuitOpenUntil = 0;

  transport.ensureFiles();
  console.log(`[${stamp()}] DRO2026 AI Director ${VERSION}`);
  console.log(`[config] mode=${config.mode} ini=${config.iniFolder} mock=${config.mock}`);
  for (const [name, profile] of Object.entries(config.profiles)) console.log(`[provider:${name}] ${JSON.stringify(redacted(profile))}`);

  function sendStatus() {
    transport.send('bridge-config', [config.mode, VERSION, circuitOpenUntil > Date.now(), Math.max(0, Math.round((circuitOpenUntil - Date.now()) / 1000))]);
  }
  function enqueue(entry, snapshot) {
    const key = `${snapshot.missionId}:${snapshot.jobType}:${snapshot.sequence}`;
    if (known.has(key)) return false;
    known.add(key);
    if (known.size > 2000) known.clear();
    if (snapshot.jobType === 'TACTICAL_INTENT') {
      for (let i = queue.length - 1; i >= 0; i -= 1) {
        if (queue[i].snapshot.jobType === 'TACTICAL_INTENT' && queue[i].snapshot.missionId === snapshot.missionId) queue.splice(i, 1);
      }
    }
    while (queue.length >= config.maxQueue) queue.shift();
    queue.push({entryId:entry.id, snapshot, receivedAt:Date.now()});
    return true;
  }
  async function runOne(job) {
    const snapshot = job.snapshot;
    const promptSnapshot = compactForPrompt(snapshot);
    const profile = snapshot.jobType === 'STRATEGIC_POLICY' ? 'strategic' : 'tactical';
    const started = Date.now();
    try {
      if (config.mode === 'OFF') throw new Error('AI_MODE_OFF');
      if (Date.now() < circuitOpenUntil) throw new Error('CIRCUIT_OPEN');
      const response = await callModel(config, profile, snapshot.jobType, promptSnapshot, memory.view());
      const result = snapshot.jobType === 'STRATEGIC_POLICY' ? validateStrategic(response.result, promptSnapshot) : validateTactical(response.result, promptSnapshot);
      const meta = {latencyMs:Date.now()-started,provider:response.provider,model:response.model,attempts:response.attempts,fallbackUsed:response.provider !== profile};
      transport.send(snapshot.jobType === 'STRATEGIC_POLICY' ? 'strategic-policy' : 'decision', snapshot.jobType === 'STRATEGIC_POLICY' ? toSqfPolicy(result,meta) : toSqfDecision(result,meta));
      memory.recordDecision(promptSnapshot,result,meta); memory.ingestEvents(snapshot.recentEvents);
      consecutiveFailures = 0;
      appendAudit(root,{type:'decision',status:'ACCEPTED',mode:config.mode,jobType:snapshot.jobType,missionId:snapshot.missionId,snapshotSequence:snapshot.sequence,...meta,result});
      console.log(`[${stamp()}] accepted ${snapshot.jobType} seq=${snapshot.sequence} provider=${meta.provider} ${meta.latencyMs}ms`);
    } catch (error) {
      const code = String(error.message || error).slice(0,240);
      if (!['AI_MODE_OFF','CIRCUIT_OPEN'].includes(code)) consecutiveFailures += 1;
      if (consecutiveFailures >= config.maxConsecutiveFailures) {
        circuitOpenUntil = Date.now() + config.circuitOpenSeconds * 1000;
        consecutiveFailures = 0;
      }
      transport.send('decision-error',[snapshot.jobType,snapshot.sequence,code,Date.now()-started,Math.max(0,Math.round((circuitOpenUntil-Date.now())/1000))]);
      appendAudit(root,{type:'decision',status:'REJECTED',mode:config.mode,jobType:snapshot.jobType,missionId:snapshot.missionId,snapshotSequence:snapshot.sequence,latencyMs:Date.now()-started,errorCode:code});
      console.error(`[${stamp()}] ${snapshot.jobType} seq=${snapshot.sequence} failed: ${code}`);
    }
  }
  async function drain() {
    if (running || queue.length === 0) return;
    running = true;
    const job = queue.shift();
    try { await runOne(job); } finally { running = false; }
  }

  sendStatus(); transport.send('ping',[Date.now(),VERSION]);
  while (true) {
    const entries = transport.readOutgoing(); const ack = [];
    for (const entry of entries) {
      try {
        if (entry.type === 'snapshot') {
          const snapshot = normalizeSnapshot(entry.data);
          enqueue(entry,snapshot);
        } else if (entry.type === 'operation-events') {
          memory.ingestEvents(entry.data); appendAudit(root,{type:'operation-events',data:entry.data});
        } else if (entry.type === 'pong') {
          appendAudit(root,{type:'pong',data:entry.data});
        }
        ack.push(entry.id);
      } catch (error) {
        console.error(`[transport] ${entry.id}: ${error.message}`);
        appendAudit(root,{type:'transport-error',entryId:entry.id,error:error.message});
        ack.push(entry.id);
      }
    }
    transport.acknowledge(ack);
    void drain();
    if (Date.now() - lastHeartbeat >= config.heartbeatMs) { sendStatus(); transport.send('ping',[Date.now(),VERSION]); lastHeartbeat=Date.now(); }
    await sleep(config.pollIntervalMs);
  }
}
main().catch((error)=>{ console.error(`Fatal: ${error.stack || error.message}`); process.exitCode=1; });
