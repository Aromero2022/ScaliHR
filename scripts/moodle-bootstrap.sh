#!/usr/bin/env bash
set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════════╗
# ║  moodle-bootstrap.sh — one-time Moodle installation + config     ║
# ║  Prerequisites: docker compose -f docker-compose.lms.yml up -d   ║
# ╚═══════════════════════════════════════════════════════════════════╝

MOODLE_CONTAINER="${MOODLE_CONTAINER:-scalia-moodle}"
DB_PASSWORD="${MOODLE_DB_PASSWORD:-moodle_dev_pass}"
ADMIN_PASS=$(openssl rand -base64 18 | tr -d '=+/')
SITE_NAME="Scalia HR — Formación"
WWWROOT="http://localhost:8080"

echo "── Waiting for Moodle container to be ready..."
until docker exec "$MOODLE_CONTAINER" test -f /var/www/html/admin/cli/install.php 2>/dev/null; do
  sleep 2
done

echo "── Running Moodle CLI install..."
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/install.php \
  --wwwroot="$WWWROOT" \
  --dataroot=/var/www/moodledata \
  --dbtype=pgsql \
  --dbhost=moodle-pg \
  --dbname=moodle \
  --dbuser=moodle \
  --dbpass="$DB_PASSWORD" \
  --fullname="$SITE_NAME" \
  --shortname="Scalia LMS" \
  --adminuser=admin \
  --adminpass="$ADMIN_PASS" \
  --adminemail="admin@scalia.local" \
  --agree-license \
  --non-interactive

echo "── Enabling REST web services..."
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --name=enablewebservices --set=1
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --name=enablemobilewebservice --set=0

echo "── Enabling REST protocol..."
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --name=webserviceprotocols --set=rest

echo "── Installing auth_userkey plugin..."
if ! docker exec "$MOODLE_CONTAINER" test -d /var/www/html/auth/userkey; then
  docker exec "$MOODLE_CONTAINER" bash -c '
    cd /tmp &&
    curl -sL "https://moodle.org/plugins/download.php/auth_userkey/latest" -o auth_userkey.zip &&
    unzip -q auth_userkey.zip -d /var/www/html/auth/ &&
    rm auth_userkey.zip
  '
fi

echo "── Running Moodle upgrade to register plugin..."
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/upgrade.php --non-interactive

echo "── Configuring auth_userkey: mapping by username..."
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --component=auth_userkey --name=mappingfield --set=username
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --component=auth_userkey --name=createuser --set=0
docker exec "$MOODLE_CONTAINER" php /var/www/html/admin/cli/cfg.php \
  --component=auth_userkey --name=iprestriction --set=0

echo "── Enabling auth_userkey authentication..."
docker exec "$MOODLE_CONTAINER" php -r "
  define('CLI_SCRIPT', true);
  require('/var/www/html/config.php');
  set_config('auth', 'manual,userkey');
"

echo "── Creating service role + user for Scalia HR API..."
docker exec "$MOODLE_CONTAINER" php -r "
  define('CLI_SCRIPT', true);
  require('/var/www/html/config.php');
  require_once(\\\$CFG->libdir . '/accesslib.php');

  // Create 'scalia_ws' role with minimal capabilities
  \\\$roleid = create_role('Scalia WS', 'scalia_ws', 'API role for Scalia HR LMS bridge');
  \\\$context = context_system::instance();

  \\\$caps = [
    'moodle/user:create',
    'moodle/user:update',
    'moodle/user:viewdetails',
    'enrol/manual:enrol',
    'enrol/manual:unenrol',
    'moodle/course:view',
    'moodle/category:manage',
    'moodle/cohort:manage',
    'moodle/cohort:view',
    'auth/userkey:generatekey',
    'webservice/rest:use',
    'moodle/user:viewalldetails',
    'moodle/course:viewhiddencourses',
  ];

  foreach (\\\$caps as \\\$cap) {
    assign_capability(\\\$cap, CAP_ALLOW, \\\$roleid, \\\$context->id, true);
  }

  // Create service user
  \\\$user = new stdClass();
  \\\$user->username = 'scalia_service';
  \\\$user->password = md5(random_bytes(32));
  \\\$user->firstname = 'Scalia';
  \\\$user->lastname = 'Service';
  \\\$user->email = 'service@scalia.local';
  \\\$user->auth = 'manual';
  \\\$user->confirmed = 1;
  \\\$user->mnethostid = \\\$CFG->mnet_localhost_id;
  \\\$user->id = user_create_user(\\\$user, false);

  role_assign(\\\$roleid, \\\$user->id, \\\$context->id);
  echo \"Service user created: scalia_service (id={\\\$user->id})\n\";
"

echo "── Creating external service + token..."
WS_TOKEN=$(docker exec "$MOODLE_CONTAINER" php -r "
  define('CLI_SCRIPT', true);
  require('/var/www/html/config.php');
  require_once(\\\$CFG->dirroot . '/lib/externallib.php');
  require_once(\\\$CFG->dirroot . '/webservice/lib.php');

  global \\\$DB;

  \\\$service = new stdClass();
  \\\$service->name = 'Scalia HR LMS Bridge';
  \\\$service->shortname = 'scalia_bridge';
  \\\$service->enabled = 1;
  \\\$service->restrictedusers = 1;
  \\\$service->downloadfiles = 0;
  \\\$service->uploadfiles = 0;
  \\\$service->id = \\\$DB->insert_record('external_services', \\\$service);

  \\\$functions = [
    'core_user_create_users',
    'core_user_get_users',
    'core_user_update_users',
    'enrol_manual_enrol_users',
    'auth_userkey_request_login_url',
    'core_course_get_categories',
    'core_course_create_categories',
    'core_cohort_create_cohorts',
    'core_cohort_add_cohort_members',
    'core_cohort_delete_cohort_members',
    'core_cohort_get_cohorts',
    'core_completion_get_activities_completion_status',
  ];

  foreach (\\\$functions as \\\$fname) {
    \\\$rec = new stdClass();
    \\\$rec->externalserviceid = \\\$service->id;
    \\\$rec->functionname = \\\$fname;
    \\\$DB->insert_record('external_services_functions', \\\$rec);
  }

  // Authorise service user
  \\\$su = \\\$DB->get_record('user', ['username' => 'scalia_service']);
  \\\$allowed = new stdClass();
  \\\$allowed->externalserviceid = \\\$service->id;
  \\\$allowed->userid = \\\$su->id;
  \\\$DB->insert_record('external_services_users', \\\$allowed);

  // Generate token
  \\\$wm = new webservice();
  \\\$token = \\\$wm->generate_user_token(\\\$service->id, \\\$su->id);
  echo \\\$token->token;
")

echo ""
echo "══════════════════════════════════════════════════"
echo "  Moodle installation complete!"
echo "  Admin user:  admin"
echo "  Admin pass:  $ADMIN_PASS"
echo "  Site URL:    $WWWROOT"
echo ""
echo "  MOODLE_WS_TOKEN=$WS_TOKEN"
echo ""
echo "  Add to your .env.local:"
echo "  MOODLE_BASE_URL=$WWWROOT"
echo "  MOODLE_WS_TOKEN=$WS_TOKEN"
echo "══════════════════════════════════════════════════"
