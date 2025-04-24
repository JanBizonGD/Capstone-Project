FROM eclipse-temurin:latest AS deps

WORKDIR /build

COPY ./src src/
COPY ./gradlew ./gradlew
COPY ./.gradle ./.gradle
COPY ./gradle ./gradle
# COPY ~/.gradle ~/.gradle
RUN mkdir target/
RUN --mount=type=bind,source=settings.gradle,target=settings.gradle \
    --mount=type=bind,source=build.gradle,target=build.gradle \
    --mount=type=cache,target=/root/.m2 \
    ./gradlew build -x test  -x compileTestJava -x processTestResources -x testClasses -x processTestAot -x compileAotTestJava -x processAotTestResources -x aotTestClasses && \
    mv build/libs/$(./gradlew -q properties --property name | grep -o 'name.*' | cut -f2 -d' ')-$(./gradlew -q properties --property version | grep -o 'version.*' | cut -f2 -d' ').jar target/app.jar
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

ENTRYPOINT [ "java", "-Dspring.profiles.active=mysql", "-DdetailedDebugMode=true", "org.springframework.boot.loader.launch.JarLauncher" ]

