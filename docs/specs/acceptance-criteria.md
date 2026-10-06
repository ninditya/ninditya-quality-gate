# Acceptance criteria

The testable half of the spec. Every criterion has an id, a source, and a
status. The quality net reads this file:

- a change that touches runtime code must cite at least one id from here
  (`quality/gate/dor.mjs`);
- every `enforced` criterion must be exercised by a test tagged with its id,
  and every tag in a test must exist here (`quality/gate/traceability.mjs`);
- a `deferred` criterion must point at an open entry in
  `quality/risk-register.json`, so "we chose not to check this" is always a
  visible, owned decision.

Sources: **PRD-01** (AI interview behaviour) and **PRD-02** (end-to-end
simulation) are the product wiki pages; **T-1** is the closed tracker ticket
"Backend returns framework error page for invalid routes"; **T-2** is the
closed ticket "Frontend shows empty form for non-existent resources".
**Derived** means no upstream document states the rule: it was written during
the audit because the build needed an answer. Derived criteria are the audit's
"missing spec" findings turned into something reviewable, and each one needs a
product sign-off (see `assessment/01-audit.md`).

Format: `### <id> — <title>`, then `Source`, `Status`, and Given/When/Then.

## Operations

### AC-OPS-01 — The service boots the way production boots it
- Source: Derived
- Status: enforced
- Given the application code as committed
- When every class is eager-loaded, as production does at boot
- Then loading succeeds without error

### AC-OPS-02 — A release build installs exactly the dependencies that were tested
- Source: Derived
- Status: enforced
- Given the web app's dependency manifest
- When dependencies are installed for a build
- Then a committed lockfile fixes every version, and it matches the manifest

### AC-OPS-03 — The documented setup works as written
- Source: Derived
- Status: enforced
- Given a fresh checkout
- When an engineer follows the READMEs
- Then the scripts they are told to run are executable, and the web app's default API address is the one the API listens on

## Invitation

### AC-INV-01 — The invite link opens the interview page
- Source: PRD-02 Phase 1 ("Link: https://app…/interview/<token>")
- Status: enforced
- Given an assessor creates a session for a candidate
- When the API returns the invite link
- Then the link is on the web app's host at `/interview/<token>`, not on the API's host

### AC-INV-02 — An invite link stops working at some point
- Source: Derived (no document says how long a link is valid or whether it is single-use)
- Status: deferred (R-17)
- Given an invite link that was never used, or whose interview has ended
- When it is opened after its validity window
- Then the candidate is told the link has expired and no session starts

## Tenancy and access

### AC-SEC-01 — A tenant cannot read another tenant's results
- Source: Derived (the schema carries `tenant_id`; no document states the isolation rule)
- Status: enforced
- Given a portfolio or fit/gap report that belongs to tenant A
- When an assessor of tenant B requests it, exports it, or runs a fit/gap on it, by id
- Then the API answers 404 and returns none of its content, and no job is queued

### AC-SEC-02 — A tenant cannot change another tenant's ratings
- Source: Derived
- Status: enforced
- Given a portfolio skill that belongs to tenant A
- When an assessor of tenant B posts an override for it
- Then the API answers 404 and no override is stored

### AC-SEC-03 — A login is bound to the user's own organization
- Source: Derived
- Status: enforced
- Given a user who belongs to organization A
- When they log in, whatever tenant header the request carries
- Then the token is scoped to organization A, never to a tenant named by the caller

### AC-SEC-04 — Tenant-less tables are only reached through a tenant scope
- Source: Derived (structural guard for the class of defect behind AC-SEC-01/02)
- Status: enforced
- Given the controllers as committed
- When they look up portfolios, portfolio skills or fit/gap reports
- Then every lookup goes through a scope that names the tenant

### AC-SEC-05 — Tenant scoping fails closed
- Source: Derived
- Status: deferred (R-14)
- Given code running with no tenant resolved
- When it queries a tenant-scoped model
- Then it gets no rows, instead of every tenant's rows

### AC-SEC-06 — Only assessors can watch a live interview
- Source: Derived
- Status: enforced
- Given a validly signed token whose role is not an assessor role
- When it connects to the live coverage socket of a session in its tenant
- Then the connection is refused

## Assessment and vacancy setup

