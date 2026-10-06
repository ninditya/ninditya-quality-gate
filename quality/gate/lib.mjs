// Shared helpers for the quality gates. No dependencies: the gates must run on
// a bare Node install, in CI and on a laptop, with the same result.
import { execFileSync } from "node:child_process";
import { readFileSync, existsSync, appendFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

export const AC_FILE = "docs/specs/acceptance-criteria.md";
export const RISK_FILE = "quality/risk-register.json";
export const AC_ID = /AC-[A-Z]+-\d+/g;

export function read(rel, root = ROOT) {
  return readFileSync(path.join(root, rel), "utf8");
}

export function exists(rel, root = ROOT) {
  return existsSync(path.join(root, rel));
}

// Tracked files plus new, not-yet-committed ones, so a gate run on a laptop
// sees the same tree a commit would.
export function repoFiles(root = ROOT) {
  const out = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return out.split("\n").filter((f) => f && existsSync(path.join(root, f)));
}

export function isTestFile(file) {
  return (
    /^api\/spec\/.*_spec\.rb$/.test(file) ||
    /^web\/src\/.*\.test\.tsx?$/.test(file) ||
    /^quality\/gate\/.*\.test\.mjs$/.test(file)
  );
}

// Code whose behaviour reaches a user or the database. A change here needs its
// inputs; a change to docs, tests or tooling alone does not.
export function isRuntimeFile(file) {
  if (isTestFile(file)) return false;
  if (/^web\/src\/test\//.test(file)) return false;
  return (
    /^api\/(app|config|db|lib)\//.test(file) ||
    /^api\/(Gemfile|Gemfile\.lock|Dockerfile|Procfile|config\.ru)$/.test(file) ||
    /^api\/k8s\//.test(file) ||
    /^web\/(src|public)\//.test(file) ||
    /^web\/(package\.json|package-lock\.json|index\.html|vite\.config\.ts|vercel\.json)$/.test(file) ||
    /^contracts\/.*\.json$/.test(file)
  );
}

// Parses docs/specs/acceptance-criteria.md into { id: { title, source, status, risk } }.
export function parseCriteria(markdown) {
  const criteria = {};
  let current = null;
  for (const line of markdown.split("\n")) {
    const heading = line.match(/^### (AC-[A-Z]+-\d+) — (.+)$/);
    if (heading) {
      current = { id: heading[1], title: heading[2].trim(), source: "", status: "", risk: null, body: [] };
      criteria[current.id] = current;
      continue;
    }
    if (/^#{1,3} /.test(line)) {
      current = null;
      continue;
    }
    if (!current) continue;
    const source = line.match(/^- Source: (.+)$/);
    const status = line.match(/^- Status: (enforced|deferred)(?: \((R-\d+)\))?\s*$/);
    if (source) current.source = source[1].trim();
    else if (status) {
      current.status = status[1];
      current.risk = status[2] ?? null;
    } else if (line.trim()) current.body.push(line.trim());
  }
  return criteria;
}

// { "AC-FG-02": ["api/spec/...", "web/src/..."] } from the `[AC-…]` tags in tests.
export function testTags(files, root = ROOT) {
  const tags = {};
  for (const file of files.filter(isTestFile)) {
    const text = read(file, root);
    for (const match of text.matchAll(/\[([^\]]*AC-[A-Z]+-\d+[^\]]*)\]/g)) {
      for (const id of match[1].match(AC_ID) ?? []) {
        (tags[id] ??= new Set()).add(file);
      }
    }
  }
  return Object.fromEntries(Object.entries(tags).map(([id, set]) => [id, [...set].sort()]));
}

export function loadRisks(root = ROOT) {
  return JSON.parse(read(RISK_FILE, root)).risks;
}

// Shown on the workflow run page, so a blocked gate explains itself without logs.
export function summary(markdown) {
  const file = process.env.GITHUB_STEP_SUMMARY;
  if (!file) return;
  try {
    appendFileSync(file, markdown + "\n");
  } catch {
    /* the summary is a convenience; the exit code is the gate */
  }
}

export function report(title, problems, okMessage) {
  if (problems.length === 0) {
    console.log(`PASS  ${title}: ${okMessage}`);
    summary(`### ✅ ${title}\n${okMessage}`);
    return 0;
  }
  console.error(`BLOCKED  ${title}`);
  for (const p of problems) console.error(`  - ${p}`);
  summary(`### ⛔ ${title}\n${problems.map((p) => `- ${p}`).join("\n")}`);
  return 1;
}
