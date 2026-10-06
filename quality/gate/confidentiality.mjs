#!/usr/bin/env node
// The one hard rule of this repository: it must not name the company, the
// product owner's brand, or any client. This check enforces that without
// naming them: the denylist holds SHA-256 digests of the forbidden words, and
// every word in every tracked file (and in commit messages) is hashed and
// compared, including as a substring of a longer identifier.
//
// It is a tripwire against accidents, not a secret: a short word's digest can
// be brute-forced. To add a term: printf '%s' "term" | shasum -a 256
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { ROOT, read, repoFiles, report } from "./lib.mjs";

// length of the forbidden word, and the digest of its lowercase form
export const DENYLIST = [
  { length: 7, sha256: "7704d9bef76cf1a7463e7ee53ab63361b86557c9cb39a63f2e220b468a81bcc1" },
  { length: 7, sha256: "60280e12933862e2f1552575bcce9c74a7890c9f3148c031237651eb5d5a1a71" },
];

const BINARY = /\.(png|jpe?g|gif|ico|webp|woff2?|ttf|eot|pdf|zip|gz|mp3|wav)$/i;
const digest = (word) => createHash("sha256").update(word).digest("hex");

// Returns the denylist entries found in the text, as indexes into the denylist.
export function forbiddenIn(text, denylist = DENYLIST, seen = new Map()) {
  const hits = new Set();
  for (const word of new Set(text.toLowerCase().match(/[a-z0-9]+/g) ?? [])) {
    if (!seen.has(word)) {
      const found = [];
      denylist.forEach((entry, index) => {
        for (let i = 0; i + entry.length <= word.length; i++) {
          if (digest(word.slice(i, i + entry.length)) === entry.sha256) {
            found.push(index);
            break;
          }
        }
      });
      seen.set(word, found);
    }
    for (const index of seen.get(word)) hits.add(index);
  }
  return [...hits];
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const seen = new Map();
  const problems = [];
  for (const file of repoFiles()) {
    if (BINARY.test(file)) continue;
    const hits = new Set(forbiddenIn(file, DENYLIST, seen));
    const lines = read(file).split("\n");
    const where = [];
    lines.forEach((line, n) => {
      const found = forbiddenIn(line, DENYLIST, seen);
      found.forEach((h) => hits.add(h));
      if (found.length) where.push(n + 1);
    });
    if (hits.size) {
      const shown = where.slice(0, 5).join(", ") + (where.length > 5 ? ", …" : "");
      problems.push(`${file}: forbidden term #${[...hits].map((h) => h + 1).join(", #")}` + (where.length ? ` on line ${shown}` : " in the path"));
    }
  }
  try {
    const log = execFileSync("git", ["log", "--format=%H%n%B"], { cwd: ROOT, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (forbiddenIn(log, DENYLIST, seen).length) problems.push("a commit message contains a forbidden term");
  } catch {
    /* no history (fresh checkout without git): files are still checked */
  }
  process.exit(report("Confidentiality", problems, "no forbidden company or client name in any tracked file or commit message"));
}
