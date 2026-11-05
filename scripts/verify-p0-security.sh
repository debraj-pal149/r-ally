#!/usr/bin/env bash
# Verifies Rally P0 security fixes are present in-repo / in the built app when provided.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAIL=1; }

echo "== Rally P0 security verifier =="

# 1. Firestore rules are owner-scoped
RULES="$ROOT/firestore.rules"
if grep -q 'function isOwner' "$RULES" \
  && grep -q 'allow read, write: if isOwner(uid)' "$RULES" \
  && ! grep -E 'allow (read|write): if true' "$RULES"; then
  pass "firestore.rules owner-only"
else
  fail "firestore.rules missing owner-only match or allows public write"
fi

# 2. Privacy Manifest present with Required Reason APIs
MANIFEST="$ROOT/app/RAlly/RAlly/PrivacyInfo.xcprivacy"
if [[ -f "$MANIFEST" ]] \
  && grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$MANIFEST" \
  && grep -q 'CA92.1' "$MANIFEST" \
  && grep -q 'NSPrivacyTracking' "$MANIFEST"; then
  pass "PrivacyInfo.xcprivacy present (UserDefaults CA92.1, tracking declared)"
else
  fail "PrivacyInfo.xcprivacy missing or incomplete"
fi

# 3. No Strava client secret in the iOS app surface (ignore DerivedData / build products)
HITS=$(grep -R --include='*.swift' --include='*.plist' --include='*.yml' -n 'STRAVA_CLIENT_SECRET' \
  "$ROOT/app/RAlly/RAlly" "$ROOT/app/RAlly/project.yml" "$ROOT/app/RAlly/RAllyTests" 2>/dev/null \
  | grep -v 'Binary' || true)
if [[ -n "$HITS" ]]; then
  fail "STRAVA_CLIENT_SECRET still referenced under app sources"
  printf '%s\n' "$HITS"
else
  pass "no STRAVA_CLIENT_SECRET in app sources/plist/yml"
fi

if grep -n 'client_secret' "$ROOT/app/RAlly/RAlly/Integrations/StravaClient.swift" >/dev/null 2>&1; then
  fail "StravaClient.swift still mentions client_secret"
else
  pass "StravaClient does not embed client_secret"
fi

if grep -q 'STRAVA_OAUTH_PROXY_URL' "$ROOT/app/RAlly/RAlly/Info.plist" \
  && grep -q 'oauthProxyURL' "$ROOT/app/RAlly/RAlly/Integrations/StravaClient.swift"; then
  pass "Strava uses server-side oauth proxy URL"
else
  fail "Strava oauth proxy wiring missing"
fi

# 4. Cloud Function exists to hold the secret
if [[ -f "$ROOT/functions/index.js" ]] && grep -q 'stravaOAuth' "$ROOT/functions/index.js"; then
  pass "functions/stravaOAuth present for server-side secret"
else
  fail "Cloud Function stravaOAuth missing"
fi

# 5. .env.example must not instruct putting the secret in the app
if grep -q 'STRAVA_CLIENT_SECRET' "$ROOT/.env.example" \
  && grep -qi 'never put in the iOS app' "$ROOT/.env.example"; then
  pass ".env.example marks STRAVA_CLIENT_SECRET as server-only"
elif ! grep -q 'STRAVA_CLIENT_SECRET=' "$ROOT/.env.example"; then
  pass ".env.example has no app-bound STRAVA_CLIENT_SECRET"
else
  fail ".env.example still treats STRAVA_CLIENT_SECRET as an app secret"
fi

# 6. Optional: built .app checks
APP="${1:-}"
if [[ -n "$APP" ]]; then
  if [[ ! -d "$APP" ]]; then
    fail "built app path not found: $APP"
  else
    if /usr/libexec/PlistBuddy -c 'Print :STRAVA_CLIENT_SECRET' "$APP/Info.plist" >/dev/null 2>&1; then
      fail "built Info.plist still contains STRAVA_CLIENT_SECRET"
    else
      pass "built Info.plist has no STRAVA_CLIENT_SECRET"
    fi
    if find "$APP" -name 'PrivacyInfo.xcprivacy' | grep -q .; then
      pass "built app embeds PrivacyInfo.xcprivacy"
    else
      fail "built app missing PrivacyInfo.xcprivacy"
    fi
  fi
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "P0 verifier: ALL CHECKS PASSED"
  exit 0
fi
echo "P0 verifier: FAILURES ABOVE"
exit 1
