#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DENO_TESTS=1

usage() {
  cat <<'EOF'
Usage: scripts/verify-agent-usage-caps.sh [--skip-deno-tests]

Verifies the self-serve server-side usage-cap implementation without deploying
or mutating external services:
  1. Checks the SQL tier/cap matrix for Default, Pro, and Power.
  2. Checks reserve/finalize RPC hardening for daily/monthly cap enforcement.
  3. Checks Realtime, transcription, Computer Use, and screen-context functions
     are wired to reserve/finalize usage when VOIYCE_ENFORCE_AGENT_USAGE_CAPS is enabled.
  4. Checks backend tests cover account-limit responses before OpenAI and
     reserve/finalize calls plus usage units for each cost-bearing capability.
  5. Runs the relevant Deno tests unless --skip-deno-tests is provided.

Options:
  --skip-deno-tests  Run static checks only.
  -h, --help         Show this help text.
EOF
}

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-deno-tests)
      RUN_DENO_TESTS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command python3
if [[ "$RUN_DENO_TESTS" -eq 1 ]]; then
  require_command deno
fi

cd "$ROOT_DIR"

log "Checking SQL tier and cap matrix"
python3 <<'PY'
from pathlib import Path
import re

root = Path.cwd()
sql_path = root / "insforge/sql/billing_schema.sql"
docs_path = root / "docs/phase-2-production-hardening.md"

sql = sql_path.read_text(encoding="utf-8")
docs = docs_path.read_text(encoding="utf-8")

required_sql_fragments = [
    "create table if not exists public.agent_usage_events",
    "usage_units jsonb not null default '{}'::jsonb",
    "check (agent_tier in ('default', 'pro', 'power'))",
    "create or replace function public.agent_tier_for_profile",
    "create or replace function public.agent_usage_monthly_cap_usd",
    "create or replace function public.agent_usage_daily_cap_usd",
    "create function public.reserve_agent_usage_cost",
    "create function public.finalize_agent_usage_cost",
    "pg_advisory_xact_lock",
    "status in ('reserved', 'succeeded')",
    "raise exception 'Daily % usage cap reached for % tier'",
    "raise exception 'Monthly % usage cap reached for % tier'",
    "grant execute on function public.reserve_agent_usage_cost",
    "grant execute on function public.finalize_agent_usage_cost",
]

missing = [fragment for fragment in required_sql_fragments if fragment not in sql]
if missing:
    raise SystemExit("missing SQL usage-cap fragments: " + ", ".join(missing))

expected_caps = {
    ("default", "computer_use"): ("0.60", "3.00"),
    ("default", "realtime"): ("1.60", "8.00"),
    ("default", "transcription"): ("1.20", "6.00"),
    ("default", "context"): ("0.40", "2.00"),
    ("pro", "computer_use"): ("7.00", "35.00"),
    ("pro", "realtime"): ("9.00", "45.00"),
    ("pro", "transcription"): ("3.60", "18.00"),
    ("pro", "context"): ("2.00", "10.00"),
    ("power", "computer_use"): ("24.00", "120.00"),
    ("power", "realtime"): ("24.00", "120.00"),
    ("power", "transcription"): ("8.00", "40.00"),
    ("power", "context"): ("5.00", "25.00"),
}

for (tier, capability), (daily, monthly) in expected_caps.items():
    sql_monthly_pattern = rf"when '{re.escape(capability)}' then {re.escape(monthly)}"
    if not re.search(sql_monthly_pattern, sql):
        raise SystemExit(f"missing SQL monthly cap for {tier}/{capability}: {monthly}")

    display_tier = {"default": "Default", "pro": "Pro", "power": "Power"}[tier]
    display_capability = {
        "computer_use": "Computer Use",
        "realtime": "Realtime",
        "transcription": "Transcription",
        "context": "Context",
    }[capability]
    docs_line = f"| {display_tier} | {display_capability} | `${daily}` | `${monthly}` |"
    if docs_line not in docs:
        raise SystemExit(f"missing documented cap row: {docs_line}")

print(f"verified {len(expected_caps)} tier/capability cap rows")
PY

log "Checking function and test wiring"
python3 <<'PY'
from pathlib import Path

root = Path.cwd()

capabilities = {
    "realtime": {
        "source": "insforge/functions/realtime-session/index.ts",
        "test": "insforge/functions/realtime-session/index.test.ts",
        "env": "VOIYCE_REALTIME_ESTIMATED_SESSION_COST_USD",
    },
    "transcription": {
        "source": "insforge/functions/transcribe-audio/index.ts",
        "test": "insforge/functions/transcribe-audio/index.test.ts",
        "env": "OPENAI_TRANSCRIPTION_COST_CENTS_PER_MINUTE",
    },
    "computer_use": {
        "source": "insforge/functions/computer-use-step/index.ts",
        "test": "insforge/functions/computer-use-step/index.test.ts",
        "env": "VOIYCE_COMPUTER_USE_ESTIMATED_STEP_COST_USD",
    },
    "context": {
        "source": "insforge/functions/screen-context/index.ts",
        "test": "insforge/functions/screen-context/index.test.ts",
        "env": "VOIYCE_SCREEN_CONTEXT_ESTIMATED_REQUEST_COST_USD",
    },
}

for capability, config in capabilities.items():
    source = (root / config["source"]).read_text(encoding="utf-8")
    test = (root / config["test"]).read_text(encoding="utf-8")

    source_fragments = [
        "VOIYCE_ENFORCE_AGENT_USAGE_CAPS",
        "reserveAgentUsageCost",
        "finalizeAgentUsageCost",
        "p_usage_units",
        f"'{capability}'",
        config["env"],
        "usage_limit_reached",
        "accountUsageLimitMessage",
    ]
    missing_source = [fragment for fragment in source_fragments if fragment not in source]
    if missing_source:
        raise SystemExit(f"{config['source']} missing: {', '.join(missing_source)}")

    test_fragments = [
        "usage limits return clear account-limit responses before OpenAI",
        "reserves and finalizes usage caps when enabled",
        "VOIYCE_ENFORCE_AGENT_USAGE_CAPS",
        "reserve_agent_usage_cost",
        "finalize_agent_usage_cost",
        f'p_capability: "{capability}"',
        "p_usage_units",
        "p_succeeded: true",
    ]
    missing_test = [fragment for fragment in test_fragments if fragment not in test]
    if missing_test:
        raise SystemExit(f"{config['test']} missing: {', '.join(missing_test)}")

print(f"verified {len(capabilities)} cost-bearing function/test pairs")
PY

if [[ "$RUN_DENO_TESTS" -eq 1 ]]; then
  log "Running backend usage-cap tests"
  deno test --allow-env \
    insforge/functions/realtime-session/index.test.ts \
    insforge/functions/transcribe-audio/index.test.ts \
    insforge/functions/computer-use-step/index.test.ts \
    insforge/functions/screen-context/index.test.ts
else
  log "Skipping Deno tests (--skip-deno-tests)"
fi

log "Agent usage-cap verification passed"
