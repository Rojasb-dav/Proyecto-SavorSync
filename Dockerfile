# Compatibility for builds that still use the repository root.
# Render should use backend/backend as its build context.
FROM eclipse-temurin:17-jdk-jammy@sha256:96ac8197b2cbc2bb0f9fbcbf91dbb0015f43b3c76a1cb351892da12e7bb91bed AS build
WORKDIR /build
COPY backend/backend/gradlew backend/backend/build.gradle backend/backend/settings.gradle ./
COPY backend/backend/gradle/wrapper/ gradle/wrapper/
COPY backend/backend/src/main/ src/main/
RUN sed -i 's/\r$//' gradlew && chmod 0755 gradlew \
    && ./gradlew bootJar --no-daemon --max-workers=2

FROM eclipse-temurin:17-jre-jammy@sha256:c6a5dd70fb24f4e07ef88cbda8efb613a5a649a1af071a41de8eaabd1ee6b5da
WORKDIR /app
COPY --from=build /build/build/libs/backend.jar /app/backend.jar
COPY backend/backend/docker-entrypoint.sh /app/docker-entrypoint.sh
RUN sed -i 's/\r$//' /app/docker-entrypoint.sh && chmod 0555 /app/docker-entrypoint.sh
USER 10001:10001
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/docker-entrypoint.sh"]
