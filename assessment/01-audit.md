# 01 — Audit: the real state of the platform

## Read this first

**What the product does.** An assessor defines an assessment (skills, each with
five level descriptions) and a vacancy (the level each skill requires). A
candidate opens an invite link and has a voice interview with an AI. The system
then rates the candidate L1 to L5 on each skill from the transcript (the
"portfolio") and compares the ratings with the vacancy (the "fit/gap report").
An assessor may override a rating. The output is a hiring recommendation about
a real person.

**The state as I received it.** It could not start in production, and if it
had, the link sent to candidates did not open. Behind those two, the interview
and the rating pipeline looked finished on screen and were wrong underneath in
ways the screen hid:

- a skill that was never discussed was stored and shown as a measured **L1**,
  and then reported as a **gap** against the vacancy;
- a network blip, or the AI saying "good luck", ended the interview and stored
  it as **all skills covered**;
- a candidate whose interview failed, or never loaded, was told **"Interview
  Complete. The interview has been recorded."**;
- any tenant could read, export and overwrite another tenant's candidates by
  changing a number in the URL;
- removing a skill in the edit form removed it from the screen and not from
  the database.

There were no tests, no acceptance criteria and no design plan for any
feature, so nobody could have said which of these was a defect.

**The count.** 41 risks: 2 P0, 15 P1, 23 P2, 1 P3. Of these, 27 are built
wrong, 8 are behaviour nobody specified, and 6 are inputs that do not exist.

**Where it stands now.** Both P0 and 14 of the 15 P1 are fixed, each with a
check that was red before the fix and is green after. 23 risks are fixed and
18 remain, every one with an owner and a mitigation.

**Ship or not.** As received: do not ship. At the head of this repository:
still do not ship to a client. Every check I can run is green, and the one
thing the product exists to do, a live AI interview, has never been run on
this build by me or, as far as the repository shows, by anyone (R-12). The
release gate blocks on that, and I agree with it. The decision is in
[03-release-decision.md](03-release-decision.md).

**What I would gate before a client's candidates use this:**

1. One real interview, start to finish, with the result attached (R-12). The
   script is in [uat-live-interview.md](uat-live-interview.md).
2. A decision on candidate consent and recording retention (R-37). A voice
   interview is recorded and sent to a third-party model; nothing asks the
   candidate or says how long it is kept.
3. Product sign-off on the 21 acceptance criteria I had to derive (R-36). They
   are my reading of what the product should do, not a decision I can make.
4. Deploy manifests that pin the released version and supply the secrets the
   app needs (R-28).

## How I assessed it

- Read all of the API (about 4,500 lines of Ruby) and the web app (about 6,400
  lines of TypeScript), the two PRDs in the source wiki, and everything around
  the code: the tracker, branches, pull requests and releases.
- Brought the API up in containers (PostgreSQL, Redis, Ruby 3.3) and turned
  each suspicion into a check that fails for that reason and no other.
- A finding is marked **Failing check** when a test demonstrates it, and **By
  reading** when I could only establish it from the code.

**Every failing check is reproducible.** Commit `6daabd8` adds the net before
any fix. Check it out and run the named file: 27 of 40 API checks and 10 of 16
web checks fail there, each on a real defect
([evidence/01-red-api.txt](evidence/01-red-api.txt),
[evidence/01-red-web.txt](evidence/01-red-web.txt)).

**What I could not run**, and so cannot vouch for:

- a live interview: I had no model credentials, and nothing in the net calls
  the model;
- a production boot or a deploy: no cluster;
- microphone capture and audio playback in a browser.

## What works

Not everything is broken, and the list matters for deciding what to trust.

- Assessor setup: creating and listing assessments and vacancies, the skill
  taxonomy, creating a session. Exercised by request checks on the write paths;
  the read paths by reading.
- The fit/gap comparison rule is correct for a skill that has a rating
  (`AC-FG-01` was green on the first run).
- Tenant scoping on assessments, sessions and vacancies was right from the
  start (the smoke check was green on the first run). The leak was in the
  tables that have no tenant column.
- Unauthenticated assessor requests are refused with JSON.
- The live audio path contains careful work: session resumption, a proactive
  reconnect before the model's own time limit, echo gating. I read it; I could
  not run it.

## The risks, ranked

