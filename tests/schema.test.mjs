// tests/schema.test.mjs — ajv-validate every rules/**/*.json against the
// authoritative pi-assert schema at ../pi-assert/schema.json.
//
// Each rule file is a FLAT object { assertName: assertDef, ... }, not the
// top-level .pi/asserts.json shape (which wraps asserts under local/repos/),
// so we validate each entry definition against schema.$defs.entry directly.
// The `$schema` key atop each rule file ("../pi-assert/schema.json") is the
// same pointer used here; it is skipped (not itself an assert).
//
// ajv is resolved from the sibling pi-assert checkout's node_modules (this
// rules repo has no JS deps of its own), retried from this repo's own
// node_modules. If ajv or the schema can't be found, the suite reports a
// skip and exits 0 so it never false-fails on a bare runner.

import { createRequire } from 'node:module';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const REPO_ROOT = process.argv[2] || resolve(here, '..');

const SCHEMA_PATH = resolve(here, '../../pi-assert/schema.json');
const require = createRequire(import.meta.url);

function loadAjv() {
  for (const root of [
    resolve(here, '../../pi-assert/node_modules'),
    resolve(REPO_ROOT, '../pi-assert/node_modules'),
    REPO_ROOT,
  ]) {
    try {
      const mod = require(require.resolve('ajv', { paths: [root] }));
      return mod.default || mod;
    } catch { /* try next */ }
  }
  return null;
}

function* walkRules(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) yield* walkRules(full);
    else if (entry.name.endsWith('.json')) yield full;
  }
}

const Ajv = loadAjv();
if (!Ajv) { console.log('  (ajv not resolvable — skipping schema validation)'); process.exit(0); }
if (!existsSync(SCHEMA_PATH)) {
  console.log(`  (schema not found at ${SCHEMA_PATH} — skipping schema validation)`);
  process.exit(0);
}

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
const validate = ajv_compile(schema.$defs.entry);

function ajv_compile(assertSchema) {
  const ajv = new Ajv({ allErrors: true, strict: false });
  return ajv.compile(assertSchema);
}

let failed = 0, checked = 0;
for (const file of walkRules(join(REPO_ROOT, 'rules'))) {
  const rel = file.slice(REPO_ROOT.length + 1);
  let doc;
  try { doc = JSON.parse(readFileSync(file, 'utf8')); }
  catch (e) { console.log(`  \u001b[31m\u2717\u001b[0m ${rel} (invalid JSON: ${e.message})`); failed++; continue; }
  for (const [name, def] of Object.entries(doc)) {
    if (name === '$schema') continue;
    checked++;
    if (!validate(def)) {
      console.log(`  \u001b[31m\u2717\u001b[0m ${rel}:${name}`);
      for (const err of validate.errors || []) console.log(`      at ${err.instancePath || '/'}: ${err.message}`);
      failed++;
    }
  }
}

if (failed === 0) console.log(`  \u001b[32m\u2713\u001b[0m ${checked} asserts valid across rules/`);
else console.log(`  ${checked} checked, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);