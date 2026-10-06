# 03 — Release decision: v1.0.0

## The decision

**v1.0.0 is BLOCKED. I do not recommend shipping it to a client.**

Every automated check is green. Both P0 defects and 14 of the 15 P1 defects
are fixed. The one that remains is that nobody has run a real AI interview on
this build (R-12), and the interview is the product. I am not willing to tell
a client "it works" about the one path I have never seen work.

This is my own release and I am the one blocking it.

## What the gate checked and what it found

The release gate (`quality/gate/release.mjs`) runs when a tag is pushed.

| The gate checked | Result |
|---|---|
| The quality net at the tagged commit: API suite, web suite with type-check and production build, the gates' own tests, confidentiality | Green: 58 of 58, 19 of 19, 23 of 23 |
| Release notes exist for exactly this version | Present |
| Traceability, both ways | Complete: 34 enforced criteria each have a test; every test tag names a criterion; 6 deferred criteria each point at an open, owned risk |
| Every risk that is not fixed is disclosed in the release notes | 18 of 18 |
| No open P0 | None open. 2 found, 2 fixed |
| No open P1 | **One open: R-12.** 15 found, 14 fixed |

The verdict, as the gate prints it:

```
# ⛔ v1.0.0 is BLOCKED

This version must not ship. It is blocked by:

- R-12 (P1) No evidence that a live AI interview works on this build: PRD-01
  section 7 says engineers must test the failure modes, and nothing does:
  open P1. Fix it, or record an explicit risk acceptance with an owner
```

The same verdict is on the tag: the
[release page](https://github.com/ninditya/ninditya-quality-gate/releases/tag/v1.0.0)
is titled "v1.0.0 — BLOCKED" and published as a pre-release so it is never
shown as the latest version, the tagged commit carries a red `release-gate`
status, and the
[workflow run](https://github.com/ninditya/ninditya-quality-gate/actions/workflows/release-gate.yml)
is red. In that run the quality net itself is green at the tag; the release
gate is what blocks.

## Why I agree with the gate

A gate that blocks on a rule can be argued with. These are my reasons, apart
from the rule.

**The net cannot see this, on purpose.** Nothing in it calls the model. It
injects the model's output and checks what the code does with it. That was the
right design for the defects I found, which were all in what the code did with
an answer. It also means a green net says nothing about whether a real
conversation starts, continues, and ends.

**My fixes went into that path.** Reconnect handling (R-07), when a closing
phrase ends the interview (R-26), how a session ends and why (R-08), and the
rating prompt (R-05) all changed. Each is covered against a stand-in for the
model connection. None has met the real one.

**I have already been wrong in exactly this way during this exercise.** My
README documented a test command I had never run as written. When I ran it, it
failed. "It should work, I just have not run it" is the claim I would be
making about the interview, and this exercise already showed me what that
claim is worth.

**What is at stake is someone's interview.** A candidate gets one. If the
session dies at minute twelve, the cost lands on a person outside the company
who cannot ask for a retry, and on the client whose name was on the invitation.

## What would change the decision

Either of two things. Both are recorded in `quality/risk-register.json`,
which is what the gate reads, so neither can happen by saying so.

**1. Run the interview.** [uat-live-interview.md](uat-live-interview.md) is
the script: one end-to-end interview on staging with model credentials, the
six failure modes PRD-01 lists, and the fixes that touch the live path. About
half a day for an engineer and the product owner. If it passes, R-12 is
recorded as accepted by the person who watched it, with an expiry date for
replacing the manual run with an automated one. Then tag again; the gate will
answer RELEASABLE without anyone editing the gate.

**2. Accept the risk explicitly.** Someone with the authority to accept it on
the client's behalf records:

```json
{
  "id": "R-12",
  "status": "accepted",
  "owner": "<who watches the first live interviews>",
  "mitigation": "<for example: first five interviews are internal, observed live, with a human interviewer on standby>",
  "accepted_by": "<name and role>",
  "expires": "<date by which the UAT run must have happened>"
}
```

The gate then lets the version through and prints that acceptance, with the
name, on the release page. **I am not that person.** The delivery model has
every gate co-signed by two roles so that nobody passes their own work
downstream, and accepting a risk in my own release would be precisely that.

If I were asked which, I would say the first. It costs half a day.

## What "blocked" does and does not mean

- It means the **tag** v1.0.0 is not marked releasable.
- It does not mean the work is unusable. Everything is on `main` and green. I
  would run it internally, and I would use it for the UAT run itself.
- It does not mean R-12 is the only thing between this and a client. See the
  next section.

## If it ships: who owns what

18 risks remain, each with an owner and a mitigation in the register and in
the release notes. Besides R-12, three of them I would raise with the client
before they find them:

| Risk | Why it needs a conversation, not just an owner | Owner |
|---|---|---|
| R-37 | A candidate's voice is recorded and sent to a third-party model, with no consent step and no retention rule. The severity scale rates this P2 because it measures function and data. It has no row for legal exposure | Product owner |
| R-36 | 21 of the 40 acceptance criteria are my reading of what the product should do. The checks enforce them faithfully, which only helps if they are right | Product owner |
| R-28 | The deploy manifests use the `latest` image tag and carry no secrets. What runs cannot be traced back to this tag, so this gate does not yet control what reaches the cluster | Tech lead |

The other fourteen are P2 with a stated mitigation. I chose not to fix them in
the time available, and each is a decision recorded in the register, not an
oversight.

## How the release process works

It is not specific to this version.

1. Add a `## vX.Y.Z` section to `RELEASE_NOTES.md` stating what the version
   claims to deliver and listing every risk that is not fixed.
2. Push the tag.
3. `.github/workflows/release-gate.yml` runs the whole quality net against
   that exact commit, then runs `release.mjs`.
4. The verdict is written in three places, readable without opening a log:
   the release page title, a status on the tagged commit, and the run itself.

To check any version locally:

```bash
node quality/gate/release.mjs --tag v1.0.0 --net success
```

## The limits of this gate

- **It gates the tag, not the deploy.** Nothing stops someone deploying `main`
  by hand (R-28).
- **A risk acceptance is a field in a file.** The gate checks that it is
  complete and not expired. It cannot check that the named person agreed. That
  needs a required review on any change to the risk register.
- **Severity is a human judgement.** A P1 mislabelled as P2 passes. The audit
  shows my reasoning for each so that the labels can be challenged.
- **It trusts the register to be complete.** A risk nobody wrote down does not
  block anything. The audit lists what I did not look at.