Severity is the brief's scale, applied top to bottom. Within a severity the
order is mine: how many people it reaches and whether it corrupts data.

"Kind" separates **built wrong** (a document says what should happen, or it is
not arguable, and the build does not do it) from **missing spec** (nobody
defined the behaviour, so the build could not be right) and **missing input**
(a spec, criterion, plan or piece of evidence that should exist and does not).

### P0 — Blocker

| # | Risk | What is wrong | Who or what is hurt | Kind | How I found it | Final status |
|---|---|---|---|---|---|---|
| 1 | R-01 | The API cannot boot the way production boots it | Everyone: the service crash-loops on deploy; nothing works. | Built wrong | Failing check: `api/spec/boot_spec.rb` | **Fixed** (`22f6c42`) |
| 2 | R-02 | The invite link sent to candidates points at the API host | Candidates: the link opens a server error page, so no interview can start from an invite. | Built wrong | Failing check: `api/spec/requests/session_lifecycle_spec.rb` | **Fixed** (`b056f79`) |

### P1 — Major

| # | Risk | What is wrong | Who or what is hurt | Kind | How I found it | Final status |
|---|---|---|---|---|---|---|
| 3 | R-12 | No evidence that a live AI interview works on this build: PRD-01 section 7 says engineers must test the failure modes, and nothing does | Everyone: the product's main function is unverified end to end; defects in that path are found by reading, not by running. | Missing input | No test, recording or eval exists in the repo, the tracker or the wiki. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: Run the scripted interview in assessment/uat-live-interview.md against staging with model credentials and attach the transcript. |
| 4 | R-03 | Any tenant can read, export and overwrite another tenant's candidate results by id | Client tenants and candidates: ratings and evidence leak across companies and can be changed by a stranger. | Built wrong | Failing check: `api/spec/requests/tenant_isolation_spec.rb` | **Fixed** (`ed73819`) |
| 5 | R-04 | A login is not tied to any organization; the caller picks the tenant with a header | Client tenants: any assessor account can obtain a valid token for any other company. | Missing spec | Failing check: `api/spec/requests/tenant_isolation_spec.rb` | **Fixed** (`ed73819`) |
| 6 | R-05 | Skills that were never assessed are stored and shown as real ratings (usually L1) | Candidates and hiring managers: a fabricated low rating reads as a measured gap and drives the fit/gap result. | Built wrong | Failing check: `api/spec/services/portfolio_generator_spec.rb` | **Fixed** (`18cf09d`) |
| 7 | R-07 | Any dropped connection silently ends the interview two minutes later, even after the candidate rejoined | Candidates: the interview keeps running on screen while the stored session is already ended as failed and rated from a truncated transcript. | Built wrong | Failing check: `api/spec/channels/audio_websocket_grace_period_spec.rb` | **Fixed** (`8b86226`) |
| 8 | R-26 | A courtesy phrase from the AI ('good luck', 'thank you for your time') ends the interview | Candidates: an interview can be cut short mid-way on a phrase match. | Built wrong | Failing check: `api/spec/channels/audio_websocket_closing_phrase_spec.rb` | **Fixed** (`1a88303`) |
| 9 | R-08 | Anyone holding an invite link can end the session, and it is recorded as 'all skills covered' | Assessors: a never-started interview shows as completed; a cut-short interview is stored as fully covered. | Built wrong | Failing check: `api/spec/requests/session_lifecycle_spec.rb` | **Fixed** (`a0c3395`) |
| 10 | R-19 | A candidate is told 'Interview Complete, recorded' when the link is invalid, the page failed to load, or the connection was lost | Candidates: they believe they finished an interview that never happened or failed, and do not retry or ask. | Built wrong | Failing check: `web/src/pages/interview/InterviewPage.test.tsx`; `web/src/hooks/useAudioWebSocket.test.ts` | **Fixed** (`2fd1c45`) |
| 11 | R-38 | Ending the interview while the connection is down shows 'Interview Complete' although the server was never told | Candidates and assessors: the candidate sees a completed interview; the stored session stays active and is ended as failed two minutes later. | Built wrong | Failing check: `web/src/pages/interview/InterviewPage.test.tsx`; found while fixing R-19 | **Fixed** (`2fd1c45`) |
| 12 | R-09 | Removing a skill in the assessment or vacancy edit form does not remove it | Assessors: the screen shows the skill gone; the AI still interviews on it and the fit/gap still requires it. | Built wrong | Failing check: `api/spec/requests/write_honesty_spec.rb`; `web/src/pages/vacancies/VacancyEditPage.test.tsx` | **Fixed** (`9f02b4e`) |
| 13 | R-10 | Clicking a level label on one skill changes a different skill's level | Assessors: required levels are saved against the wrong skill, so fit/gap results are computed against wrong requirements. | Built wrong | Failing check: `web/src/components/assessment/LevelRadio.test.tsx` | **Fixed** (`7c58b5d`) |
| 14 | R-06 | Confidence is whatever the model says, not the rule the PRD defines | Hiring managers: a rating can show HIGH confidence for a skill probed once. | Built wrong | Failing check: `api/spec/services/portfolio_generator_spec.rb` | **Fixed** (`18cf09d`) |
| 15 | R-20 | A failed portfolio regeneration destroys the existing ratings and assessor overrides | Assessors: human review work is lost with no trace. | Built wrong | Failing check: `api/spec/services/portfolio_generator_spec.rb` | **Fixed** (`18cf09d`) |
| 16 | R-11 | A fit/gap report is served unchanged after the vacancy's requirements change | Hiring managers: a decision is read from a report computed against requirements that no longer exist. | Missing spec | Failing check: `api/spec/requests/fit_gap_spec.rb` | **Fixed** (`5e18945`) |
| 17 | R-21 | Deleting an assessment that has sessions answers 'deleted' and deletes nothing | API consumers: the response contradicts the stored data. | Built wrong | Failing check: `api/spec/requests/write_honesty_spec.rb` | **Fixed** (`40818f2`) |

