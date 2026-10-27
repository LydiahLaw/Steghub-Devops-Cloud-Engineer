#!/bin/bash
set -e
for env in dev sit prod; do
  var="${env^^}_DB_PASSWORD"
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS tooling_${env};
CREATE USER IF NOT EXISTS '${env}_user'@'%' IDENTIFIED BY '${!var}';
GRANT ALL PRIVILEGES ON tooling_${env}.* TO '${env}_user'@'%';
SQL
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "tooling_${env}" < /schema/tooling-db.sql
done
