// Tests for the gates themselves. A gate nobody tests is a gate nobody trusts:
// each rule is shown blocking the thing it exists to block, and letting a
// well-formed change through.
//
//   node --test quality/gate/gate.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { ROOT, read, exists, parseCriteria } from "./lib.mjs";
import { checkPullRequest, section } from "./dor.mjs";
import { checkTraceability } from "./traceability.mjs";
import { checkRelease, notesFor, renderStatus } from "./release.mjs";
import { forbiddenIn, DENYLIST } from "./confidentiality.mjs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

const criteria = parseCriteria(`
### AC-FG-02 — Unrated skill is not assessed
- Source: PRD-02 Phase 5
- Status: enforced
- Given … When … Then …

### AC-INV-02 — Invite links expire
- Source: Derived
- Status: deferred (R-17)
`);
const tags = { "AC-FG-02": ["api/spec/requests/fit_gap_spec.rb"] };
const fileExists = (p) => p === "docs/specs/acceptance-criteria.md";

const readyBody = `
## Spec
docs/specs/acceptance-criteria.md (Fit/gap)

## Acceptance criteria
AC-FG-02

## Design plan
Engine returns not_assessed when the candidate level is null; the table renders
a dash. No migration. Roll back by reverting this commit.
`;

const pr = (overrides) =>
  checkPullRequest({
    body: readyBody,
    changed: ["api/app/services/fit_gap/engine.rb", "api/spec/requests/fit_gap_spec.rb"],
    criteria,
    tags,
    fileExists,
    ...overrides,
  });

test("DoR passes a runtime change that carries spec, criteria, design plan and tests", () => {
  assert.deepEqual(pr().problems, []);
});

test("DoR blocks a runtime change with no linked spec or acceptance criteria", () => {
  const { problems } = pr({ body: "Quick fix, trust me." });
  assert.ok(problems.some((p) => p.includes("no spec linked")));
  assert.ok(problems.some((p) => p.includes("no acceptance criteria cited")));
  assert.ok(problems.some((p) => p.includes("no design plan")));
});

test("DoR blocks a runtime change that changes no test", () => {
  const { problems } = pr({ changed: ["api/app/services/fit_gap/engine.rb"] });
  assert.deepEqual(problems, ["runtime code changed but no test changed with it"]);
});

test("DoR blocks an untouched PR template (placeholders are not inputs)", () => {
  const template = read(".github/pull_request_template.md");
  const { problems } = pr({ body: template });
  assert.ok(problems.length >= 3, problems.join("\n"));
});

test("DoR blocks criteria that do not exist, are deferred, or have no test", () => {
  const body = readyBody.replace("AC-FG-02", "AC-FG-02, AC-INV-02, AC-XX-99");
  const { problems } = pr({ body });
  assert.ok(problems.some((p) => p.includes("AC-XX-99 is not defined")));
  assert.ok(problems.some((p) => p.includes("AC-INV-02 is deferred")));
  const untested = pr({ tags: {} }).problems;
  assert.ok(untested.some((p) => p.includes("no test is tagged [AC-FG-02]")));
});

test("DoR blocks a linked spec that does not exist", () => {
  const { problems } = pr({ body: readyBody.replace("acceptance-criteria.md", "ghost-spec.md") });
  assert.ok(problems.some((p) => p.includes("linked spec does not exist")));
});

test("DoR lets docs- and tooling-only changes through without ceremony", () => {
  const { problems, kind } = pr({ body: "", changed: ["assessment/01-audit.md", ".github/workflows/ci.yml"] });
  assert.equal(kind, "non-runtime");
  assert.deepEqual(problems, []);
});

test("DoR decides 'runtime' from the diff, not from what the description claims", () => {
  const { problems } = pr({ body: "## Change type\nchore, docs only", changed: ["web/src/pages/auth/LoginPage.tsx"] });
  assert.ok(problems.length > 0);
});

