#!/usr/bin/env node
// Release gate (gate G3). Answers one question for one tag, in words a
// non-engineer can read: is this version RELEASABLE or BLOCKED, and why.
//
// A version is releasable only when all of these hold:
//   1. the quality net (API suite, web suite, traceability, confidentiality) is green
//   2. RELEASE_NOTES.md has a section for the tag
//   3. no P0 or P1 risk is open; an accepted one has an owner, a mitigation,
//      a named approver and an expiry date that has not passed
//   4. every risk that is not fixed is disclosed in that release-notes section
//   5. traceability is complete both ways
//
//   node quality/gate/release.mjs --tag v1.0.0 --net success
import { writeFileSync } from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { ROOT, read, exists, loadRisks, summary } from "./lib.mjs";
import { collect, checkTraceability } from "./traceability.mjs";

const NOTES = "RELEASE_NOTES.md";
const BLOCKING = new Set(["P0", "P1"]);

// The part of the release notes that belongs to one version.
export function notesFor(notes, tag) {
  const escaped = tag.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = notes.match(new RegExp(`^## ${escaped}\\b[^\\n]*\\n([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, "m"));
  return match ? match[1] : null;
}

export function checkRelease({ tag, net, notes, risks, traceability, today = new Date().toISOString().slice(0, 10) }) {
  const blockers = [];
  const disclosed = [];

  if (!/^v\d+\.\d+\.\d+$/.test(tag ?? "")) blockers.push(`"${tag}" is not a release tag (expected vMAJOR.MINOR.PATCH)`);
  if (net !== "success") blockers.push(`the quality net is not green (result: ${net ?? "not run"})`);

  const section = notes === null ? null : notesFor(notes, tag);
  if (section === null) blockers.push(`${NOTES} has no "## ${tag}" section stating what this version delivers`);

  for (const r of risks) {
    if (r.status === "fixed") continue;
    const label = `${r.id} (${r.severity}) ${r.title}`;

    if (r.status === "accepted") {
      const missing = ["owner", "mitigation", "accepted_by", "expires"].filter((f) => !r[f]);
      if (missing.length) blockers.push(`${label}: accepted without ${missing.join(", ")}`);
      else if (r.expires < today) blockers.push(`${label}: risk acceptance expired on ${r.expires}`);
      else disclosed.push(`${label} — accepted by ${r.accepted_by} until ${r.expires}; owner ${r.owner}`);
    } else if (BLOCKING.has(r.severity)) {
      blockers.push(`${label}: open ${r.severity}. Fix it, or record an explicit risk acceptance with an owner`);
    } else {
      if (!r.owner) blockers.push(`${label}: open risk has no owner`);
      disclosed.push(`${label} — open; owner ${r.owner ?? "nobody"}`);
    }

    if (section !== null && !section.includes(r.id)) {
      blockers.push(`${label}: not disclosed in the ${tag} release notes`);
    }
  }

  for (const problem of traceability) blockers.push(`traceability: ${problem}`);

  return { tag, releasable: blockers.length === 0, blockers, disclosed };
}

export function renderStatus({ tag, releasable, blockers, disclosed }) {
  const lines = [
    releasable ? `# ✅ ${tag} is RELEASABLE` : `# ⛔ ${tag} is BLOCKED`,
    "",
    releasable
      ? "Every release gate passed for this version."
      : "This version must not ship. It is blocked by:",
  ];
  if (!releasable) lines.push("", ...blockers.map((b) => `- ${b}`));
  lines.push("", "## What the gate checked", "",
    "- the quality net: API suite, web suite, traceability, confidentiality",
    "- release notes exist for this exact version",
    "- no open P0/P1; accepted risks are owned, mitigated, approved and not expired",
    "- every unfixed risk is disclosed in the release notes",
    "- every enforced acceptance criterion has a test, and every test tag resolves");
  lines.push("", "## Known risks shipping with this version", "",
    ...(disclosed.length ? disclosed.map((d) => `- ${d}`) : ["- none"]));
  return lines.join("\n") + "\n";
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const arg = (name) => {
    const i = process.argv.indexOf(name);
    return i > -1 ? process.argv[i + 1] : undefined;
  };
  const data = collect();
  const result = checkRelease({
    tag: arg("--tag") ?? process.env.GITHUB_REF_NAME,
    net: arg("--net") ?? process.env.NET_RESULT,
    notes: exists(NOTES) ? read(NOTES) : null,
    risks: loadRisks(),
    traceability: checkTraceability(data),
  });
  const status = renderStatus(result);
  const out = arg("--out");
  if (out) writeFileSync(path.resolve(ROOT, out), status);
  summary(status);
  console.log(status);
  if (process.env.GITHUB_OUTPUT) {
    writeFileSync(process.env.GITHUB_OUTPUT, `status=${result.releasable ? "RELEASABLE" : "BLOCKED"}\n`, { flag: "a" });
  }
  process.exit(result.releasable ? 0 : 1);
}
