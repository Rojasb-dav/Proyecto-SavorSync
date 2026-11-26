#!/bin/sh
set -eu

case ",${SPRING_PROFILES_ACTIVE:-}," in
  *,production,*)
    case "${SPRING_DATASOURCE_URL:-}" in
      jdbc:mysql://*/defaultdb) ;;
      *) printf '%s\n' 'Se requiere URL JDBC MySQL de producción sin parámetros.' >&2; exit 1 ;;
    esac
    case "$SPRING_DATASOURCE_URL" in
      *\?*|*\#*|*\@*|*,*|*\(*|*\)*) printf '%s\n' 'URL JDBC de producción no permitida.' >&2; exit 1 ;;
    esac
    cert=/etc/secrets/aiven-ca.pem
    if [ ! -s "$cert" ]; then
      printf '%s\n' 'Falta el certificado CA de MySQL en /etc/secrets/aiven-ca.pem.' >&2
      exit 1
    fi
    umask 077
    tls_dir="$(mktemp -d)"
    MYSQL_TRUSTSTORE_PASSWORD="$(cat /proc/sys/kernel/random/uuid)"
    export MYSQL_TRUSTSTORE_PASSWORD
    if ! keytool -importcert -noprompt -alias mysql-ca -file "$cert" \
      -keystore "$tls_dir/mysql.p12" -storetype PKCS12 \
      -storepass:env MYSQL_TRUSTSTORE_PASSWORD >/dev/null 2>&1; then
      printf '%s\n' 'No se pudo importar la CA de MySQL.' >&2
      exit 1
    fi
    export MYSQL_TRUSTSTORE_URL="file:$tls_dir/mysql.p12"
    ;;
esac

exec java -XX:MaxRAMPercentage=65 -jar /app/backend.jar "$@"
