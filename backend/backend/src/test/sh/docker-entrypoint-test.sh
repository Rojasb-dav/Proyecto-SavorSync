#!/bin/sh
set -eu

# Run with sh from the backend directory, in a Linux environment without a CA
# at /etc/secrets/aiven-ca.pem. A valid URL reaches the mandatory CA check.
entrypoint=${1:-./docker-entrypoint.sh}
if [ -s /etc/secrets/aiven-ca.pem ]; then
  printf '%s\n' 'Run this test without the production CA mounted.' >&2
  exit 1
fi

cases=0
expect_rejection() {
  expected=$1
  url=$2
  shift 2
  if output=$(SPRING_PROFILES_ACTIVE='local, production' SPRING_DATASOURCE_URL="$url" \
      sh "$entrypoint" "$@" 2>&1); then
    printf 'Case %s unexpectedly started Java\n' "$((cases + 1))" >&2
    exit 1
  fi
  case "$output" in
    "$expected"*) ;;
    *) printf 'Case %s returned a different diagnostic\n' "$((cases + 1))" >&2; exit 1 ;;
  esac
  case "$output" in
    *fixture-secret*) printf 'Case %s logged a fixture secret\n' "$((cases + 1))" >&2; exit 1 ;;
  esac
  if [ -n "$url" ]; then
    case "$output" in
      *"$url"*) printf 'Case %s logged the supplied URL\n' "$((cases + 1))" >&2; exit 1 ;;
    esac
  fi
  cases=$((cases + 1))
}

valid=jdbc:mysql://mysql-1.example.test:3306/savorsync_v34_validation
expect_rejection 'Falta el certificado CA' "$valid"
expect_rejection 'Falta el certificado CA' "$valid" --savorsync-bootstrap-admin
expect_rejection 'Falta el certificado CA' 'jdbc:mysql://db:65535/savorsync_v34_validation'
expect_rejection 'La configuración JDBC' "$valid" --spring.datasource.url=ignored
expect_rejection 'La configuración JDBC' "$valid" --spring.datasource.hikari.jdbc-url=ignored
expect_rejection 'La configuración JDBC' "$valid" --spring.profiles.active=development
expect_rejection 'La configuración JDBC' "$valid" --spring.flyway.enabled=true
expect_rejection 'La configuración JDBC' "$valid" --spring.jpa.hibernate.ddl-auto=update

for invalid in \
    '' \
    'jdbc:mysql://db:3306/defaultdb' \
    'jdbc:mysql://db:3306/otro_esquema' \
    'jdbc:mysql://db:3306/SAVORSYNC_V34_VALIDATION' \
    'jdbc:mysql://db:3306/savorsync_v34_validation?useSSL=false' \
    'jdbc:mysql://db:3306/savorsync_v34_validation#fragment' \
    'jdbc:mysql://user:fixture@db:3306/savorsync_v34_validation' \
    'jdbc:mysql://db:3306/savorsync_v34_validation?password=fixture' \
    'jdbc:mysql://db:3306,backup:3306/savorsync_v34_validation' \
    'jdbc:mysql:loadbalance://db:3306/savorsync_v34_validation' \
    'jdbc:mysql://address=(host=db)(port=3306)/savorsync_v34_validation' \
    'jdbc:mysql://db:3306/extra/savorsync_v34_validation' \
    'jdbc:mysql://db:3306/savorsync_v34_validation/' \
    'jdbc:mysql://db:3306/savorsync%5fv34_validation' \
    'jdbc:mysql://db/savorsync_v34_validation' \
    'jdbc:mysql://db:/savorsync_v34_validation' \
    'jdbc:mysql://db:0/savorsync_v34_validation' \
    'jdbc:mysql://db:65536/savorsync_v34_validation' \
    'jdbc:mysql://db:33x6/savorsync_v34_validation' \
    'jdbc:mysql://db:3306:3306/savorsync_v34_validation' \
    'jdbc:mysql://[::1]:3306/savorsync_v34_validation' \
    'jdbc:mysql://:3306/savorsync_v34_validation' \
    'jdbc:mysql://-db:3306/savorsync_v34_validation' \
    'jdbc:mysql://db..example.test:3306/savorsync_v34_validation' \
    'jdbc:mysql://db.example.test.:3306/savorsync_v34_validation' \
    "$(printf 'jdbc:mysql://bad\nserver:3306/savorsync_v34_validation')" \
    "$(printf '%s\r' "$valid")"; do
  expect_rejection 'URL JDBC de producción no permitida' "$invalid"
done

expect_rejection 'La configuración JDBC' "$valid" --spring.config.additional-location=/fixture/
expect_rejection 'La configuración JDBC' "$valid" --spring.jpa.hibernate.ddlAuto=create
expect_rejection 'La configuración JDBC' "$valid" --spring.profiles.include=production
SPRING_APPLICATION_JSON='{"spring":{"datasource":{"url":"fixture-secret"}}}' \
  expect_rejection 'Las opciones JVM externas' "$valid"
JAVA_TOOL_OPTIONS='-Dspring.datasource.password=fixture-secret' \
  expect_rejection 'Las opciones JVM externas' "$valid"

if output=$(env 'spring.datasource.hikari.dataSourceProperties.sslMode=fixture-secret' \
    SPRING_PROFILES_ACTIVE=production SPRING_DATASOURCE_URL="$valid" sh "$entrypoint" 2>&1); then
  printf '%s\n' 'A dotted environment key unexpectedly started Java' >&2
  exit 1
fi
case "$output" in
  *fixture-secret*) printf '%s\n' 'A fixture secret was logged' >&2; exit 1 ;;
  'La configuración externa de Spring'*) cases=$((cases + 1)) ;;
  *) printf '%s\n' 'A dotted environment key was not rejected' >&2; exit 1 ;;
esac

printf '%s entrypoint checks passed\n' "$cases"
