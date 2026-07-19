'use strict';
const fs = require('node:fs');
const path = require('node:path');
function appendAudit(root, event) {
  const dir = path.join(root, 'logs'); fs.mkdirSync(dir, {recursive: true});
  fs.appendFileSync(path.join(dir, 'decisions.ndjson'), `${JSON.stringify({timestamp: new Date().toISOString(), ...event})}\n`, 'utf8');
}
module.exports = { appendAudit };
