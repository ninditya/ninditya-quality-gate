# 02 — The quality system

What I built, how to run it, what each part protects, and how the net went
from red to green.

## The whole thing on one screen

Two halves, one status.

```
 a change
    │
    ▼
 pull request ──► quality-net  (one status; nothing merges around it)
                   ├─ Definition of Ready   spec + criteria + design plan + tests
                   ├─ API suite             58 checks: data, tenancy, lifecycle, contracts
                   ├─ Web suite             19 checks, type-check, production build
                   └─ Gates                 traceability both ways, confidentiality

 tag vX.Y.Z ───► release-gate  the same net at the tag
                               + the risk register + the release notes
                               ──► RELEASABLE or BLOCKED, written on the tag
```

- **The workflow gate** makes missing inputs block the work. A change to
  runtime code cannot go green without a linked spec, acceptance criteria that
  exist and are enforced, a design plan, and a test.
- **The test net** goes red on real defects in what is stored and computed,
  and in the seam between the two services.

Everything runs in CI on every push and pull request, with no human in the
loop, and reports through a single job named `quality-net`.

## Where it sits in the delivery model

The brief describes six stages and four gates and puts this role at G2
("buildable") and G3 ("release-ready"). This is what each gate asks for and
what enforces it here.

| The gate needs | Enforced by | Not covered, and why |
|---|---|---|
| G2: acceptance criteria in Given/When/Then | `docs/specs/acceptance-criteria.md`. A runtime change must cite ids from it; an id that does not exist, or is still deferred, blocks | Whether a criterion is *right*. That takes a product owner |
| G2: a Definition of Done on every task | "Done" is mechanical: every cited criterion has a test tagged with its id, and the net is green | — |
| G2: an approved prototype | — | A code gate cannot see a prototype |
| G3: all DoDs met, regression green | `quality-net` at the tag | — |
| G3: traceability complete both ways | `quality/gate/traceability.mjs` and the generated [matrix](traceability-matrix.md) | — |
| Every gate co-signed by two roles | — | I worked alone. In a team this is a required review from a second role on the pull request, and on any change to the risk register |

## Half one: the workflow gate

`quality/gate/dor.mjs`, run by CI on every pull request, reading the pull
request description ([template](../.github/pull_request_template.md)).

**What it requires of a change that touches runtime code:**

1. **A spec.** A path under `docs/specs/` that exists.
2. **Acceptance criteria.** Ids that exist in the criteria file and are marked
   `enforced`. Citing a deferred criterion blocks: a change that implements a
   requirement has to switch it on.
3. **A design plan.** A few lines: what changes where, what data it touches,
   how to roll it back.
4. **Tests.** The change touches at least one test, and every cited criterion
   has a test tagged with its id.

**What keeps it from being a box-ticking exercise:**

- Whether a change is "runtime" is decided **from the diff**, not from a
  checkbox. Nobody can declare their way out.
- The template's own placeholder text does not count as content. An untouched
  template blocks.
- A change to docs, tests or tooling alone passes with an empty description.
  The gate costs nothing when there is nothing to protect.
- Removing a test file, or adding a skipped or focused test, blocks unless the
  description has a `## Net change` section saying why. The net can change,
  never quietly.

**What it deliberately does not judge:** whether the spec is correct or the
plan is good. It checks that the inputs exist and connect to each other. A
person still has to read them.

**Red means it cannot merge.** A branch ruleset on `main` requires a pull
request and a passing `quality-net` status, and its bypass list is empty. A
pull request the net rejects cannot be merged by anyone, me included, and a
direct push to `main` is refused. The ruleset went on after the bulk of the
work, which the brief asks to be committed straight to `main`; from then on
every change goes through a pull request, starting with the one that added
this paragraph.

### The three blocks the brief asks for

| Must block | What blocks it | Shown by |
|---|---|---|
| A change with no test | Rule 4 | Pull request #1; gate self-test "blocks a runtime change that changes no test" |
| A change with no linked spec or acceptance criteria | Rules 1 and 2 | Pull request #1; gate self-test "blocks a runtime change with no linked spec or acceptance criteria" |
| A regression on a critical path | The API and web suites | Pull request #1: its change turns `portfolio_generator_spec` red |

### The two demonstration pull requests