### P2 — Minor

| # | Risk | What is wrong | Who or what is hurt | Kind | How I found it | Final status |
|---|---|---|---|---|---|---|
| 18 | R-37 | Shipped behaviour with no spec at all: login and users, the tenancy model, candidate consent and recording retention, export contents, rate limits, the 10-minute time limit | Clients and candidates: a voice interview is recorded and sent to a third-party model with no consent step or retention rule defined. | Missing spec | No document covers these; the code is the only statement of intent. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: None. Needs a product and legal decision before client data is processed. |
| 19 | R-36 | No feature had acceptance criteria, a design plan, or any test before this audit | Everyone: nobody could say whether a feature was correct. The criteria written here are the auditor's reading and need product sign-off. | Missing input | The wiki holds two narrative PRDs; the repo had no spec directory and no tests. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: docs/specs/acceptance-criteria.md now holds reviewable criteria; the gate requires them for every runtime change. |
| 20 | R-14 | Tenant scoping fails open: with no tenant resolved, queries return every tenant's rows | Client tenants: the next endpoint or job that forgets the tenant leaks everything instead of nothing. | Built wrong | By reading api/app/models/concerns/tenant_scoped.rb. | **Remaining.** Owner: Tech lead (to be named at G3 sign-off). Mitigation: Every authenticated request requires a resolved tenant today, and AC-SEC-04 guards the tenant-less tables. Workers and sockets rely on the open default, so closing it is a planned refactor. |
| 21 | R-39 | The web app falls back to a build-time developer token when nobody is signed in | Client tenants: a build made with VITE_DEV_TOKEN set ships that token inside the public bundle, and every visitor is signed in as it. | Built wrong | By reading web/src/stores/authAtom.ts (getStoredToken) and web/.env.example. | **Remaining.** Owner: Tech lead (to be named at G3 sign-off). Mitigation: Not set in any committed configuration. Never set VITE_DEV_TOKEN for a deployed build; remove the fallback or strip it from production builds. |
| 22 | R-13 | Evidence quotes are not checked against the transcript | Hiring managers: a quote the model invented would be shown as 'Evidence from interview'. | Missing spec | By reading api/app/services/portfolios/generator.rb; not observed, no model access. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: The transcript is one click away for cross-checking. Measure the invention rate during the R-12 run before choosing a rule. |
| 23 | R-35 | Transcript turns are written on background threads and write errors are swallowed | Hiring managers: a transcript can be missing turns with no signal, and ratings are generated from it. | Built wrong | By reading api/app/channels/audio_websocket_middleware.rb (save_transcript_turn). | **Remaining.** Owner: Ninditya (quality owner). Mitigation: Errors are logged. |
| 24 | R-34 | A skill is promoted to 'covered' on probe count alone, which PRD-01 section 4 does not allow | Hiring managers: 'covered' and therefore HIGH confidence can be reached without the evidence test. | Missing spec | By reading api/app/workers/coverage_analyzer_worker.rb (advance_stale_partials). | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: Promotion needs at least four exchanges on the skill. |
| 25 | R-16 | Editing an assessment after interviews were held rewrites what they were held against | Assessors: the definition a past result was judged against is no longer recoverable. | Missing spec | By reading; no document defines edit semantics once sessions exist. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: Stored ratings do not change. Avoid editing an assessment that has sessions; duplicate it instead. |
| 26 | R-17 | Invite links never expire and work for anyone who has them | Candidates and assessors: a forwarded or leaked link lets someone else take or disturb the interview. | Missing spec | By reading api/app/models/session.rb. | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: Tokens are 256-bit random; ended sessions refuse new connections. |
| 27 | R-15 | The live coverage socket accepts any validly signed token, whatever its role | Client tenants: a non-assessor account of the same tenant can watch a live interview's coverage. | Missing spec | By reading api/app/channels/coverage_websocket_middleware.rb. | **Fixed** (pull request #2) |
| 28 | R-18 | The time limit is only enforced when someone speaks | Operations: a silent, connected session is never ended by the server. | Built wrong | By reading api/app/channels/audio_websocket_middleware.rb (check_time_ceiling). | **Remaining.** Owner: Ninditya (quality owner). Mitigation: The browser ends the interview when its own timer expires. |
| 29 | R-33 | The fit/gap page re-queues generation on every poll and has no failed state | Operations and assessors: duplicate model calls, and an endless spinner if generation fails. | Built wrong | By reading web/src/pages/fitgap/FitGapReportPage.tsx. | **Remaining.** Owner: Ninditya (quality owner). Mitigation: Reload the page. |
| 30 | R-29 | Calls to the analysis model are configured to retry but never do | Assessors: a transient model error fails a portfolio or coverage update immediately. | Built wrong | By reading api/app/clients/gemini/http_client.rb against the retry middleware defaults; not run. | **Remaining.** Owner: Ninditya (quality owner). Mitigation: Sidekiq retries the portfolio job three times. |
| 31 | R-32 | Creating an assessment answers 'system_prompt_generated: true' before the prompt exists, in a different shape from update | API consumers: a client that trusts the flag starts an interview with no prompt. | Built wrong | By reading api/app/controllers/api/v1/assessments_controller.rb. | **Remaining.** Owner: Ninditya (quality owner). Mitigation: The audio socket compiles a missing prompt on connect. |
| 32 | R-28 | Deploy manifests are not release-ready: image tag 'latest', the worker runs as 'staging' beside a 'production' API, and no manifest provides the secrets the app needs | Operations: what runs cannot be traced to a released version. | Missing input | By reading api/k8s/*.yaml; no cluster access. | **Remaining.** Owner: Tech lead (to be named at G3 sign-off). Mitigation: Do not apply these manifests as they are. Pin the image to the release tag at deploy time. |
| 33 | R-40 | Assessor pages show an empty form or a blank page when a resource does not exist or fails to load; the ticket for it (T-2) was closed as not planned | Assessors: a mistyped or stale link looks the same as a record with no data, and saving the empty form sends an update for a record that is not there. | Built wrong | T-2; by reading the load handlers in web/src/pages (four of them end in `.catch(() => {})`). | **Remaining.** Owner: Product owner (to be named at G2 sign-off). Mitigation: The API answers 404 for the missing record, so nothing is stored. The decision not to fix is the product owner's; it should be revisited for the result pages. |
| 34 | R-41 | Dependencies have never been audited: the web build and test tooling carries 11 known advisories, and the API's gems were not checked at all | Engineers and CI: a vulnerable tool runs on developer machines and in the pipeline. Nothing known reaches the shipped bundle. | Missing input | `cd web && npm audit`: 11 advisories (4 moderate, 5 high, 2 critical) in the tailwind and vitest chains. No audit tool is installed for the API. | **Remaining.** Owner: Ninditya (quality owner). Mitigation: `npm audit --omit=dev` is clean, so no advisory is in code that ships. CI runs with a read-only token and no secrets. Triage the 11, and add a gem audit to the net. |
| 35 | R-30 | A fresh setup has no user to log in with, and the signup screen calls an endpoint that does not exist | New engineers: the documented setup cannot reach a logged-in state. | Missing input | Failing check: `api/db/seeds.rb`; `web/src/services/auth.ts.` | **Remaining.** Owner: Ninditya (quality owner). Mitigation: Create a user from the Rails console. |
| 36 | R-22 | The fit/gap table shows an empty Required column and never marks overrides | Hiring managers: the report's main table is missing half its comparison. | Built wrong | Failing check: `web/src/components/fitgap/ComparisonTable.test.tsx`; `api/spec/requests/fit_gap_spec.rb` | **Fixed** (`207f325`) |
| 37 | R-24 | A session with no portfolio reports 'generating' forever | Assessors: an endless spinner for an interview that has not ended. | Built wrong | Failing check: `api/spec/requests/session_lifecycle_spec.rb` | **Fixed** (`a0c3395`) |
| 38 | R-23 | Unknown API routes raise a framework error; the ticket for it was closed as completed with no change | API consumers and the audit trail: a 'done' ticket describes work that never shipped. | Built wrong | Failing check: `api/spec/requests/write_honesty_spec.rb` | **Fixed** (`b919660`) |
| 39 | R-25 | A wrong password reloads the login page instead of showing the error | Assessors: no feedback on a failed login. | Built wrong | Failing check: `web/src/services/api.test.ts` | **Fixed** (`ee1b48f`) |
| 40 | R-27 | The web app had no lockfile, so a release build could differ from what was tested | Everyone: an untested dependency version can ship. | Missing input | Failing check: web/package-lock.json was absent from the source. | **Fixed** (`6daabd8`) |

### P3 — Cosmetic

| # | Risk | What is wrong | Who or what is hurt | Kind | How I found it | Final status |
|---|---|---|---|---|---|---|
| 41 | R-31 | Setup does not work as documented: bin stubs are not executable, and the web app's default API address is a port the API does not listen on | New engineers: the documented commands fail and a default setup cannot reach the API. | Built wrong | Failing check: `quality/gate/gate.test.mjs`; found by running the net's own documented command | **Fixed** (`73fc9df`) |

Two notes on severity.

- **R-12 is ranked first among the P1s although nothing is known to be
  broken.** It is the only risk that could be hiding a P0. The code shows
  signs of having been tuned against real sessions, so I assume the interview
  works in the authors' hands. An assumption is what it is.
- **R-37 is P2 by the scale and I would still stop for it.** The scale measures
  function and data. It has no row for "works correctly and exposes the client
  legally". Recording a candidate's voice and sending it to a third party with
  no consent step is a business decision that has not been made, which is why
  it sits in my gate list above.

## The patterns behind the issues

Most of the 41 came from five habits. These are what I would fix in the team,
because patching instances leaves the next one waiting.

**1. The system cannot say "unknown" or "failed", so it says "fine".**
A missing rating became L1 (R-05). A failed load became "Interview Complete"
(R-19). No portfolio became "generating" (R-24). A refused delete became
"deleted" (R-21). Every automatic end became "all skills covered" (R-08). A
dropped message became "complete" (R-38).
*Why it recurs:* the data model was designed for the happy path. The level
column was NOT NULL, the candidate page had one terminal state, the end reason
was hard-coded. With no value for "we do not know", every author of every new
feature has to invent a default, and the default is always the pleasant one.
*What stops it:* checks that assert what is **stored** on the unhappy path
(`portfolio_generator_spec`, `write_honesty_spec`, `session_lifecycle_spec`),
and nullable-by-design fields for anything measured.

**2. Two services, one contract, written twice by hand.**
The API sends `expected_level`; the web read `required_level` and drew an empty
column (R-22). The web marked overrides from a field the API never sent (R-22).
The web removes a row by leaving it out; the API removes a row only when told
to (R-09). The API built the candidate's link on its own host, where no such
page exists (R-02). The web's default API port is not the API's port (R-31).
The signup screen posts to an endpoint that does not exist (R-30).
*Why it recurs:* each side is correct by its own convention. The web's types
are assertions about the API, not checks against it, so the compiler agrees
with whatever the web believes.
*What stops it:* `contracts/`. One fixture per response, asserted by the API
suite against the real response and rendered by the web suite through the
real component. Either side drifting turns one suite red.

**3. Trust placed in the wrong party.**
The caller chose its own tenant with a header (R-04). An id in the URL was
taken as proof of ownership (R-03). An unauthenticated request was taken as
proof that every skill had been covered (R-08). The model's answer was stored
as it came: which skills exist, their levels, its own confidence (R-05, R-06,
R-13). A phrase in the model's speech ended the interview (R-26). With no
tenant resolved, queries return every tenant's rows (R-14). The live coverage
socket let in any role (R-15).
*Why it recurs:* nothing ever specified who may assert what. Each endpoint did
the minimum that made the demo work.
*What stops it:* a structural check that fails on the next unscoped lookup
(`tenant_scoping_guard_spec`), and treating model output as untrusted input
whose effects are decided by code.

**4. "Done" was a claim, never a check.**
The source had zero tests. PRD-01 says "engineers must test for these failure
modes" and nothing does (R-12). A ticket was closed as completed for a change
that was never made (R-23). The app had never been booted the way production
boots it (R-01). The setup instructions had never been followed as written
(R-31), including by me until I ran my own README.
*Why it recurs:* nothing in the workflow asked for proof, so none was produced.
*What stops it:* the Definition of Ready gate, traceability both ways, and a
release gate that reads the risk register
([02-quality-system.md](02-quality-system.md)).

**5. Facts about an interview kept where they can be lost.**
The "is the candidate still here" timer lived in one socket's memory, so a
reconnect could not cancel it (R-07). The time limit is checked only when
someone speaks (R-18). Transcript turns are written on background threads and a
failed write is logged and forgotten (R-35), and the ratings are generated
from that transcript.
*Why it recurs:* the audio path was built event by event, and state went
wherever the event handler happened to be.
*What stops it:* I fixed R-07 by moving the one fact that mattered onto the
session row. R-18 and R-35 are the same class and remain open.

## Missing inputs

These are findings in their own right. A feature with no criterion cannot be
correct or incorrect; it can only be whatever it is.

| Missing | What it means | What I did |
|---|---|---|
| Acceptance criteria, for every feature (R-36) | The two PRDs are narrative. Neither contains one testable statement. | Wrote 40 criteria in Given/When/Then: [docs/specs/acceptance-criteria.md](../docs/specs/acceptance-criteria.md). 19 cite a PRD, a ticket or the schema. **21 are "Derived"**: no document states the rule, I needed an answer to build, and each needs a product sign-off. |
| A design plan, for every feature | Nobody recorded what was meant to change where. | The gate now requires one on every runtime change. I did not write plans retroactively for existing features. |
| Evidence that the AI interviews as specified (R-12) | PRD-01 lists six failure modes and says engineers must test them. No test, recording or evaluation exists. | Wrote the script to run: [uat-live-interview.md](uat-live-interview.md). Could not run it. |
| Any spec at all for login, users, the tenancy model, candidate consent, recording retention, export contents, rate limits (R-37) | Shipped behaviour whose only statement of intent is the code. | Listed. These are product and legal decisions. |
| A dependency audit (R-41) | Nobody has looked at what the tooling pulls in. | Ran it for the web app and recorded the result. Not triaged. |
| Release notes, a tag, a changelog | There has never been a release. | This repository's are the first. |

**Decisions I had to make that are not mine to make.** Each is written down as
a criterion so that it can be reviewed and overturned:

| Question nobody answered | What I assumed | Where |
|---|---|---|
| May one tenant ever see another's results? | Never. | AC-SEC-01, 02 |
| What does a fit/gap report mean after the vacancy changes? | It is stale and must be regenerated. | AC-FG-04 |
| What is stored for a skill the interview did not reach? | No level: "not assessed". | AC-PF-01 |
| May an assessor rate a skill the AI could not? | Yes, and the override records that the AI level was empty. | AC-FG-02 |
| What does saving an edit form mean for a skill that is no longer on it? | It is removed. | AC-ASM-01, AC-VAC-01 |
| Does editing an assessment change interviews already held? | It should not. Not enforced yet. | AC-ASM-03 (R-16) |
| When does an invite link stop working? | At some point. Not enforced yet. | AC-INV-02 (R-17) |
| Who may watch a live interview? | Assessors only. | AC-SEC-06 |
| What end reason is recorded when the AI closes early? | None exists. I did not invent one. | commit `a0c3395` |

## Project context beyond the code

The brief says to look around and to handle what I find as I would in
production. This is what was there.

- **The tracker holds four tickets, which are two tickets filed twice.**
  T-1 ("backend returns a framework error page for invalid routes") was closed
  as **completed**. Its duplicate was closed as **not planned**. The route it
  asks for was never added: `routes.rb` had not changed since the import. I
  treated the ticket's own text as the acceptance criterion (AC-API-01), wrote
  the check, watched it fail, and fixed it (R-23).
- **T-1 was a P0 reported as a P2.** Its example of an "invalid route" is
  `/interview/:token` on the API host. That is the candidate's invite link.
  The ticket asked for a nicer 404; the defect was that the link pointed at
  the wrong service (R-02). Triage treated the symptom.
- **T-2** ("frontend shows an empty form for non-existent resources") was
  closed as **not planned**, twice. That is a decision someone made, so I did
  not quietly implement it. I did fix the two instances that tell a lie about
  data rather than merely look bare: the candidate page (R-19) and the endless
  "generating" (R-24). The rest is listed as R-40 for the product owner to
  revisit.
- **The repository named the company and a client in 25 files**: comments,
  database names, a registry path, hostnames, a node pool, the page header.
  The brief's one hard rule forbids that in a public repository. A commit that
  removes a name leaves it readable in the history before it, so I removed
  them from every commit's tree, starting with the import. A gate now fails on
  either name in any file or commit message; it compares hashes, so the names
  are not in the gate either.
- **No release has ever been cut.** No tag, no notes, no changelog.
- **The code says this service shares a signing key and a database with
  another service** ("the core API" in the scrubbed comments). No document
  describes that dependency. It is part of R-37.

## Assumptions

There was no channel for questions, so these are the calls I made.

1. **Roles, not names, as owners.** I do not know the team. Risks I can act on
   carry my name. The rest name a role "to be named at sign-off", because a
   risk owned by nobody in particular is owned by nobody.
2. **"Client" means the organization assessing candidates**, and its
   candidates are third parties who never agreed to anything with us.
3. **R-12 is P1, not P0.** See the note under the table.
4. **Confidence follows PRD-01 section 5 literally.** I implemented the rule as
   written, including its corners (a covered skill probed once is "low").
5. **The invite token is the candidate's credential**, so its holder may end
   their own interview, and may not do anything else.
6. **I kept T-1's response shape** although it differs from every other error
   the API returns. Changing a written requirement on my own would be the same
   habit this audit criticises.
7. **I did not ask for model credentials.** With them, R-12 is an afternoon.
8. **History.** The brief asks for a fresh repository with no link to the
   source. I replayed my commits onto a new import, keeping each message and
   timestamp, with the names removed throughout. The API red baseline and the
   gates were re-run at the same commit in the new history and match what is
   recorded.
9. **"The product" in the confidentiality rule means its brand name.** The
   rule forbids naming the company, the product or any client. The code
   describes what it does as an "AI interview" in about a hundred places across
   37 files: a package name, a database schema, the page title. I read that as
   a description and left it. The brief has me import the code as it stands,
   and renaming a database schema to avoid a generic phrase would be a
   behaviour change nobody specified. The gate's denylist therefore holds the
   company's name and the client's. If the product has a brand name beyond
   that phrase, I did not find it in the source.

## What I did not look at

Stated so that silence is not read as a pass.

- Load, concurrency and cost: how many interviews at once, what one costs.
- Audio quality, browser and device coverage, accessibility.
- Security beyond the findings above. This was a code read, not a penetration
  test. The API's gems were not audited (R-41).
- Whether the AI's ratings are *good*. The net checks what the code does with a
  rating, not whether the rating is right. That needs human-rated transcripts
  to compare against, which do not exist.
- Indonesian-language interviews. The prompt compiler supports them; I read
  only the English path closely.