### AC-ASM-01 — Removing a skill from an assessment removes it
- Source: PRD-02 Phase 1 (the assessor defines the skills the interview covers)
- Status: enforced
- Given an assessment with skills A, B and C
- When the assessor saves the edit form with B removed
- Then the stored assessment has exactly A and C, and the response lists exactly A and C

### AC-ASM-02 — A delete that did not happen is not reported as done
- Source: Derived
- Status: enforced
- Given an assessment that has sessions and therefore cannot be deleted
- When a delete is requested
- Then the API answers 409 with the reason, and the assessment still exists

### AC-ASM-03 — Editing an assessment does not rewrite interviews already held
- Source: Derived (no document says what an edit means once sessions exist)
- Status: deferred (R-16)
- Given an assessment with at least one started or ended session
- When its skills or anchors are edited
- Then past sessions keep the definitions they were interviewed against

### AC-VAC-01 — Removing a skill from a vacancy removes it
- Source: PRD-02 Phase 5 (fit/gap compares against the vacancy's required skills)
- Status: enforced
- Given a vacancy with required skills A and B
- When the assessor saves the edit form with B removed
- Then the stored vacancy requires exactly A

### AC-VAC-02 — Choosing a level for one skill never changes another
- Source: Derived
- Status: enforced
- Given a form with level pickers for two skills
- When the assessor clicks a level label on the second skill
- Then only the second skill's level changes

## Interview session

### AC-SES-01 — An interview that never started cannot be ended from the invite link
- Source: PRD-02 Session End (a session ends from an active interview)
- Status: enforced
- Given a pending session that no candidate has joined
- When the unauthenticated audio-complete endpoint is called with its invite token
- Then the API answers 409, the session stays pending, and no portfolio is created or queued

### AC-SES-02 — "All covered" is recorded only when all skills are covered
- Source: PRD-02 Session End ("N8 detects: ALL configured skills = covered → end_reason = all_covered")
- Status: enforced
- Given an active session where at least one configured skill is not covered
- When the session is ended through the automatic end path
- Then the stored end reason is not `all_covered`

### AC-SES-03 — A dropped connection does not end an interview the candidate rejoined
- Source: PRD-02 Reconnection ("the candidate hears no interruption")
- Status: enforced
- Given an active interview whose browser connection dropped and reconnected
- When the grace period of the dropped connection expires
- Then the session is still active and no portfolio has been generated

### AC-SES-04 — The time limit ends the interview even in silence
- Source: PRD-02 (time limit, time warning)
- Status: deferred (R-18)
- Given an active interview that has reached its time limit
- When nobody speaks
- Then the session still ends with reason `time_ceiling`

### AC-SES-05 — A courtesy phrase does not end the interview
- Source: PRD-01 §2 rule 7 (wrap up when all skills are covered or on a time warning)
- Status: enforced
- Given an active interview with skills still uncovered and no wrap-up signalled
- When the AI says a phrase such as "good luck" or "thank you for your time" in passing
- Then the interview continues

## Candidate experience

### AC-INT-01 — A candidate is never told a failed load was a completed interview
- Source: Derived; T-2 covers the assessor pages but was closed as not planned
- Status: enforced
- Given an invite link that is invalid, or an interview that could not be loaded
- When the candidate opens it
- Then the page says what went wrong, and does not say "Interview Complete"

### AC-INT-02 — A lost or failed interview is reported as failed
- Source: Derived
- Status: enforced
- Given an interview that ends because of an error, a refused connection, or exhausted reconnects
- When the page shows its final state
- Then it reports a failure and what to do next, not completion

### AC-INT-03 — Ending an interview is reported as complete only once the server recorded it
- Source: Derived (found while fixing AC-INT-02)
- Status: enforced
- Given a candidate who ends the interview while the live connection is down
- When the page shows its final state
- Then the end was reported to the API by another route, or the page says the interview was not completed

## Transcript

### AC-TR-01 — A transcript with a missing turn says so
- Source: Derived (PRD-01 §5 generates every rating from the transcript; no document says what happens when a turn cannot be stored)
- Status: enforced
- Given an interview in which a turn could not be stored
- When the write still fails after retrying, or the stored turns have a hole in their numbering
- Then the session is marked as having an incomplete transcript, and the portfolio and its export say so

### AC-TR-02 — Two connections never cost a turn
- Source: Derived
- Status: enforced
- Given two connections of one session that give different turns the same number
- When both are stored
- Then both turns are in the transcript; only an exact replay of a stored turn is skipped

## Portfolio

### AC-PF-01 — A skill that was not assessed has no level
- Source: PRD-01 §5 (levels come from transcript evidence); schema `fit_result = not_assessed`
- Status: enforced
- Given a configured skill that was never discussed, or that the model could not rate
- When the portfolio is generated
- Then the skill is stored with no AI level and shown as "Not assessed", never as L1

### AC-PF-02 — Every configured skill appears in the portfolio
- Source: PRD-01 §5 ("For EACH skill in the coverage map")
- Status: enforced
- Given the model's answer omits a configured skill
- When the portfolio is saved
- Then that skill is still present, marked not assessed

### AC-PF-03 — Confidence follows the coverage rule
- Source: PRD-01 §5 (high: probe_count ≥ 3 and covered; medium: probe_count = 2 or partial; low: otherwise)
- Status: enforced
- Given a skill's final coverage state and probe count
- When the portfolio is generated
- Then confidence is computed from them by the rule, whatever the model answered

### AC-PF-04 — A failed regeneration leaves the previous portfolio intact
- Source: Derived
- Status: enforced
- Given a portfolio with ratings and assessor overrides
- When regeneration fails part-way
- Then the previous ratings and overrides are all still there

### AC-PF-05 — No candidate speech means no ratings
- Source: PRD-01 §5 (evidence is quotes from the candidate)
- Status: enforced
- Given a session that ended with no candidate turn in the transcript
- When the portfolio is generated
- Then the model is not asked to rate anything and every skill is not assessed

### AC-PF-06 — "Generating" is only reported while something is generating
- Source: Derived; related to T-2
- Status: enforced
- Given a session that has no portfolio
- When its portfolio is requested
- Then the API says it is not available, not that it is being generated

### AC-PF-07 — Evidence quotes are things the candidate said
- Source: PRD-01 §5 ("quotes from the CANDIDATE")
- Status: enforced
- Given the evidence the model returns for a skill
- When a quote does not appear in the candidate's turns
- Then it is not stored or shown as evidence; it is kept apart and labelled as not found in the transcript

## Fit/gap

### AC-FG-01 — Levels are compared by rule
- Source: PRD-02 Phase 5 (match / gap / exceed)
- Status: enforced
- Given a candidate level and a required level for a skill
- When the report is generated
- Then the result is match, gap or exceed with the signed difference

### AC-FG-02 — An unrated skill is "not assessed", never a gap
- Source: schema `fit_result = not_assessed`; follows from AC-PF-01
- Status: enforced
- Given a required skill the candidate has no level for
- When the report is generated and shown
- Then the result is not assessed, with no candidate level

### AC-FG-03 — A human override is visible as one
- Source: PRD-02 Phase 5 (assessor reviews and may override)
- Status: enforced
- Given a skill whose level came from an assessor override
- When the report is generated and shown
- Then the comparison is flagged as overridden and the table marks it

### AC-FG-04 — A report is never served against requirements that have changed
- Source: Derived
- Status: enforced
- Given a stored report for a portfolio and a vacancy
- When the vacancy's required levels change afterwards
- Then the old report is not served; a new one is generated

### AC-FG-05 — The report shows the required level
- Source: PRD-02 Phase 5 (table: Skill / Required / Candidate / Result)
- Status: enforced
- Given a report from the API
- When the web app renders the comparison table
- Then the Required column shows the vacancy's level for each skill

## API surface

### AC-API-01 — Unknown routes answer JSON 404
- Source: T-1 (closed as completed; the route was never added)
- Status: enforced
- Given a path the API does not serve
- When it is requested
- Then the response is 404 JSON `{"error": "Route not found", "status": 404}`, never an HTML error page

### AC-API-02 — Responses the web depends on keep their shape
- Source: Derived (structural guard for the web/API seam)
- Status: enforced
- Given the fixtures in `contracts/`
- When the API produces the corresponding response
- Then it has exactly the fixture's fields and types

### AC-AUTH-01 — A wrong password shows the login error
- Source: Derived
- Status: enforced
- Given the login form
- When the API rejects the credentials
- Then the form stays on screen with its error message

## AI interview behaviour

### AC-AI-01 — The interviewer probes, challenges and wraps up as specified
- Source: PRD-01 §1, §7 ("Engineers must test for these failure modes")
- Status: deferred (R-12)
- Given a scripted candidate conversation
- When the interviewer responds
- Then none of the PRD-01 §7 failure modes occur
