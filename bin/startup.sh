#!/usr/bin/env bash

if [ -z "${GEOSERVER_ENABLE_WEBUI}" ]
then
    # Disable the Web UI unless GEOSERVER_ENABLE_WEBUI is set
    JAVA_OPTS="-DGEOSERVER_CONSOLE_DISABLED=true ${JAVA_OPTS:-''}"
    export JAVA_OPTS
else
    # Web UI is enabled
    if [ -z "{GEOSERVER_ENABLE_LOGIN_AUTOCOMPLETE}" ]
    then
        # Disable login autocomplete unless GEOSERVER_ENABLE_LOGIN_AUTOCOMPLETE is set
        JAVA_OPTS="-Dgeoserver.login.autocomplete=off ${JAVA_OPTS:-}"
        export JAVA_OPTS
    fi
fi

java ${JAVA_OPTS} \
    -jar "${HOME}/webapp-runner.jar" \
    --port "${PORT}" \
    "${HOME}/geoserver.war"