test("DoR blocks weakening the net silently: deleted or skipped checks need a stated reason", () => {
  const deleted = pr({ deleted: ["api/spec/requests/fit_gap_spec.rb"] }).problems;
  assert.ok(deleted.some((p) => p.includes("removes checks")));

  const skipped = pr({ addedLines: "+  xit 'reports an unrated skill as not assessed' do\n+    it.skip('x')" }).problems;
  assert.ok(skipped.some((p) => p.includes("skipped or focused")));

  const innocent = pr({ addedLines: "+  it 'serves the fit/gap report' do\n+    post \"/portfolios/1/fitgap\"\n+  # we skip nothing here" }).problems;
  assert.deepEqual(innocent, []);

  const stated = pr({
    deleted: ["api/spec/requests/fit_gap_spec.rb"],
    body: readyBody + "\n## Net change\nMoved into fit_gap_engine_spec.rb; same assertions.\n",
  }).problems;
  assert.deepEqual(stated, []);
});

test("section() ignores HTML comments, so template hints never count as content", () => {
  assert.equal(section("## Spec\n<!-- link the spec -->\n\n## Next\nx", "Spec"), "");
});

test("traceability blocks an enforced criterion with no test, and a test tag with no criterion", () => {
  const risks = [{ id: "R-17", status: "open", acs: ["AC-INV-02"] }];
  assert.deepEqual(checkTraceability({ criteria, tags, risks }), []);
  assert.ok(checkTraceability({ criteria, tags: {}, risks })[0].includes("AC-FG-02 is enforced but no test"));
  const orphan = checkTraceability({ criteria, tags: { ...tags, "AC-ZZ-01": ["web/src/x.test.ts"] }, risks });
  assert.ok(orphan.some((p) => p.includes("AC-ZZ-01")));
});

test("traceability blocks 'deferred' without an open risk, and 'fixed' without proof", () => {
  assert.ok(checkTraceability({ criteria, tags, risks: [] }).some((p) => p.includes("AC-INV-02 is deferred without")));
  const unproven = [{ id: "R-17", status: "open", acs: ["AC-INV-02"] }, { id: "R-99", status: "fixed", acs: [] }];
  assert.ok(checkTraceability({ criteria, tags, risks: unproven }).some((p) => p.includes("R-99 is marked fixed")));
});

const notes = "# Release notes\n\n## v1.0.0 — 2026-01-01\nDelivers X. Known risks: R-13.\n\n## v0.9.0\nOld.\n";
const fixed = { id: "R-01", severity: "P0", title: "boot", status: "fixed" };
const openP2 = { id: "R-13", severity: "P2", title: "quotes", status: "open", owner: "Product owner" };
const release = (overrides) =>
  checkRelease({ tag: "v1.0.0", net: "success", notes, risks: [fixed, openP2], traceability: [], today: "2026-06-01", ...overrides });

test("release is RELEASABLE when the net is green and only disclosed, owned P2/P3 risks remain", () => {
  const result = release();
  assert.equal(result.releasable, true, result.blockers.join("\n"));
  assert.match(renderStatus(result), /v1\.0\.0 is RELEASABLE/);
});

test("release is BLOCKED by any open P0 or P1", () => {
  const result = release({ risks: [fixed, openP2, { id: "R-12", severity: "P1", title: "no live evidence", status: "open", owner: "x" }], notes: notes.replace("R-13", "R-13, R-12") });
  assert.equal(result.releasable, false);
  assert.ok(result.blockers.some((b) => b.includes("R-12") && b.includes("open P1")));
  assert.match(renderStatus(result), /v1\.0\.0 is BLOCKED/);
});

test("release is BLOCKED when the quality net is red or did not run", () => {
  assert.equal(release({ net: "failure" }).releasable, false);
  assert.equal(release({ net: undefined }).releasable, false);
});

test("release is BLOCKED without release notes for the exact version", () => {
  assert.equal(release({ tag: "v1.1.0" }).releasable, false);
  assert.equal(release({ notes: null }).releasable, false);
  assert.equal(notesFor(notes, "v1.0.0").includes("Old."), false);
});

