#!/usr/bin/env bash

set -euo pipefail

# This helper prints a Stripe live billing review checklist only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, charge users, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-stripe-live-billing-review.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown Stripe live billing review checklist for account mode,
product/price ids, checkout and portal evidence, webhook endpoint and
signing-secret presence, subscription mapping, cancellation/refund copy,
support escalation, no-secret evidence handling, and final sign-off. This
script is read-only and does not read secret values, write files, stage, commit,
tag, build, package, deploy, notarize, upload, charge users, or mutate external
services.

Examples:
  scripts/generate-stripe-live-billing-review.sh
  scripts/generate-stripe-live-billing-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-version)
      [[ $# -ge 2 ]] || { echo "error: --expected-version requires a value" >&2; exit 2; }
      EXPECTED_VERSION="$2"
      shift 2
      ;;
    --expected-build)
      [[ $# -ge 2 ]] || { echo "error: --expected-build requires a value" >&2; exit 2; }
      EXPECTED_BUILD="$2"
      shift 2
      ;;
    --expected-tag)
      [[ $# -ge 2 ]] || { echo "error: --expected-tag requires a value" >&2; exit 2; }
      EXPECTED_TAG="$2"
      shift 2
      ;;
    --production-url)
      [[ $# -ge 2 ]] || { echo "error: --production-url requires a value" >&2; exit 2; }
      PRODUCTION_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
DIRTY_COUNT="$(git status --porcelain=v1 --untracked-files=all | sed '/^$/d' | wc -l | tr -d ' ')"

cat <<EOF
### Stripe Live Billing Review - YYYY-MM-DD

- Reviewer:
- Billing owner:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Decision: pass / hold
- Stripe account mode: test / live
- Final owner sign-off:

#### Live Mode Decision

- \`STRIPE_ALLOW_LIVE_MODE\` decision:
- Live charges intentionally enabled: yes / no
- Beta stays in test mode unless explicitly approved:
- Owner-approved exception:
- Open billing blockers:

#### Product And Price Review

- Products reviewed:
- Monthly product id:
- Monthly price id:
- Yearly product id:
- Yearly price id:
- Fallback \`STRIPE_PRICE_ID\` decision:
- App plan copy matches active Stripe products/prices:
- Terms subscription/cancellation copy evidence:
- Privacy/billing disclosure evidence:

#### Checkout And Portal Evidence

- Checkout session evidence:
- Billing portal evidence:
- Test customer or internal account used:
- Checkout success path evidence:
- Checkout cancel path evidence:
- Portal cancellation behavior:
- Refund policy/copy evidence:
- No real customer payment details copied into docs/support/chat:

#### Webhook And Subscription Mapping

- Webhook endpoint id:
- Webhook events verified:
- \`STRIPE_WEBHOOK_SECRET\` presence verified without copying value:
- Signature verification evidence:
- Subscription created/updated/deleted evidence:
- Subscription RPC/mapping evidence:
- cancel-at-period-end evidence:
- Active plan mapping evidence:
- Database access/update evidence:

#### Support And Monitoring

- Support escalation owner:
- Billing escalation owner:
- First live-charge monitoring owner:
- Stripe dashboard evidence reviewed:
- Support response copy reviewed:
- Refund/cancellation support path reviewed:
- Invite/release-note decision: hold / narrow / proceed

#### Privacy Review

- No Stripe secret keys copied into record:
- No webhook signing secrets copied into record:
- No card numbers copied into record:
- No payment screenshots with private details copied into record:
- No customer private data copied into record:
- Dashboard screenshots redacted:

Launch hold rule: if the live-mode decision, product/price ids, webhook endpoint, webhook signing-secret presence, checkout evidence, portal evidence, subscription mapping, refund/cancellation copy, support owner, or no-secret handling are missing, keep billing in test mode and do not charge users.
EOF
