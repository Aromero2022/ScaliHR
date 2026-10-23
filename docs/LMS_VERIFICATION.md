# LMS Integration — Manual Verification

## Prerequisites

- Docker + Docker Compose installed
- `.env` file with `MOODLE_DB_PASSWORD` set (any secure value)

## Automated verification

```bash
bash scripts/verify-lms.sh
```

This script:

1. Starts `docker-compose.lms.yml` (Moodle + PostgreSQL)
2. Waits for Moodle HTTP to respond (up to 120s)
3. Runs `scripts/moodle-bootstrap.sh` (CLI install, web services, auth_userkey)
4. Verifies all Moodle web service endpoints used by Scalia HR:
   - `core_webservice_get_site_info` — basic connectivity
   - `core_user_create_users` — user provisioning
   - `auth_userkey_request_login_url` — SSO launch
   - `core_course_create_categories` — tenant category isolation
   - `core_cohort_create_cohorts` — tenant cohort isolation
5. Tears down containers and volumes
6. Exits 0 (all passed) or 1 (failures)

## Manual step-by-step

### 1. Start containers

```bash
docker compose -f docker-compose.lms.yml up -d
```

### 2. Bootstrap Moodle

```bash
bash scripts/moodle-bootstrap.sh
```

Save the `MOODLE_WS_TOKEN` from the output. Add it to your `.env`:

```
MOODLE_BASE_URL=http://127.0.0.1:8080
MOODLE_WS_TOKEN=<token from bootstrap>
```

### 3. Verify web services

```bash
# Site info (basic connectivity)
curl -s "http://127.0.0.1:8080/webservice/rest/server.php?\
wstoken=TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"

# Create test user
curl -s "http://127.0.0.1:8080/webservice/rest/server.php" \
  -d "wstoken=TOKEN&wsfunction=core_user_create_users&moodlewsrestformat=json\
&users[0][username]=testuser1&users[0][email]=test1@scalia.local\
&users[0][firstname]=Test&users[0][lastname]=User\
&users[0][password]=TestPass1!&users[0][auth]=userkey&users[0][createpassword]=0"

# SSO login URL
curl -s "http://127.0.0.1:8080/webservice/rest/server.php" \
  -d "wstoken=TOKEN&wsfunction=auth_userkey_request_login_url\
&moodlewsrestformat=json&user[username]=testuser1"
```

The SSO response should contain a `loginurl` field with a URL like:
`http://127.0.0.1:8080/auth/userkey/login.php?key=...`

### 4. Test SSO in browser

1. Start the Next.js dev server: `npm run dev:web`
2. Log in as `elena.martinez@acme.dev / Demo1234!`
3. Enable LMS for the tenant (set `is_lms_active = true` in the `tenants` table)
4. Navigate to Formacion (LMS) in the sidebar
5. Click "Abrir Moodle" — should redirect to Moodle with an active session

### 5. Teardown

```bash
docker compose -f docker-compose.lms.yml down -v
```
