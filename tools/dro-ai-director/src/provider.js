'use strict';
const { system, user } = require('./prompts');
function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
function extractJson(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) return value;
  let text = String(value ?? '').trim();
  if (text.startsWith('```')) text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  const first = text.indexOf('{'); const last = text.lastIndexOf('}');
  if (first >= 0 && last > first) text = text.slice(first, last + 1);
  return JSON.parse(text);
}
function mockResult(jobType, snapshot) {
  if (jobType === 'STRATEGIC_POLICY') return {
    schema:1, snapshotSequence:snapshot.snapshotSequence, doctrine:snapshot.operation.doctrine || 'DRONE_HEAVY',
    desiredTempo:0.52, reconPressure:0.62, strikePressure:0.48, reserveCommitment:0.44,
    logisticsPriority:0.66, recoveryBias:0.5, pauseAfterMajorAttack:70,
    priorities:['PROTECT_LOGISTICS','IMPROVE_CONTACT_QUALITY'], reasonCode:'MOCK_BALANCED_POLICY'
  };
  const candidate = snapshot.candidates?.[0];
  return {schema:1, snapshotSequence:snapshot.snapshotSequence, selectedCandidateId:candidate?.id || '', decision:candidate?'EXECUTE':'USE_DETERMINISTIC', delaySeconds:5, tempoModifier:1, actionModifiers:{salvoCount:1,relocateAfter:false,searchRadius:900,holdSeconds:0}, reasonCode:'MOCK_TOP_VALID_CANDIDATE'};
}
async function callOnce(profile, jobType, snapshot, memory, timeoutMs) {
  const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const body = {
      model: profile.model,
      messages: [{role:'system',content:system(jobType)},{role:'user',content:user(jobType,snapshot,memory)}],
      temperature: profile.temperature,
      max_tokens: profile.maxTokens,
      response_format: {type:'json_object'},
      ...profile.extraBody
    };
    const response = await fetch(`${profile.baseUrl}/chat/completions`, {
      method:'POST', signal:controller.signal,
      headers:{'content-type':'application/json','authorization':`Bearer ${profile.apiKey}`},
      body:JSON.stringify(body)
    });
    const rawText = await response.text();
    if (!response.ok) throw new Error(`HTTP_${response.status}: ${rawText.slice(0,300)}`);
    const payload = JSON.parse(rawText);
    const content = payload?.choices?.[0]?.message?.content ?? payload?.choices?.[0]?.text;
    if (content == null) throw new Error('Provider response has no choices[0].message.content');
    return extractJson(content);
  } finally { clearTimeout(timer); }
}
async function callModel(config, profileName, jobType, snapshot, memory) {
  if (config.mock) return {result:mockResult(jobType,snapshot), provider:'mock', model:'mock', attempts:1};
  const names = [profileName]; if (config.fallbackProfile && config.fallbackProfile !== profileName) names.push(config.fallbackProfile);
  let lastError;
  for (const name of names) {
    const profile = config.profiles[name];
    if (!profile?.baseUrl || !profile?.apiKey || !profile?.model) { lastError = new Error(`Provider profile ${name} is incomplete`); continue; }
    for (let attempt = 0; attempt <= profile.retries; attempt += 1) {
      try {
        const result = await callOnce(profile, jobType, snapshot, memory, profile.timeoutMs);
        return {result, provider:name, model:profile.model, attempts:attempt+1};
      } catch (error) {
        lastError = error;
        if (attempt < profile.retries) await sleep(350 * (attempt + 1));
      }
    }
  }
  throw lastError || new Error('No configured provider available');
}
module.exports = { callModel, extractJson, mockResult };
