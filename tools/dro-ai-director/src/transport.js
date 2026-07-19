'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { parseSqf, stringifySqf } = require('./sqf');

class IniTransport {
  constructor(folder, logger = console) {
    this.folder = folder; this.logger = logger;
    this.inFile = path.join(folder, 'DROAI_in.ini');
    this.outFile = path.join(folder, 'DROAI_out.ini');
    this.writeSeq = 0; this.acked = new Set(); this.inFlight = new Set(); this.order = [];
  }
  ensureFiles() {
    fs.mkdirSync(this.folder, {recursive: true});
    for (const [file, section] of [[this.inFile,'DROAI_in'],[this.outFile,'DROAI_out']]) {
      if (!fs.existsSync(file)) fs.writeFileSync(file, `[${section}]\r\n`, 'utf8');
    }
  }
  readOutgoing() {
    this.ensureFiles(); const entries = [];
    for (const line of fs.readFileSync(this.outFile, 'utf8').split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('[') || trimmed.startsWith(';') || trimmed.startsWith('#')) continue;
      const idx = line.indexOf('='); if (idx < 0) continue;
      const id = line.slice(0, idx).trim();
      if (!id || this.acked.has(id) || this.inFlight.has(id)) continue;
      try {
        const value = parseSqf(line.slice(idx + 1).trim());
        if (!Array.isArray(value) || value.length < 2) throw new Error('entry must be [type,data]');
        this.inFlight.add(id); entries.push({id, type: String(value[0]), data: value[1]});
      } catch (error) { this.logger.warn(`[transport] ${id}: ${error.message}`); }
    }
    return entries;
  }
  release(ids) { for (const id of ids || []) this.inFlight.delete(id); }
  acknowledge(ids) {
    const clean = [...new Set((ids || []).filter(Boolean))];
    if (!clean.length) return;
    for (const id of clean) {
      this.inFlight.delete(id); this.acked.add(id); this.order.push(id);
    }
    while (this.order.length > 5000) this.acked.delete(this.order.shift());
    this.send('ack-out', clean);
  }
  send(type, data) {
    this.ensureFiles(); this.writeSeq += 1;
    const id = `${Date.now()}_${process.pid}_${this.writeSeq}`;
    fs.appendFileSync(this.inFile, `${id} = ${stringifySqf([type, data])}\r\n`, 'utf8');
    return id;
  }
}
module.exports = { IniTransport };
