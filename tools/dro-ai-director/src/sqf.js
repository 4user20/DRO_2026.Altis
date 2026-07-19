'use strict';

class SqfParser {
  constructor(input) { this.input = String(input); this.i = 0; }
  skip() { while (this.i < this.input.length && /\s/.test(this.input[this.i])) this.i += 1; }
  parse() { this.skip(); const value = this.value(); this.skip(); if (this.i !== this.input.length) throw new Error(`Trailing SQF data at ${this.i}`); return value; }
  value() {
    this.skip(); const ch = this.input[this.i];
    if (ch === '[') return this.array();
    if (ch === '"') return this.string();
    if (ch === '-' || ch === '+' || /\d/.test(ch || '')) return this.number();
    return this.identifier();
  }
  array() {
    const out = []; this.i += 1; this.skip();
    if (this.input[this.i] === ']') { this.i += 1; return out; }
    while (this.i < this.input.length) {
      out.push(this.value()); this.skip(); const ch = this.input[this.i];
      if (ch === ',') { this.i += 1; continue; }
      if (ch === ']') { this.i += 1; return out; }
      throw new Error(`Expected ',' or ']' at ${this.i}`);
    }
    throw new Error('Unterminated SQF array');
  }
  string() {
    let out = ''; this.i += 1;
    while (this.i < this.input.length) {
      const ch = this.input[this.i];
      if (ch === '"') {
        if (this.input[this.i + 1] === '"') { out += '"'; this.i += 2; continue; }
        this.i += 1; return out;
      }
      out += ch; this.i += 1;
    }
    throw new Error('Unterminated SQF string');
  }
  number() {
    const start = this.i;
    while (this.i < this.input.length && /[0-9eE+\-.]/.test(this.input[this.i])) this.i += 1;
    const value = Number(this.input.slice(start, this.i));
    if (!Number.isFinite(value)) throw new Error(`Invalid SQF number at ${start}`);
    return value;
  }
  identifier() {
    const start = this.i;
    while (this.i < this.input.length && /[A-Za-z_]/.test(this.input[this.i])) this.i += 1;
    const token = this.input.slice(start, this.i).toLowerCase();
    if (token === 'true') return true;
    if (token === 'false') return false;
    if (['nil', 'objnull', 'grpnull'].includes(token)) return null;
    throw new Error(`Unknown SQF identifier '${token}' at ${start}`);
  }
}

function parseSqf(input) { return new SqfParser(input).parse(); }
function stringifySqf(value) {
  if (Array.isArray(value)) return `[${value.map(stringifySqf).join(',')}]`;
  if (typeof value === 'string') return `"${value.replaceAll('"', '""').replace(/[\r\n]/g, ' ')}"`;
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '0';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (value == null) return 'nil';
  throw new TypeError(`Unsupported SQF type: ${typeof value}`);
}
module.exports = { parseSqf, stringifySqf };
