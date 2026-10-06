# Release notes

Whether a version may ship is decided by the release gate, not by this file.
Pushing a tag runs the whole quality net against that commit and publishes
the verdict on the tag's release page as **RELEASABLE** or **BLOCKED**, with
the reasons. These notes say what a version claims; the gate says whether to
believe it.

## v1.0.1 — 2026-10-06

A correction to v1.0.0, then three fixes.

### Why there is a v1.0.1

v1.0.0 listed three risks as P2 that the severity scale puts at P1. Each is a
data-integrity issue, and the scale says any of those is at least P1. I had
rated them lower because I had read them in the code and not seen them happen.
The release gate reads the severity it is given, so it did not block on them.
They are re-rated and fixed here. The reasoning is in
`assessment/03-release-decision.md`.

### What this version claims to deliver, on top of v1.0.0

**Evidence means the candidate said it.**

- A quote counts as evidence only if it is found in the candidate's own turns
  of the transcript. A "quote" the model wrote itself is kept apart and shown
  under "Not found in the transcript". It used to be shown as evidence (R-13).

**A lost piece of transcript is visible.**

- A transcript turn that fails to store is retried. If it is still lost, the
  session is marked, and the portfolio page and the PDF export say the ratings
  came from an incomplete transcript. It used to be logged and forgotten.
- When two connections of one interview give different turns the same number,
  both are kept. The second used to be discarded as a duplicate (R-35).

**"Covered" means the analyzer judged it covered.**

- A skill is no longer promoted to "covered" for having been probed often. It
  stays "partial" until the coverage analyzer judges the evidence sufficient,
  as the product spec requires. Its rating then shows medium confidence, and
  an interview that never returns to it ends on time, not as "all skills
  covered" (R-34).

**The gate is enforced, not advisory.**

- `main` requires a pull request and a passing `quality-net` status, with no
  bypass. A change the net rejects cannot be merged.
- The net is now 71 API checks and 23 web checks.

### What this version does not claim

The same three things as v1.0.0, and the first is still the reason it is
blocked:

- **That a live AI interview works.** No interview has been run against the
  real model on this build (R-12). The three fixes above are verified against
  a stand-in for the model, like the others.
- That the AI's ratings are accurate.
- That it is ready to deploy from the manifests in the repository (R-28).

One consequence of the coverage fix is not yet measured: interviews may run
closer to their time limit. That needs a live run too.

### Known risks shipping with this version

Every risk that is not fixed, with its owner. Details, evidence and
mitigations are in `quality/risk-register.json` and
`assessment/01-audit.md`.

| Risk | Severity | What | Owner |
|---|---|---|---|
| R-12 | **P1** | No evidence that a live AI interview works on this build | Product owner |
| R-37 | P2 | No spec for candidate consent, recording retention, login, tenancy, export contents or rate limits | Product owner |
| R-36 | P2 | The acceptance criteria were written during the audit and 23 of them await product sign-off | Product owner |
| R-14 | P2 | Tenant scoping returns every tenant's rows when no tenant is resolved | Tech lead |
| R-39 | P2 | The web app falls back to a build-time developer token when nobody is signed in | Tech lead |
| R-16 | P2 | Editing an assessment changes what past interviews were held against | Product owner |
| R-17 | P2 | Invite links never expire | Product owner |
| R-18 | P2 | The time limit is enforced only when someone speaks | Quality owner |
| R-33 | P2 | The fit/gap page re-queues generation on every poll and has no failed state | Quality owner |
| R-29 | P2 | Calls to the analysis model are configured to retry and do not | Quality owner |
| R-32 | P2 | Creating an assessment reports the system prompt as generated before it exists | Quality owner |
| R-28 | P2 | Deploy manifests use the `latest` image tag, disagree on the environment and carry no secrets | Tech lead |
| R-40 | P2 | Assessor pages show an empty form for a record that does not exist | Product owner |
| R-41 | P2 | Dependencies were never audited; 11 advisories in build and test tooling are untriaged | Quality owner |
| R-30 | P2 | The signup screen calls an endpoint that does not exist | Quality owner |

### Upgrade notes

- **Two migrations, both additive.** `portfolio_skills.unverified_evidence`
  and `sessions.transcript_incomplete`.
- **Portfolios generated before this version keep their evidence unchecked**
  until they are regenerated. There is still no endpoint for regenerating a
  completed portfolio.
- **Coverage states already stored are not rewritten.** A skill promoted on
  probe count in a past interview stays "covered" in that interview's record.

## v1.0.0 — 2026-10-06

> Superseded by v1.0.1. Three risks listed in this section as P2 (R-13, R-34,
> R-35) were under-rated. They are P1, and v1.0.1 fixes them. The section is
> kept as it was released.

The first release. It takes the platform as received, which could not start
in production, to a version whose known P0 and P1 defects are fixed and held
by automated checks.

### What this version claims to deliver

**The service starts and candidates can reach their interview.**

- The API boots under eager loading, as production loads it.
- The invite link opens the interview page on the web app. It used to point
  at the API, where no such page exists.

**One client's data stays with that client.**

