# The Product
The initial product specification is the wiki of the source repository this copy was made from (two PRDs). It is not reproduced here; `docs/specs/acceptance-criteria.md` cites it as PRD-01 and PRD-02.

# The Platform

A two-service application used for the Product Engineer case study. It is provided as a single repository so the whole thing clones, runs, and releases as one unit.

```
.
├── api/    # Backend service (Ruby on Rails, PostgreSQL, Redis/Sidekiq)
└── web/    # Frontend web app (React 18 + TypeScript, Vite, Tailwind)
```

The two services run together: the web app talks to the API over REST and WebSocket.

## Running it locally

Each service has its own setup guide. Run the API first, then the web app pointed at it.

1. **API** — see [`api/README.md`](api/README.md). Rails app; needs Ruby (see `api/.ruby-version`), PostgreSQL, and Redis. It serves on `http://localhost:3001`.
2. **Web** — see [`web/README.md`](web/README.md). Vite app; `npm install`, copy `.env.example` to `.env`, point `VITE_API_BASE_URL` at the API, then `npm run dev`. It serves on `http://localhost:5173`.

## Quality net and assessment

This copy of the platform has been assessed, hardened and put behind a release gate.

| Read | For |
|---|---|
| [`assessment/01-audit.md`](assessment/01-audit.md) | The state of the platform: 41 risks, ranked, with what is fixed and what remains |
| [`assessment/02-quality-system.md`](assessment/02-quality-system.md) | The quality net, how to run it, and how it went from red to green |
| [`assessment/03-release-decision.md`](assessment/03-release-decision.md) | Whether v1.0.0 may ship, and why |
| [`RELEASE_NOTES.md`](RELEASE_NOTES.md) | What the release claims, and every known risk in it |
| [`quality/README.md`](quality/README.md) | Running and extending the net |

```bash
docker compose -f docker-compose.test.yml run --rm api-test   # API suite, in containers
cd web && npm ci && npm run typecheck && npm test             # web suite
node --test quality/gate/gate.test.mjs                        # the gates' own tests
```

## Notes for the case study

- This is the codebase you assess, harden, and release. Treat it as a version about to ship to a client.
- Work in the `/assessment` folder at the repo root for your written deliverables; code changes go in `api/` or `web/`.
- See the case-study brief you were given for what to produce and how it is evaluated.