test("release is BLOCKED when an unfixed risk is not disclosed in the release notes", () => {
  const result = release({ notes: "## v1.0.0\nDelivers X.\n" });
  assert.ok(result.blockers.some((b) => b.includes("R-13") && b.includes("not disclosed")));
});

test("an accepted P1 ships only with owner, mitigation, approver and an unexpired date", () => {
  const accepted = { id: "R-12", severity: "P1", title: "no live evidence", status: "accepted", owner: "QA", mitigation: "UAT run", accepted_by: "CTO", expires: "2026-12-31" };
  const withNotes = { notes: notes.replace("R-13", "R-13, R-12") };
  assert.equal(release({ ...withNotes, risks: [openP2, accepted] }).releasable, true);
  assert.equal(release({ ...withNotes, risks: [openP2, { ...accepted, accepted_by: "" }] }).releasable, false);
  assert.equal(release({ ...withNotes, risks: [openP2, { ...accepted, expires: "2026-01-31" }] }).releasable, false);
});

test("release is BLOCKED by a traceability gap and by a malformed tag", () => {
  assert.equal(release({ traceability: ["AC-FG-02 is enforced but no test"] }).releasable, false);
  assert.equal(release({ tag: "latest" }).releasable, false);
});

test("confidentiality guard finds a forbidden word, also inside a longer identifier", () => {
  const sha256 = createHash("sha256").update("acmecorp").digest("hex");
  const denylist = [{ length: 8, sha256 }];
  assert.deepEqual(forbiddenIn("deploy to AcmeCorp-prod", denylist), [0]);
  assert.deepEqual(forbiddenIn("DB_NAME=acmecorp_development", denylist), [0]);
  assert.deepEqual(forbiddenIn("image: registry/acmecorpdev/api", denylist), [0]);
  assert.deepEqual(forbiddenIn("nothing to see here", denylist), []);
  assert.ok(DENYLIST.every((e) => /^[0-9a-f]{64}$/.test(e.sha256)));
});

test("the web lockfile exists and matches the manifest [AC-OPS-02]", () => {
  assert.ok(exists("web/package-lock.json"), "web/package-lock.json is missing: builds would float");
  const manifest = JSON.parse(read("web/package.json"));
  const lockRoot = JSON.parse(read("web/package-lock.json")).packages[""];
  assert.deepEqual(lockRoot.dependencies, manifest.dependencies);
  assert.deepEqual(lockRoot.devDependencies, manifest.devDependencies);
});

test("the documented setup works as written [AC-OPS-03]", () => {
  // git records the executable bit. A script without it fails with "Permission
  // denied" for whoever follows the README, which is how this was found.
  const scripts = execFileSync("git", ["ls-files", "-s", "api/bin", "quality/snapshot.sh", "quality/fix.py"], {
    cwd: ROOT,
    encoding: "utf8",
  }).trim().split("\n");
  assert.ok(scripts.length >= 5, "expected the bin stubs and the quality scripts to be tracked");
  for (const line of scripts) assert.match(line, /^100755 /, `${line.split("\t")[1]} is not executable`);

  // The web app's default API address must be the address the API listens on.
  const apiPort = read("api/config/puma.rb").match(/ENV\.fetch\('PORT', (\d+)\)/)?.[1];
  assert.ok(apiPort, "could not read the API's default port from api/config/puma.rb");
  for (const file of ["web/.env.example", "web/src/services/api.ts", "web/README.md"]) {
    const ports = [...read(file).matchAll(/localhost:(\d+)/g)].map((m) => m[1]).filter((p) => p !== "5173");
    assert.ok(ports.length > 0, `${file} names no API address`);
    assert.deepEqual([...new Set(ports)], [apiPort], `${file} points at a port the API does not listen on`);
  }
});

test("the repository layout the gates rely on is present", () => {
  for (const file of ["docs/specs/acceptance-criteria.md", "quality/risk-register.json", ".github/pull_request_template.md"]) {
    assert.ok(exists(file), `${file} is missing (repo root: ${ROOT})`);
  }
});
