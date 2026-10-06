# The quality net

Two halves, one status.

| Half | What it is | Where |
|---|---|---|
| Workflow gate | A change cannot merge without a spec, acceptance criteria, a design plan and tests; a release cannot ship with an open P0/P1 | `quality/gate/`, `.github/` |
| Test net | Checks that go red on real defects in data, tenancy, session lifecycle and the web/API seam | `api/spec/`, `web/src/**/*.test.*`, `contracts/` |

CI (`.github/workflows/quality-net.yml`) runs all of it on every push and pull
request and reports a single status, `quality-net`.

## Run it

```bash
# API suite: Postgres, Redis and Ruby in containers, nothing installed on the host
docker compose -f docker-compose.test.yml run --rm api-test

# Web suite
cd web && npm ci && npm run typecheck && npm test && npm run build

# Gates (Node 22, no dependencies)
node --test quality/gate/gate.test.mjs        # the gates' own tests
node quality/gate/traceability.mjs            # criteria <-> tests, both ways
node quality/gate/confidentiality.mjs         # no company or client names
PR_BODY="$(cat my-pr.md)" node quality/gate/dor.mjs --base origin/main --head HEAD
node quality/gate/release.mjs --tag v1.0.0 --net success
```

## The pieces

| Check | Protects against | Deliberately does not cover |
|---|---|---|
| `api/spec/boot_spec.rb` | Code that loads on a laptop and crashes production at boot | Missing environment variables or infrastructure |
| `api/spec/requests/tenant_isolation_spec.rb`, `tenant_scoping_guard_spec.rb` | One tenant reading or changing another's results; the next unscoped lookup | Tenancy in workers and sockets (R-14) |
| `api/spec/services/portfolio_generator_spec.rb` | Model output becoming stored ratings without checks: invented levels, dropped skills, trusted confidence, partial writes | Whether the model's ratings are *good* (R-12) |
| `api/spec/requests/fit_gap_spec.rb` | Wrong or stale comparisons reaching a hiring decision | Narrative text quality |
| `api/spec/requests/session_lifecycle_spec.rb`, `spec/channels/audio_websocket_*` | Sessions ended, mislabelled or killed for the wrong reason | Audio, the live model connection (R-12) |
| `api/spec/channels/coverage_websocket_auth_spec.rb` | Someone who is not an assessor watching a live interview | — |
| `api/spec/channels/audio_websocket_transcript_spec.rb` | A turn of the interview lost without a trace | A lost final turn when the database is down for every write |
| `api/spec/workers/coverage_analyzer_worker_spec.rb` | A skill marked covered that the analyzer never judged covered | Whether the analyzer judges well (R-12) |
| `api/spec/requests/write_honesty_spec.rb` | A success response for a write that did not happen | — |
| `contracts/` + `contract_spec.rb` + web component tests | The web and the API drifting apart on a field name or type | Endpoints with no fixture yet |
| `web/src/pages/interview/*.test.tsx`, `hooks/useAudioWebSocket.test.ts` | Telling a candidate a failed interview is complete | Browser audio capture and playback |
| `quality/gate/dor.mjs` | Work that starts from a ghost spec | Whether the spec is *right*: that needs a human |
| `quality/gate/traceability.mjs` | A requirement nobody tests; a test nobody asked for; a silent "we skipped that" | — |
| `quality/gate/release.mjs` | Shipping with an open P0/P1 or an undisclosed risk | Deploying: it gates the tag, not the cluster (R-28) |
| `quality/gate/confidentiality.mjs` | Naming the company or a client in a public repo | Images and binaries |
| `quality/gate/gate.test.mjs` | A gate that has stopped blocking; a lockfile that drifted from the manifest; a documented command that does not run | — |

## Extend it

**A new behaviour.** Add a criterion to `docs/specs/acceptance-criteria.md`
(`### AC-AREA-NN — title`, `Source`, `Status: enforced`, Given/When/Then). Write
a test whose name ends with `[AC-AREA-NN]`. Run
`node quality/gate/traceability.mjs --write` and commit the matrix.

**A response the web reads.** Add `contracts/<name>.json`, assert it in
`api/spec/requests/contract_spec.rb`, and render it in a web test via
`@contracts/<name>.json`.

**A risk you are not fixing now.** Add it to `quality/risk-register.json` with
an owner and a mitigation. If a criterion describes it, mark that criterion
`Status: deferred (R-NN)`. An open P0/P1 blocks every release until it is fixed
or accepted with `accepted_by` and `expires`.

**A fix.** Flip the risk to `"status": "fixed"`. The gate refuses that unless an
enforced, tested criterion backs it, so "fixed" always means "there is a check".

## Rules the net holds itself to

- Tests are tagged with the criterion they prove; untagged checks are allowed
  (guards, smoke tests) but tagged ones must resolve.
- Removing or skipping a check needs a `## Net change` section in the pull
  request saying why. In CI a focused or skipped test fails the run.
- Nothing calls the model or the network. Model output is injected, because the
  point is what the code does with an answer it should not trust.