- **[#1](https://github.com/ninditya/ninditya-quality-gate/pull/1), blocked.** "Fill empty levels with L1 so the report has no blanks." A
  plausible request and exactly the change this net exists to stop: it
  restores R-05. One-line description, no spec, no criteria, no plan, no test.
  The Definition of Ready job fails with four reasons and the API suite fails
  on `AC-PF-01` (6 of 55 checks red). Left open; GitHub shows its merge as
  blocked.
- **[#2](https://github.com/ninditya/ninditya-quality-gate/pull/2), passes.** "Only assessors can watch a live interview" (R-15). It
  cites `AC-SEC-06`, switches that criterion from deferred to enforced, adds
  the tagged check, states its plan and rollback, and marks the risk fixed in
  the register. Green, merged.

The gates have their own tests (`quality/gate/gate.test.mjs`, 23 of them).
Each rule is shown blocking what it exists to block and letting a well-formed
change through. A gate nobody tests is a gate nobody should trust.

## Half two: the test net

77 checks. Each one is there because of a risk in the audit; none is there for
a coverage number.

| Check | Protects against | Deliberately does not cover |
|---|---|---|
| `api/spec/boot_spec.rb` | Code that loads on a laptop and crashes production at boot | Missing environment variables, infrastructure |
| `api/spec/requests/tenant_isolation_spec.rb` | One tenant reading or changing another's results | Tenancy in workers and sockets (R-14) |
| `api/spec/tenant_scoping_guard_spec.rb` | The *next* unscoped lookup: it reads the controllers and fails on any bare lookup of a table with no tenant column | Code outside controllers |
| `api/spec/services/portfolio_generator_spec.rb` | Model output becoming stored ratings unchecked: invented levels, dropped skills, trusted confidence, half-written regenerations | Whether the model's ratings are *good* (R-12) |
| `api/spec/requests/fit_gap_spec.rb` | Wrong or stale comparisons reaching a hiring decision | The quality of the narrative text |
| `api/spec/requests/session_lifecycle_spec.rb` | Sessions ended by the wrong party or stored with the wrong reason | — |
| `api/spec/channels/audio_websocket_*` | An interview killed by a reconnect or by a polite phrase | Audio, and the real model connection (R-12) |
| `api/spec/channels/coverage_websocket_auth_spec.rb` | Someone who is not an assessor watching a live interview | — |
| `api/spec/requests/write_honesty_spec.rb` | A success response for a write that did not happen | — |
| `contracts/*.json`, `contract_spec.rb`, web component tests | The web and the API drifting apart on a field name or type | Responses with no fixture yet. Four have one so far: the ones the result and candidate pages read |
| `web/src/pages/interview/*.test.tsx`, `hooks/useAudioWebSocket.test.ts` | Telling a candidate that a failed interview is complete | Microphone capture and playback |
| `web/src/components/assessment/LevelRadio.test.tsx` | A level saved against the wrong skill | — |
| `quality/gate/traceability.mjs` | A requirement nobody tests; a test nobody asked for; a silent "we skipped that" | — |
| `quality/gate/confidentiality.mjs` | The company or a client being named in a public repository | Images and binaries |
| `quality/gate/release.mjs` | Shipping with an open P0 or P1, or with an undisclosed risk | The deploy itself: it gates the tag, not the cluster (R-28) |

**Rules the net holds itself to:**

- It checks **what is stored and computed**, not what is rendered. Most API
  checks pair the HTTP answer with a database read afterwards.
- **Nothing calls the model or the network.** Model output is injected, because
  the question is what the code does with an answer it should not trust. The
  cost of that choice is R-12, and it is stated rather than hidden.
- **Every check that proves a requirement is tagged** with the criterion id
  (`[AC-PF-01]`). Traceability is computed from the tags, so it cannot drift
  from the tests.
- **"Deferred" is never free.** A criterion I am not enforcing must point at
  an open, owned risk, or the gate fails. A risk cannot be marked fixed unless
  an enforced, tested criterion backs it.

**Would it have caught the audit's findings before a human looked?** That is
measured, not claimed. At the commit that introduces the net, before any fix,
it fails by itself on 27 of 40 API checks and 10 of 16 web checks, and every
one of those failures is a finding in the audit.

## Run it and extend it

The working instructions are in [quality/README.md](../quality/README.md).
In short:

```bash
# API suite. Postgres, Redis and Ruby run in containers; nothing to install.
docker compose -f docker-compose.test.yml run --rm api-test

# Web suite
cd web && npm ci && npm run typecheck && npm test && npm run build

# Gates (Node 22, no dependencies)
node --test quality/gate/gate.test.mjs
node quality/gate/traceability.mjs
node quality/gate/confidentiality.mjs
node quality/gate/release.mjs --tag v1.0.0 --net success
```

I ran exactly these from a fresh copy of this repository before writing this
page. The suites and the gates pass. The release gate answers BLOCKED, which
[03-release-decision.md](03-release-decision.md) explains.

To add a behaviour: write the criterion, write a test whose name ends with its
id, regenerate the matrix. To record a risk you are not fixing: add it to
`quality/risk-register.json` with an owner and a mitigation.

## Red to green

**Before.** Commit `6daabd8` adds the net and nothing else.
[evidence/01-red-api.txt](evidence/01-red-api.txt),
[01-red-web.txt](evidence/01-red-web.txt): API 27 of 40 failing, web 10 of 16
failing plus a type error.

**After.** [evidence/02-green-api.txt](evidence/02-green-api.txt),
[02-green-web.txt](evidence/02-green-web.txt),
[02-green-gates.txt](evidence/02-green-gates.txt): API 58 of 58, web 19 of
19, type-check clean, gates 23 of 23.

**In between,** one commit per risk. Each commit message states the root
cause, the fix, and which check went from red to green. Each commit was pushed
on its own, so each has its own CI run: in the [Actions tab](https://github.com/ninditya/ninditya-quality-gate/actions)
the `quality-net` runs on `main` are red for fifteen commits in a row, from
`6daabd8` to `7c58b5d`, and green from `ee1b48f` on.

| Risk | Sev | What was red | Root cause, and what I changed | Commit |
|---|---|---|---|---|
| R-01 | P0 | `boot_spec` | Two class names did not match their file names. Lazy loading in development hid it; production eager-loads and crashes. Declared the names to the autoloader | `22f6c42` |
| R-02 | P0 | `session_lifecycle_spec` (invite link) | The link was built from the API's own URL. Built it from the web app's URL; production refuses to boot without it | `b056f79` |
| R-03, R-04 | P1 | `tenant_isolation_spec`, `tenant_scoping_guard_spec` | Result tables have no tenant column and were looked up by bare id; login took the tenant from a header. Added ownership scopes, used them everywhere, bound login to the user's organization | `ed73819` |
| R-05, R-06, R-20 | P1 | `portfolio_generator_spec`, `SkillPortfolioCard.test` | The level column could not hold "unknown", so the code wrote 1; confidence was the model's own word; regeneration deleted before it inserted. Made the level nullable, decided what to store from the assessment and the coverage map, computed confidence by the PRD rule, wrapped the replace in a transaction | `18cf09d` |
| R-22 | P2 | `ComparisonTable.test`, `contract_spec`, the web type-check | The web read a field name the API does not send, and a flag the API never sent. Fixed both sides against one fixture | `207f325` |
| R-11 | P1 | `fit_gap_spec` (stale report) | A stored report was always served. A report now knows its inputs are newer than it is | `5e18945` |
| R-08, R-24 | P1, P2 | `session_lifecycle_spec` | An unauthenticated endpoint ended any session as "all covered". It now refuses a session that never started and records the reason from stored coverage and time | `a0c3395` |
| R-07 | P1 | `audio_websocket_grace_period_spec` | The "candidate left" timer lived in one socket's memory, so a reconnect could not cancel it. The newest connection now records itself on the session row | `8b86226` |
| R-26 | P1 | `audio_websocket_closing_phrase_spec` | Any of fifteen phrases in the AI's speech ended the interview. The match now counts only when the AI had a reason to close | `1a88303` |
| R-09 | P1 | `write_honesty_spec` (removed skill) | The web removes a row by omitting it; the API removes one only when told to. On update, the submitted list is now the list | `9f02b4e` |
| R-21 | P1 | `write_honesty_spec` (delete) | The controller ignored the result of the delete. It answers 409 when nothing was deleted | `40818f2` |
| R-23 | P2 | `write_honesty_spec` (unknown route) | No catch-all route; the ticket for it was closed as completed without a change | `b919660` |
| R-19, R-38 | P1 | `InterviewPage.test`, `useAudioWebSocket.test` | The candidate page had one terminal state and every exit used it. Added a "failed" state and stopped claiming completion the server never confirmed | `2fd1c45` |
| R-10 | P1 | `LevelRadio.test` | Every level picker on a page used the same element ids. Unique ids per picker | `7c58b5d` |
| R-25 | P2 | `api.test` | Every 401 reloaded the login page, including a wrong password. The login request is exempt | `ee1b48f` |
| R-31, R-27 | P3, P2 | gate self-test `AC-OPS-03` | Scripts committed without the executable bit; the web's default API port was not the API's | `73fc9df` |
| R-15 | P2 | `coverage_websocket_auth_spec` | The live coverage socket checked who the caller was and never their role. It now uses the role list the HTTP API uses | pull request #2 |

`ee1b48f` is the first commit at which the whole net is green.

### No check was made green by weakening it

Since the net was introduced, 317 lines were added to checks and **four were
removed**. No test file was deleted and nothing is skipped. The four lines:

- In `fit_gap_spec.rb`, three lines of setup for `AC-FG-02` that inserted the
  unrated row with `save!(validate: false)`, and only when the column happened
  to be nullable. Replaced by creating the row through the model's validations.
  The check is stricter than it was (commit `18cf09d`).
- In `InterviewPage.test.tsx`, a stub of the hardware check that rendered
  static text. Replaced by one with a start button, so that new tests can
  begin an interview (commit `2fd1c45`).

To verify:

```bash
git diff 6daabd8 HEAD -- api/spec 'web/src/*.test.ts' 'web/src/*.test.tsx' quality/gate/gate.test.mjs | grep '^-[^-]'
```

### What I got wrong on the way

Kept because the corrections say more about the method than the successes do.

- **I never ran my own documented command.** The README told the reader to run
  `docker compose … run --rm api-test`. I had been using a longer form by hand.
  When I finally ran it as written, it failed: the scripts it calls were not
  executable. The audit had this down as a P3 papercut; it broke the first
  command a new engineer would type. It now has a criterion and a check.
- **Two checks were red for the wrong reason on the first run.** A fake model
  client was being constructed incorrectly, so those tests failed on the
  harness, not on the defect. I read every failure message before counting a
  red as a finding, and fixed the harness first.
- **The gate's "skipped test" detector flagged the word "fit"** in "Fit/gap"
  as a focused test. It is now anchored to where a test is declared.
- **The first fix for R-19 left a path that still lied.** With the socket
  down, "End Interview" sent a message nowhere and showed "complete". Found
  while reading my own diff; recorded as R-38 rather than folded in quietly.
- **A commit message claimed more than the ticket said.** I checked it against
  the ticket and corrected the message before publishing.

I used an AI assistant throughout: to read the code, and to draft checks,
fixes and these documents. Each of the corrections above is a place where a
first draft was wrong and running it, or reading the source it referred to,
showed that.

## About the history

The brief asks for a fresh repository with no link to the source. It also
forbids naming the company or a client, and the source named both in 25
files. A later commit that removes a name leaves it readable in every earlier
one, so the names are removed from **every** commit's tree, beginning with the
import. Each of my commits was replayed onto that import with its message and
timestamp unchanged.

Two consequences, stated so they are not surprises:

- The confidentiality gate is green at every commit in this history. It was
  red on the source as received. That red cannot be reproduced from this
  repository, by design.
- After replaying, I re-ran the API suite and the gates at `6daabd8` in the
  new history. They match the recorded baseline exactly.

## What I would build next

1. **An evaluation harness for the interviewer (R-12).** A scripted candidate,
   a recorded transcript, and assertions for the six failure modes in PRD-01.
   It is the one check the product most needs and the only large gap in this
   net.
2. **A required second reviewer.** The ruleset on `main` already turns "cannot
   go green" into "cannot merge". What it cannot supply while I work alone is
   the second signature the delivery model asks for on every gate.
3. **Fail-closed tenancy (R-14)**, so that the next forgotten scope returns
   nothing rather than everything.
4. **Contract fixtures for the remaining responses**, starting with the ones
   the candidate page reads.
5. **A gem audit** in the gates job (R-41).