- Portfolios, ratings, overrides, fit/gap reports and exports can only be
  reached by the tenant that owns them.
- A login is tied to the account's own organization. The caller can no longer
  choose a tenant with a request header.
- Only assessors can watch a live interview. The live view used to accept any
  role in the tenant.

**A rating means something was measured.**

- A skill that was not discussed, or that could not be rated, is stored with
  no level and shown as "Not assessed". It used to be stored as L1 and
  reported as a gap.
- Every skill on the assessment appears in the portfolio, whatever the model
  returned.
- Confidence is computed from how thoroughly the skill was covered, by the
  rule in the product spec. The model's own claim is ignored.
- A failed regeneration leaves the previous ratings and overrides intact.
- An assessor can rate a skill the AI could not.

**An interview ends when it should, for the reason recorded.**

- A dropped connection no longer ends an interview the candidate has rejoined.
- A courtesy phrase from the AI no longer ends the interview.
- An interview that never started cannot be ended from the invite link.
- "All skills covered" is recorded only when they are. An interview that ran
  out of time is recorded as that.

**What the screen says is what happened.**

- A candidate is told the interview is complete only when the server ended it
  normally. A bad link, a failed load, a lost connection and an interview
  that ended on an error each say so, and say what to do.
- Removing a skill from an assessment or a vacancy removes it.
- Choosing a level for one skill no longer changes another skill.
- The fit/gap table shows the required level and marks ratings that came from
  an assessor.
- A fit/gap report is regenerated when the vacancy's requirements have
  changed since it was made.
- A delete that was refused is reported as refused.
- A wrong password shows the login error.
- Unknown API paths answer JSON 404.

**The team can tell whether the next change is safe.**

- A quality net runs on every push and pull request: 58 API checks, 19 web
  checks, contract fixtures shared by both services, and the gates.
- A pull request that changes runtime code cannot go green without a linked
  spec, acceptance criteria, a design plan and a test.
- A release cannot be marked releasable with an open P0 or P1, an undisclosed
  risk, or a requirement without a test.

### What this version does not claim

- **That a live AI interview works.** No interview has been run against the
  real model on this build (R-12). Everything above about interviews is
  verified against a stand-in for the model.
- That the AI's ratings are accurate. The checks cover what the code does
  with a rating, not whether the rating is right.
- That it is ready to deploy from the manifests in the repository (R-28).

### Known risks shipping with this version

Every risk that is not fixed, with its owner. Details, evidence and
mitigations are in `quality/risk-register.json` and
`assessment/01-audit.md`.

| Risk | Severity | What | Owner |
|---|---|---|---|
| R-12 | **P1** | No evidence that a live AI interview works on this build | Product owner |
| R-37 | P2 | No spec for candidate consent, recording retention, login, tenancy, export contents or rate limits | Product owner |
| R-36 | P2 | The acceptance criteria were written during the audit and 21 of them await product sign-off | Product owner |
| R-14 | P2 | Tenant scoping returns every tenant's rows when no tenant is resolved | Tech lead |
| R-39 | P2 | The web app falls back to a build-time developer token when nobody is signed in | Tech lead |
| R-13 | P2 | Evidence quotes are not checked against the transcript | Product owner |
| R-35 | P2 | A transcript turn that fails to save is logged and dropped | Quality owner |
| R-34 | P2 | A skill can become "covered" on probe count alone | Product owner |
| R-16 | P2 | Editing an assessment changes what past interviews were held against | Product owner |
| R-17 | P2 | Invite links never expire | Product owner |
| R-18 | P2 | The time limit is enforced only when someone speaks | Quality owner |
| R-33 | P2 | The fit/gap page re-queues generation on every poll and has no failed state | Quality owner |
| R-29 | P2 | Calls to the analysis model are configured to retry and do not | Quality owner |
| R-32 | P2 | Creating an assessment reports the system prompt as generated before it exists | Quality owner |
| R-28 | P2 | Deploy manifests use the `latest` image tag, disagree on the environment and carry no secrets | Tech lead |
| R-40 | P2 | Assessor pages show an empty form for a record that does not exist | Product owner |
| R-41 | P2 | Dependencies were never audited; 11 advisories in build and test tooling are untriaged | Quality owner |
| R-30 | P2 | The signup screen calls an endpoint that does not exist | Quality owner |

### Upgrade notes

- **Three migrations.** `users.organization_id`; `ai_level` becomes nullable
  on portfolio skills and overrides; `sessions.audio_connection_id`.
- **`WEB_BASE_URL` is required in production.** Invite links are built from
  it. `APP_BASE_URL` is no longer read.
- **Existing accounts cannot sign in until assigned an organization.** That is
  deliberate: the alternative was to guess a tenant.
- **Ratings stored by earlier builds are not corrected.** An L1 written before
  this version may have been invented, and nothing in the data tells the two
  apart. No production data is known to exist. If any does, those portfolios
  have to be regenerated, and there is no endpoint for regenerating a
  completed portfolio; it needs a console task.
- The web app's default API address is now port 3001, the port the API
  listens on.
