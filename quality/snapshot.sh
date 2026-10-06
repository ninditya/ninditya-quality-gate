#!/usr/bin/env bash
# Records what the net says right now, as plain text, under assessment/evidence/.
# Used to keep the red-to-green story in the repository next to the commits
# that produced it. CI is the authority; this is the receipt.
#
#   quality/snapshot.sh 02-after-boot-fix "after fixing R-01"
set -uo pipefail
cd "$(dirname "$0")/.."

label="${1:?usage: quality/snapshot.sh <label> [description]}"
description="${2:-}"
out="assessment/evidence"
mkdir -p "$out"

api_log="$(mktemp)"
docker compose -f docker-compose.test.yml run --rm api-test \
  bash -lc "bundle exec rails db:create db:schema:load >/dev/null 2>&1; bundle exec rspec --no-color" > "$api_log" 2>&1
{
  echo "# API suite ${description:+— $description}"
  echo "# docker compose -f docker-compose.test.yml run --rm api-test"
  echo
  grep -E "^[0-9]+ examples," "$api_log" || echo "the suite did not run: $(grep -m1 -E 'Error|error' "$api_log")"
  echo
  grep -E "^rspec \./spec" "$api_log" | sed -E 's/^rspec \.\/(spec[^ ]+):[0-9]+ # /RED  \1  /' | sort
} > "$out/$label-api.txt"
rm -f "$api_log"

web_log="$(mktemp)"
(cd web && CI=true NO_COLOR=1 npx vitest run --reporter=verbose > "$web_log" 2>&1)
{
  echo "# Web suite ${description:+— $description}"
  echo "# cd web && npm run typecheck && npm test"
  echo
  grep -E "^ +(Test Files|Tests) " "$web_log" | sed -E 's/^ +//'
  echo
  grep -E "^ × " "$web_log" | sed -E 's/^ × /RED  /; s/ [0-9]+ms$//' | sort
  echo
  if (cd web && npx tsc --noEmit > "$web_log" 2>&1); then
    echo "typecheck: clean"
  else
    echo "typecheck: $(grep -c 'error TS' "$web_log") error(s)"
    grep "error TS" "$web_log" | cut -c1-160 | sed 's/^/RED  /'
  fi
} > "$out/$label-web.txt"
rm -f "$web_log"

{
  echo "# Gates ${description:+— $description}"
  echo
  node --test quality/gate/gate.test.mjs 2>&1 | grep -E "^# (tests|pass|fail)" | tr '\n' ' '
  echo
  node quality/gate/traceability.mjs 2>&1 | head -20
  node quality/gate/confidentiality.mjs 2>&1 | head -4
} > "$out/$label-gates.txt"

head -4 "$out/$label-api.txt" | tail -1
grep -E "^(Test Files|Tests)|^typecheck" "$out/$label-web.txt"
