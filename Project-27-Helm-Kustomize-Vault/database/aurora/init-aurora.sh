#!/bin/bash
set -e
MYSQL="mysql -h $DB_HOST -u$DB_ADMIN_USER -p$DB_ADMIN_PASSWORD"

echo "Waiting for Aurora at $DB_HOST..."
for i in $(seq 1 30); do
  if mysqladmin -h "$DB_HOST" -u"$DB_ADMIN_USER" -p"$DB_ADMIN_PASSWORD" ping --silent; then break; fi
  sleep 5
done

for env in dev sit prod; do
  var="${env^^}_DB_PASSWORD"
  $MYSQL <<SQL
CREATE DATABASE IF NOT EXISTS tooling_${env};
CREATE USER IF NOT EXISTS '${env}_user'@'%' IDENTIFIED BY '${!var}';
GRANT ALL PRIVILEGES ON tooling_${env}.* TO '${env}_user'@'%';
SQL
  if $MYSQL "tooling_${env}" -e "SHOW TABLES LIKE 'users'" | grep -q users; then
    echo "tooling_${env}: schema already loaded, skipping"
  else
    $MYSQL "tooling_${env}" < /schema/tooling-db.sql
    echo "tooling_${env}: schema loaded"
  fi
done
