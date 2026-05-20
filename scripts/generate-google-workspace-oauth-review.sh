#!/usr/bin/env bash

set -euo pipefail

# This helper prints a Google Workspace OAuth readiness checklist only.
# It does not read secret values, write files, stage, commit, tag, build, package, deploy, notarize, upload, connect accounts, or mutate external services.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_VERSION="1.0"
EXPECTED_BUILD="16"
EXPECTED_TAG="v1.0+16"
PRODUCTION_URL="${PRODUCTION_LANDING_URL:-https://voiyce.us}"
SUPPORT_EMAIL="aki.b@pentridgemedia.com"

usage() {
  cat <<'EOF'
Usage: scripts/generate-google-workspace-oauth-review.sh [--expected-version <version>] [--expected-build <build>] [--expected-tag <tag>] [--production-url <url>]

Prints a markdown Google Workspace OAuth readiness checklist for OAuth app
identity, redirect URI review, Gmail/Calendar scope review, consent copy,
test-account connection, missing-OAuth recovery, token/privacy handling, support
evidence, and final sign-off. This script is read-only and does not read secret
values, write files, stage, commit, tag, build, package, deploy, notarize,
upload, connect accounts, or mutate external services.

Examples:
  scripts/generate-google-workspace-oauth-review.sh
  scripts/generate-google-workspace-oauth-review.sh --expected-version 1.0 --expected-build 16 --expected-tag 'v1.0+16'
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
### Google Workspace OAuth Review - YYYY-MM-DD

- Reviewer:
- Support contact: ${SUPPORT_EMAIL}
- Production URL: ${PRODUCTION_URL}
- Release version/build/tag: ${EXPECTED_VERSION} / ${EXPECTED_BUILD} / ${EXPECTED_TAG}
- Current branch: ${BRANCH}
- Current HEAD: ${HEAD_SHA}
- Current dirty path count: ${DIRTY_COUNT}
- Decision: pass / hold
- Final owner sign-off:

#### OAuth App And Redirects

- Google Cloud project/app reviewed:
- OAuth app publishing status:
- Authorized redirect URI evidence:
- Authorized JavaScript origin evidence, if applicable:
- App name and support contact match Voiyce:
- OAuth consent screen copy matches Gmail/Calendar feature surface:
- Test users or production publishing status reviewed:
- Open OAuth blockers:

#### Scope Review

- Gmail read scope reviewed:
- Gmail draft/send scope reviewed, if enabled:
- Calendar read scope reviewed:
- Calendar write scope reviewed, if enabled:
- Requested scopes match current app behavior:
- App copy does not imply Gmail/Calendar access before connection:
- Beta limitations mention Google-connected features:
- Support workaround copy reviewed:

#### Test Account Evidence

- Test account used:
- Sign-in and Google connect flow result:
- Missing-OAuth recovery result:
- Revoked-OAuth recovery result:
- Gmail read/query smoke result:
- Gmail draft/send smoke result, if enabled:
- Calendar read/query smoke result:
- Calendar write smoke result, if enabled:
- Agent Log/support export event IDs:
- No raw email or calendar content copied into evidence:

#### Token And Privacy Review

- No OAuth client secrets copied into record:
- No OAuth access tokens copied into record:
- No refresh tokens copied into record:
- No raw inbox content copied into record:
- No raw calendar details copied into record:
- Dashboard screenshots redacted:
- Support exports reviewed before linking:

#### Support And Launch Decision

- Support owner:
- Engineering owner:
- Known limitation or workaround link:
- Invite/release-note decision: hold / narrow / proceed
- User-facing support reply reviewed:
- Open Google Workspace blockers:

Launch hold rule: if OAuth app identity, redirect URI, requested scopes, consent copy, missing-OAuth recovery, revoked-OAuth recovery, test-account smoke, support workaround, or no-token/no-private-data handling are missing, keep Gmail and Calendar workflows out of invite claims or hold invites for users who need those workflows.
EOF
