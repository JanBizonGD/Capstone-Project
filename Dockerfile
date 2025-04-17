FROM eclipse-temurin:latest AS deps

WORKDIR /build

COPY ./src src/
COPY ./gradlew ./gradlew
COPY ./.gradle ./.gradle
# COPY ~/.gradle ~/.gradle
RUN --mount=type=bind,source=settings.gradle,target=settings.gradle \
    --mount=type=bind,source=build.gradle,target=build.gradle \
    --mount=type=cache,target=/root/.m2 \
    ./gradlew build -x test && \
    mv build/lib/$(./gradlew -q properties | awk -F ': ' '/^name: / {name=$2} /^version: / {version=$2} END {print name "-" version ".jar"}') target/app.jar
RUN java -Djarmode=layertools -jar target/app.jar extract --destination target/extracted


################################################################################

FROM eclipse-temurin:21-jre-alpine AS final

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser
USER appuser

COPY --from=deps build/target/extracted/dependencies/ ./
COPY --from=deps build/target/extracted/spring-boot-loader/ ./
COPY --from=deps build/target/extracted/snapshot-dependencies/ ./
COPY --from=deps build/target/extracted/application/ ./

EXPOSE 8080

ENTRYPOINT [ "java", "org.springframework.boot.loader.launch.JarLauncher" ]

