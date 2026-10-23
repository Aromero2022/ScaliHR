#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════
# verify-lms.sh — End-to-end LMS integration verification
#
# Prerequisites:
#   - Docker + Docker Compose
#   - .env with MOODLE_DB_PASSWORD set
#
# Usage: bash scripts/verify-lms.sh
# ═══════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "═══════════════════════════════════════════════════"
echo " Scalia HR — LMS Integration Verification"
echo "═══════════════════════════════════════════════════"
echo ""

# ── 1. Start containers ─────────────────────────────────────────
echo -e "${YELLOW}[1/5]${NC} Starting LMS containers..."
docker compose -f docker-compose.lms.yml up -d

echo -e "${YELLOW}[2/5]${NC} Waiting for Moodle to be ready (up to 120s)..."
READY=false
for i in $(seq 1 24); do
  if curl -sf http://127.0.0.1:8080/ >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 5
done

if [ "$READY" = false ]; then
  echo -e "${RED}Moodle did not start within 120s. Check docker logs.${NC}"
  docker compose -f docker-compose.lms.yml logs --tail=20
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Moodle HTTP responding"

# ── 2. Bootstrap ────────────────────────────────────────────────
echo -e "${YELLOW}[3/5]${NC} Running moodle-bootstrap.sh..."
BOOTSTRAP_OUT=$(bash scripts/moodle-bootstrap.sh 2>&1)
echo "$BOOTSTRAP_OUT"

TOKEN=$(echo "$BOOTSTRAP_OUT" | grep -oP 'MOODLE_WS_TOKEN=\K\S+' || true)
if [ -z "$TOKEN" ]; then
  echo -e "${RED}Could not extract MOODLE_WS_TOKEN from bootstrap output.${NC}"
  exit 1
fi
echo -e "  ${GREEN}✓${NC} Token extracted"

# ── 3. Web services check ──────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/5]${NC} Verifying Moodle web services..."

check "core_webservice_get_site_info responds" \
  curl -sf "http://127.0.0.1:8080/webservice/rest/server.php?wstoken=${TOKEN}&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"

check "core_user_create_users works" \
  bash -c "curl -sf 'http://127.0.0.1:8080/webservice/rest/server.php' \
    -d 'wstoken=${TOKEN}&wsfunction=core_user_create_users&moodlewsrestformat=json&users[0][username]=testuser_verify&users[0][email]=testverify@scalia.local&users[0][firstname]=Test&users[0][lastname]=Verify&users[0][password]=TestPass123!&users[0][auth]=userkey&users[0][createpassword]=0' \
    | grep -q '\"id\"'"

check "auth_userkey_request_login_url returns a URL" \
  bash -c "curl -sf 'http://127.0.0.1:8080/webservice/rest/server.php' \
    -d 'wstoken=${TOKEN}&wsfunction=auth_userkey_request_login_url&moodlewsrestformat=json&user[username]=testuser_verify' \
    | grep -q 'loginurl'"

check "core_course_create_categories works" \
  bash -c "curl -sf 'http://127.0.0.1:8080/webservice/rest/server.php' \
    -d 'wstoken=${TOKEN}&wsfunction=core_course_create_categories&moodlewsrestformat=json&categories[0][name]=Verify+Category&categories[0][parent]=0' \
    | grep -q '\"id\"'"

check "core_cohort_create_cohorts works" \
  bash -c "curl -sf 'http://127.0.0.1:8080/webservice/rest/server.php' \
    -d 'wstoken=${TOKEN}&wsfunction=core_cohort_create_cohorts&moodlewsrestformat=json&cohorts[0][categorytype][type]=system&cohorts[0][categorytype][value]=&cohorts[0][name]=Verify+Cohort&cohorts[0][idnumber]=verify_test' \
    | grep -q '\"id\"'"

# ── 4. Teardown ─────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}[5/5]${NC} Stopping containers..."
docker compose -f docker-compose.lms.yml down -v

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "═══════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
