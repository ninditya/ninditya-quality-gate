# UAT: one live interview, end to end

This is the run that closes R-12. It has not been done. I had no model
credentials, and nothing in the automated net talks to the model, by design:
the net checks what the code does with the model's output, never the model.

That leaves the product's main function unverified on this build. Several of
the fixes in this release touch the live path (reconnect handling, when a
closing phrase ends the interview, the rating prompt), which makes the run more
necessary, not less.

**Who runs it:** an engineer and the product owner together. Two people,
because one of them has to play a candidate while the other watches the
assessor's screen and the database.

**What it needs:** a staging deployment of the tagged version with model
credentials, two browsers, a microphone, about 45 minutes.

**What counts as done:** every row below has a result and evidence attached to
the release (transcript export, the portfolio JSON, screenshots). A row that
cannot be run is recorded as not run, with the reason.

## Setup

1. Create an assessment with three skills, 10 minute limit. Use one skill from
   the taxonomy and two custom skills, so both kinds are exercised.
2. Create a vacancy that requires those three skills at L3, L3 and L2.
3. Create a session and copy the invite link.

## Part 1 — The path works at all

| # | Do this | Expect | Checks |
|---|---|---|---|
| 1.1 | Open the invite link in a private window | The interview page on the web app's host, with the role title and "10 minutes" | R-02 |
| 1.2 | Pass the hardware check and start | The AI speaks first; the assessor's monitor shows the session as active | R-01 (the service is up in production mode) |
| 1.3 | Answer two questions on the first skill in detail | The monitor shows that skill move from "not yet" towards "partial" with a probe count | coverage analysis |
| 1.4 | Let the interview run until the AI closes it, covering all three skills | The page shows "Wrapping up", then "Interview Complete" | auto-end |
| 1.5 | Read the session row | `status = ended`, `end_reason = all_covered`, a duration | R-08 |
| 1.6 | Open the portfolio | Three skills, each with a level, quotes and a summary. Confidence matches the rule: high needs three probes and "covered" | R-05, R-06 |
| 1.7 | Compare each evidence quote with the transcript | Every quote under "Evidence" is something the candidate said. Count the ones under "Not found in the transcript": if most quotes land there, the match is too literal for how the model quotes | R-13 |
| 1.8 | Run the fit/gap against the vacancy | Required and Candidate columns both filled; result per rule | R-22 |
| 1.9 | Export the PDF | It opens, and matches the screen | export |

## Part 2 — The six failure modes PRD-01 says to test

PRD-01, section 7: "Engineers must test for these failure modes during QA."
Run a second interview and try to provoke each one.

| # | Failure mode | How to provoke it | Pass when |
|---|---|---|---|
| 2.1 | Question-list behaviour | Give a specific, unusual answer | The follow-up refers to that answer |
| 2.2 | Hollow affirmation | Listen across the interview | The AI does not open every turn with praise |
| 2.3 | Topic announcement | Listen at each change of skill | It never says "now let's talk about …" |
| 2.4 | Skipping follow-up | Give a one-line answer and stop | It probes before moving on; probe count reaches 2 before "partial" |
| 2.5 | Answering for the candidate | Ask "what do you mean?" | It rephrases without supplying an example answer |
| 2.6 | Running out of things to ask | Answer briefly throughout | It does not say it has no more questions while a skill is uncovered |

## Part 3 — The fixes that touch the live path

These are covered by automated checks against a fake model connection. This
part checks them against the real one.

| # | Do this | Expect | Checks |
|---|---|---|---|
| 3.1 | Mid-answer, turn the network off for ten seconds and on again | "Briefly reconnecting", then the interview continues. **Wait three full minutes** | The session is still active after the two-minute mark (R-07) |
| 3.2 | Reload the page mid-interview and rejoin | Same as 3.1 | R-07 |
| 3.3 | Close the tab and do not return | After two minutes the session ends with `end_reason = error`; reopening the link says the interview was interrupted, not complete | R-07, R-19 |
| 3.4 | Early on, say something that invites a courtesy ("I have an exam tomorrow") | If the AI says "good luck", the interview continues | R-26 |
| 3.5 | Leave one skill untouched and end from the candidate's button | `end_reason = manual_candidate`. The portfolio shows that skill as "Not assessed" with no level, and the fit/gap shows it as "Not assessed", not as a gap | R-05, R-08 |
| 3.6 | Turn the network off, then press End Interview | The page does not say "Interview Complete" unless the session is ended in the database | R-38 |
| 3.7 | Say nothing at all for the whole time limit | Record what happens. The server is known not to enforce the limit in silence | R-18 (expected to fail; record it) |
| 3.8 | Watch whether the AI ever says goodbye with a skill uncovered and time left | Record how often. The session now stays open in that case | R-26, and the open question in commit `1a88303` |
| 3.9 | After the reconnect in 3.1, read the transcript end to end | No turn is missing or doubled; the portfolio shows no "transcript is incomplete" warning | R-35 |
| 3.10 | Give thin answers on one skill, then move the conversation to another | The first skill stays "partial" on the monitor. Either the AI returns to it, or the interview ends on time with that skill at medium confidence. Record how long the interview ran | R-34 |

## Part 4 — Things nobody has decided

Not pass or fail. The run is the cheapest moment to collect the facts the
decisions need.

- How long did the portfolio take to generate, and what did the interview cost?
- Did the candidate at any point know they were being recorded? (R-37)
- If a quote in 1.7 was invented, how many, out of how many? (R-13)

## Recording the result

Attach the evidence to the release, then in `quality/risk-register.json`:

- everything in parts 1 to 3 passed: mark R-12 `fixed` only once AC-AI-01 has
  an automated check behind it. Until then mark it `accepted`, with the person
  who watched the run as `accepted_by` and an `expires` date for the automated
  version. The release gate reads those fields.
- anything in part 1 failed: R-12 becomes a P0 and the release stays blocked.
