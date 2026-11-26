#!/bin/sh
set -eu

reject_jdbc_url() {
  printf '%s\n' 'URL JDBC de producción no permitida. Usa un host DNS, puerto y esquema savorsync_v34_validation sin parámetros.' >&2
  exit 1
}

validate_production_url() {
  case "$1" in
    jdbc:mysql://*/savorsync_v34_validation) ;;
    *) reject_jdbc_url ;;
  esac

  authority=${1#jdbc:mysql://}
  authority=${authority%/savorsync_v34_validation}
  # Filter the complete authority before checking DNS labels so embedded newlines
  # cannot be interpreted by grep as a separate valid line.
  case "$authority" in
    *[!A-Za-z0-9.:-]*|*:*:*) reject_jdbc_url ;;
    *:*) ;;
    *) reject_jdbc_url ;;
  esac
  host=${authority%:*}
  port=${authority##*:}

  if [ "${#host}" -gt 253 ] ||
    ! printf '%s\n' "$host" | LC_ALL=C grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'; then
    reject_jdbc_url
  fi

  case "$port" in
    ''|*[!0-9]*|??????*) reject_jdbc_url ;;
  esac
  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    reject_jdbc_url
  fi
}

unset SAVORSYNC_PRODUCTION_ENTRYPOINT
if printf '%s\n' "${SPRING_PROFILES_ACTIVE:-}" | LC_ALL=C grep -Eq '(^|,)[[:space:]]*production[[:space:]]*(,|$)'; then
  # Spring splits profile names on commas. A newline inside a name must
  # not be treated as a separate production profile by the check above.
  case "$SPRING_PROFILES_ACTIVE" in
    *"
"*|*"$(printf '\r')"*)
      printf '%s\n' 'SPRING_PROFILES_ACTIVE debe contener una lista de perfiles en una sola línea.' >&2
      exit 1
      ;;
  esac
  production_url=${SPRING_DATASOURCE_URL:-}
  validate_production_url "$production_url"

  for argument in "$@"; do
    case "$argument" in
      --savorsync-bootstrap-admin) ;;
      *)
        printf '%s\n' 'La configuración JDBC y del esquema de producción se controla desde el entrypoint.' >&2
        exit 1
        ;;
    esac
  done

  if [ -n "${JAVA_TOOL_OPTIONS:-}${_JAVA_OPTIONS:-}${JDK_JAVA_OPTIONS:-}${SPRING_APPLICATION_JSON:-}" ]; then
    printf '%s\n' 'Las opciones JVM externas y SPRING_APPLICATION_JSON no se admiten en producción.' >&2
    exit 1
  fi

  # dash can discard environment names containing dots before launching Java.
  # Inspect only names in the original NUL-delimited environment, without printing it.
  if LC_ALL=C grep -zEiq '^(spring|hibernate|flyway|logging)[^=]*[^[:alnum:]_=][^=]*=' "/proc/$$/environ"; then
    printf '%s\n' 'La configuración externa de Spring no se admite en producción.' >&2
    exit 1
  elif [ "$?" -ne 1 ]; then
    printf '%s\n' 'No se pudo validar el entorno original del contenedor.' >&2
    exit 1
  fi

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

  # Pin the URL checked above for both Boot and Hikari. Only the URL is exposed
  # to these arguments. Credentials and truststore password stay in the environment.
  export SAVORSYNC_PRODUCTION_ENTRYPOINT=true
  set -- "$@" "--spring.config.location=classpath:/" "--spring.datasource.url=$production_url" \
    "--spring.datasource.hikari.jdbc-url=$production_url" \
    "--spring.jpa.hibernate.ddl-auto=validate" "--spring.flyway.enabled=false"
fi

exec java -XX:MaxRAMPercentage=65 -jar /app/backend.jar "$@"
