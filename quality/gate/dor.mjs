#!/usr/bin/env node
// Definition of Ready / Done for a pull request (gate G2).
//
// A change that touches runtime code cannot merge without its inputs:
//   1. a spec it implements            (Spec: docs/specs/...)
//   2. acceptance criteria it satisfies (AC ids that exist in the criteria file)
//   3. a short design plan
//   4. tests: the PR changes a test, and every cited criterion has a tagged test
// and it cannot weaken the net on the quiet (deleted or skipped checks).
//
// Whether a change is "runtime" is decided from the diff, not from a checkbox,
// so nobody can tick their way out of the gate. Docs- and tooling-only changes
// pass without ceremony.
//
//   PR_BODY="$(cat body.md)" node quality/gate/dor.mjs --base origin/main --head HEAD
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { ROOT, AC_FILE, AC_ID, read, exists, repoFiles, parseCriteria, testTags, isRuntimeFile, isTestFile, report } from "./lib.mjs";

// A check switched off in place: RSpec's xit/fit/skip/pending at the start of a
// statement, or Vitest's .skip/.only/.todo. Anchored so that the words "fit" or
// "skip" inside a test name or URL are not mistaken for it.
const SKIP_MARKER =
  /^\+\s*(?:(?:xit|xdescribe|xcontext|fit|fdescribe|fcontext|skip|pending)\b(?=[\s(]|$)|.*\b(?:it|test|describe)\.(?:skip|only|todo)\s*\()/gm;

const PLACEHOLDER = /^(|n\/?a|none|tbd|todo|-|–|—|\.+|<[^>]*>)$/i;

// Text under a "## Heading" (or after a "Heading:" label), with HTML comments removed.
export function section(body, name) {
  const clean = body.replace(/<!--[\s\S]*?-->/g, "");
  const heading = new RegExp(`^#{2,3}\\s*${name}\\s*$([\\s\\S]*?)(?=^#{2,3}\\s|(?![\\s\\S]))`, "im");
  const inline = new RegExp(`^\\**${name}\\**\\s*:\\s*(.*)$`, "im");
  const found = clean.match(heading)?.[1] ?? clean.match(inline)?.[1] ?? "";
  return found.trim();
}

const meaningful = (text) => text.split("\n").map((l) => l.replace(/^[-*\s]+/, "").trim()).filter((l) => !PLACEHOLDER.test(l)).join(" ");

export function checkPullRequest({ body, changed, deleted = [], addedLines = "", criteria, tags, fileExists }) {
  const problems = [];
  const runtime = changed.filter(isRuntimeFile);
  const tests = changed.filter(isTestFile);

  // The net may change, but never silently.
  const netChange = meaningful(section(body, "Net change"));
  const removedTests = deleted.filter(isTestFile);
  const skipMarkers = addedLines.match(SKIP_MARKER) ?? [];
  if ((removedTests.length || skipMarkers.length) && !netChange) {
    if (removedTests.length) problems.push(`removes checks (${removedTests.join(", ")}) without a "Net change" section saying why`);
    if (skipMarkers.length) problems.push(`adds skipped or focused tests (${skipMarkers.length}) without a "Net change" section saying why`);
  }

  if (runtime.length === 0) return { problems, runtime, kind: "non-runtime" };

  const where = `${runtime.length} runtime file(s) changed, e.g. ${runtime.slice(0, 3).join(", ")}`;

  // 1. Spec
  const spec = section(body, "Spec");
  const specPaths = [...spec.matchAll(/docs\/specs\/[\w./-]+/g)].map((m) => m[0].replace(/[.,)]+$/, ""));
  if (specPaths.length === 0) problems.push(`no spec linked: add "Spec: docs/specs/<file>" (${where})`);
  for (const p of specPaths) if (!fileExists(p)) problems.push(`linked spec does not exist: ${p}`);

  // 2. Acceptance criteria
  const cited = [...new Set(section(body, "Acceptance criteria").match(AC_ID) ?? [])];
  if (cited.length === 0) problems.push(`no acceptance criteria cited: list the AC ids from ${AC_FILE} this change satisfies`);
  for (const id of cited) {
    if (!criteria[id]) problems.push(`${id} is not defined in ${AC_FILE}`);
    else if (criteria[id].status !== "enforced") problems.push(`${id} is ${criteria[id].status || "unspecified"}: a change that implements it must mark it enforced`);
  }

  // 3. Design plan
  if (meaningful(section(body, "Design plan")).length < 60) {
    problems.push("no design plan: say in a few lines what changes where, what data it touches, and how to roll it back");
  }

  // 4. Tests
  if (tests.length === 0) problems.push("runtime code changed but no test changed with it");
  for (const id of cited) {
    if (criteria[id] && !tags[id]) problems.push(`${id} is cited but no test is tagged [${id}]`);
  }

  return { problems, runtime, cited, kind: "runtime" };
}

function git(args) {
  return execFileSync("git", args, { cwd: ROOT, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const arg = (name, fallback) => {
    const i = process.argv.indexOf(name);
    return i > -1 ? process.argv[i + 1] : fallback;
  };
  const base = arg("--base", "origin/main");
  const head = arg("--head", "HEAD");
  const range = `${base}...${head}`;
  const names = (filter) => git(["diff", "--name-only", `--diff-filter=${filter}`, range]).split("\n").filter(Boolean);

  const result = checkPullRequest({
    body: process.env.PR_BODY ?? "",
    changed: names("ACMRT"),
    deleted: names("D"),
    addedLines: git(["diff", "--unified=0", range, "--", "api/spec", "web/src"]),
    criteria: parseCriteria(read(AC_FILE)),
    tags: testTags(repoFiles()),
    fileExists: exists,
  });

  const ok = result.kind === "runtime"
    ? `spec, criteria (${result.cited.join(", ")}), design plan and tests are present`
    : "no runtime code changed; inputs are not required";
  process.exit(report("Definition of Ready", result.problems, ok));
}
