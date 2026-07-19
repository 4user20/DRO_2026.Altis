'use strict';
const fs = require('node:fs');
const path = require('node:path');

function parseCfg(text) {
  const out = {};
  for (const raw of String(text).replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith(';') || line.startsWith('[')) continue;
    const idx = line.indexOf('='); if (idx < 0) continue;
    out[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  }
  return out;
}
function int(value, fallback, min, max) { const n = Number.parseInt(value, 10); return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback; }
function num(value, fallback, min, max) { const n = Number(value); return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback; }
function bool(value, fallback) { return value == null || value === '' ? fallback : ['1','true','yes','on'].includes(String(value).toLowerCase()); }
function json(value, fallback = {}) { try { const out = JSON.parse(value || '{}'); return out && typeof out === 'object' && !Array.isArray(out) ? out : fallback; } catch { return fallback; } }
function discoverIniFolder(root, configured) {
  if (configured && configured.toLowerCase() !== 'auto') return path.resolve(root, configured);
  const candidates = [
    process.env.DROAI_INI_FOLDER,
    path.join(root, '..', '@INIDBI2', 'db'),
    path.join(root, '..', '..', '@INIDBI2', 'db'),
    path.join(root, '..', 'db'), path.join(root, '..', '..', 'db')
  ].filter(Boolean).map((p) => path.resolve(p));
  return candidates.find((p) => fs.existsSync(p) && fs.statSync(p).isDirectory()) || null;
}
function provider(raw, name) {
  const cap = name[0].toUpperCase() + name.slice(1);
  const envPrefix = `DROAI_${name.toUpperCase()}_`;
  const key = raw[`${name}ApiKey`] && raw[`${name}ApiKey`] !== 'PUT_KEY_HERE' ? raw[`${name}ApiKey`] : '';
  return {
    name,
    baseUrl: (process.env[`${envPrefix}BASE_URL`] || raw[`${name}BaseUrl`] || '').replace(/\/+$/, ''),
    apiKey: process.env[`${envPrefix}API_KEY`] || key,
    model: process.env[`${envPrefix}MODEL`] || raw[`${name}Model`] || '',
    timeoutMs: int(process.env[`${envPrefix}TIMEOUT_MS`] || raw[`${name}TimeoutMs`], name === 'strategic' ? 60000 : 20000, 3000, 180000),
    retries: int(process.env[`${envPrefix}RETRIES`] || raw[`${name}Retries`], 1, 0, 4),
    maxTokens: int(process.env[`${envPrefix}MAX_TOKENS`] || raw[`${name}MaxTokens`], name === 'strategic' ? 1400 : 500, 64, 4096),
    temperature: num(process.env[`${envPrefix}TEMPERATURE`] || raw[`${name}Temperature`], 0.2, 0, 1.5),
    extraBody: json(process.env[`${envPrefix}EXTRA_BODY`] || raw[`${name}ExtraBody`], {}),
    label: cap
  };
}
function loadConfig(rootDir) {
  const cfgPath = path.join(rootDir, 'DROAI-config.cfg');
  if (!fs.existsSync(cfgPath)) throw new Error(`Missing ${cfgPath}; copy DROAI-config.example.cfg first`);
  const raw = parseCfg(fs.readFileSync(cfgPath, 'utf8'));
  const mode = String(process.env.DROAI_MODE || raw.mode || 'OBSERVE').toUpperCase();
  if (!['OFF','OBSERVE','HYBRID'].includes(mode)) throw new Error(`Invalid mode ${mode}`);
  return {
    rootDir, cfgPath, mode,
    iniFolder: discoverIniFolder(rootDir, raw.iniFolder || 'auto'),
    pollIntervalMs: int(raw.pollIntervalMs, 200, 50, 2000),
    heartbeatMs: int(raw.heartbeatMs, 10000, 1000, 60000),
    maxQueue: int(raw.maxQueue, 8, 1, 64),
    maxSnapshotAgeSeconds: int(raw.maxSnapshotAgeSeconds, 150, 15, 1800),
    maxConsecutiveFailures: int(raw.maxConsecutiveFailures, 3, 1, 20),
    circuitOpenSeconds: int(raw.circuitOpenSeconds, 300, 30, 3600),
    fallbackProfile: raw.fallbackProfile || 'narrative',
    mock: bool(process.env.DROAI_MOCK ?? raw.mock, false),
    profiles: {
      tactical: provider(raw, 'tactical'),
      strategic: provider(raw, 'strategic'),
      narrative: provider(raw, 'narrative')
    }
  };
}
function redacted(profile) { return {...profile, apiKey: profile.apiKey ? 'present/redacted' : 'missing'}; }
module.exports = { loadConfig, parseCfg, discoverIniFolder, redacted };
