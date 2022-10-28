#!/usr/bin/env bash

jvm_flags="${JAVA_OPTS:-''}"

if [ -z "${GEOSERVER_ENABLE_WEBUI}" ]
then
    # Disable the Web UI unless GEOSERVER_ENABLE_WEBUI is set
    jvm_flags="-DGEOSERVER_CONSOLE_DISABLED=true ${jvm_flags}"
fi

java ${jvm_flags} \
    -jar "${HOME}/webapp-runner.jar" \
    --port "${PORT}" \
    "${HOME}/geoserver.war"
