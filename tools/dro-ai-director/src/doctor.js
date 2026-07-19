'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { loadConfig, redacted } = require('./config');
const { IniTransport } = require('./transport');
async function main() {
  const root = path.resolve(__dirname,'..'); const checks=[]; let cfg;
  checks.push(['Node >= 20',Number(process.versions.node.split('.')[0])>=20,process.versions.node]);
  try { cfg=loadConfig(root); checks.push(['Config valid',true,cfg.cfgPath]); } catch(error) { checks.push(['Config valid',false,error.message]); }
  if (cfg) {
    checks.push(['INIDBI folder found',Boolean(cfg.iniFolder),cfg.iniFolder || 'not found']);
    if (cfg.iniFolder) { try { new IniTransport(cfg.iniFolder).ensureFiles(); checks.push(['Transport writable',true,cfg.iniFolder]); } catch(error) { checks.push(['Transport writable',false,error.message]); } }
    for (const [name,p] of Object.entries(cfg.profiles)) checks.push([`${name} profile configured`,cfg.mock || Boolean(p.baseUrl && p.apiKey && p.model),`${cfg.mock ? 'mock mode; ' : ''}${JSON.stringify(redacted(p))}`]);
    checks.push(['Config file excludes obvious secret from output',!fs.readFileSync(cfg.cfgPath,'utf8').includes('Authorization: Bearer'),'redaction check']);
  }
  for (const [name,ok,detail] of checks) console.log(`${ok?'OK ':'ERR'} ${name}: ${detail}`);
  if (checks.some(([,ok])=>!ok)) process.exitCode=1;
}
main().catch((error)=>{console.error(error);process.exitCode=1;});
