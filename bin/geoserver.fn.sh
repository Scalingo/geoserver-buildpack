#!/usr/bin/env bash


# Retrieves GeoServer .war, either by fetching it from the cache or by
# downloading it. Ensure geoserver.war is present in the build dir
#
# Usage: get_geoserver <build_dir> <cache_dir> <version>
#
get_geoserver() {
    local build_d=$1
    local cache_d=$2
    local version=$3

    local archive_name="geoserver-${version}-war.zip"
    local url="https://sourceforge.net/projects/geoserver/files/GeoServer/${version}/${archive_name}"
    local zip_cache_file="${cache_d}/geoserver-${version}.zip"

    if [ ! -f "${zip_cache_file}" ] ; then
        echo "Downloading GeoServer ${version}"
        curl --retry 3 --silent --location "${url}" \
            --output "${zip_cache_file}"
    else
        echo "---> Retrieving GeoServer ${version} from cache"
    fi

    # Either we got geoserver zip from the cache of from the project page
    unzip -qq -o "${zip_cache_file}" -d "${build_d}/geoserver-${version}"

    # Ensure we have a working link to current war version in $build_dir/geoserver.war
    pushd "${build_d}" > /dev/null \
        && ln -sfn "geoserver-${version}/geoserver.war" "geoserver.war" \
        && popd > /dev/null
}


# Starts GeoServer locally so we can inject the configuration.
# Returns the pid of the process.
#
# Usage: run_geoserver <build_dir> <port>
#
run_geoserver() {
    local build_d
    local port

    build_d="${1}"
    port="${2}"

    # Starts the webserver in background (will be killed later)
    java ${JAVA_OPTS:-} -jar "${build_d}/webapp-runner.jar" \
        --port "${port}" \
        "${build_d}/geoserver.war" \
        > out.log 2>&1 &
}


# Stops the process corresponding to the given PID.
#
# Usage: stop_geoserver <pid>
#
stop_geoserver() {
    local pid
    local waited

    pid="${1}"
    waited=0

    set +e

    kill -SIGTERM "${pid}"

    while [ ${waited} -lt 180 ]
    do
        sleep 1

        kill -0 "${pid}" > /dev/null 2>&1 \
            || break

        ((waited++))
    done

    kill -0 "${pid}" > /dev/null 2>&1 \
        && {
            kill -SIGKILL "${pid}"
            echo "!! Temporary GeoServer was not responding and has been killed."
            echo "!! Stopping build as this may have introduced data corruption."
            exit 1
        }

    set -e
}


# Installs Java and webapp_runner
#
# Usage: install_webapp_runner <build_dir> <cache_dir> <java_version> <webapp_runner_version>
#
install_webapp_runner() {
    local jvm_url
    local runner_url

    local build_d
    local cache_d

    local tmp_d
    local jre_version
    local runner_version

    local cached_jvm_common
    local cached_runner

    build_d="${1}"
    cache_d="${2}"
    jre_version="${3}"
    runner_version="${4}"

    jvm_url="https://buildpacks-repository.s3.eu-central-1.amazonaws.com/jvm-common.tar.xz"
    runner_url="https://buildpacks-repository.s3.eu-central-1.amazonaws.com/webapp-runner-${runner_version}.jar"

    # Install JVM common tools:
    cached_jvm_common="${cache_d}/jvm-common.tar.xz"

    if [ ! -f "${cached_jvm_common}" ]
    then
        curl --location --silent --retry 6 --retry-connrefused --retry-delay 0 \
            "${jvm_url}" \
            --output "${cached_jvm_common}"
    fi

    tmp_d=$( mktemp -d jvm-common-XXXXXX ) && {
        tar --extract --xz --touch --strip-components=1 \
            --file "${cached_jvm_common}" \
            --directory "${tmp_d}"

        # Source utilities and functions:
        source "${tmp_d}/bin/util"
        source "${tmp_d}/bin/java"

        echo "java.runtime.version=${jre_version}" \
            > "${build_d}/system.properties"

        install_java_with_overlay "${build_d}"

        rm -Rf "${tmp_d}"
    }

    # Install Webapp Runner
    cached_runner="${cache_d}/webapp-runner-${runner_version}.jar"

    if [ ! -f "${cached_runner}" ]
    then
        curl --location --silent --retry 6 --retry-connrefused --retry-delay 0 \
            "${runner_url}" \
            --output "${cached_runner}" \
            || {
                echo "Unable to download webapp runner ${runner_version}. Aborting."
                exit 1
            }
    fi

    cp "${cached_runner}" "${build_d}/webapp-runner.jar"
}


# Prints out some environment variables.
#
# Usage: print_environment
#
print_environment() {
    echo -e "     GEOSERVER_VERSION: ${geoserver_version}"
    echo -e "     GEOSERVER_CONFIG_SCRIPT: ${geoserver_config_script}"
    echo -e "     GEOSERVER_DATA_DIR: ${geoserver_data_dir}"
    echo -e "     JAVA_VERSION: ${java_version}"
    echo -e "     JAVA_WEBAPP_RUNNER_VERSION: ${webapp_runner_version}"
}


# Checks whether all required environment variables are set or not.
#
# Usage: check_environment
#
check_environment() {
    local mandatory
    local mandatory_is_ok

    mandatory=(
        GEOSERVER_ADMIN_PASSWORD
        GEOSERVER_WORKSPACE_NAME
        GEOSERVER_DATASTORE_NAME
    )

    mandatory_is_ok=0

    for m in "${mandatory[@]}"
    do
        if [ -z "${!m}" ]
        then
            echo "!! Setting the ${m} environment variable is mandatory." >&2
            echo "!! Please set it and relaunch your deployment." >&2
            mandatory_is_ok=1
        fi
    done

    if [ -z "${SCALINGO_POSTGRESQL_URL}" ]
    then
        echo "!! This buildpack requires a PostgreSQL database addon." >&2
        mandatory_is_ok=1
    fi

    if [ ${mandatory_is_ok} -ne 0 ]
    then
        exit 1
    fi
}


# Split the DB connexion string into multiple environment variables
# so we can use them in the templates
#
# Usage: export_db_conn
#
export_db_conn() {
    DB_HOST="$( echo "${SCALINGO_POSTGRESQL_URL}" \
        | cut -d "@" -f2 | cut -d ":" -f1 )"

    DB_USER="$( echo "${SCALINGO_POSTGRESQL_URL}" \
        | cut -d "/" -f3 | cut -d ":" -f1 )"

    DB_PORT="$( echo "${SCALINGO_POSTGRESQL_URL}" \
        | cut -d ":" -f4 | cut -d "/" -f1 )"

    DB_PASS="$( echo "${SCALINGO_POSTGRESQL_URL}" \
        | cut -d "@" -f1 | cut -d ":" -f3 )"

    DB_NAME="$( echo "${SCALINGO_POSTGRESQL_URL}" \
        | cut -d "?" -f1 | cut -d "/" -f4 )"

    export DB_HOST
    export DB_USER
    export DB_PORT
    export DB_PASS
    export DB_NAME
}


# Interpolates variables present in the given template.
#
# Usage: do_template <template_file>
#
do_template() {
    local src
    local dst

    src="${1}"
    # dst is the same as src, exept we remove the '.erb' suffix:
    dst="${src%.erb}"

    # Process the template:
    erb "${src}" > "${dst}"
}


# Enforces the disk space dedicated to GeoWebCache.
#
# Usage: enforce_geowebcache_diskquota <buildpack_dir>
#
# !! Don't use an API call to do this, it won't persist during the
# BUILD --> RUN transition.
#
enforce_geowebcache_diskquota() {
    local buildpack_d

    buildpack_d="${1}"

    mkdir -p "${GEOSERVER_DATA_DIR}/gwc"

    cp "${buildpack_d}/config/geowebcache-diskquota.xml" \
        "${GEOSERVER_DATA_DIR}/gwc/"
}


# Enforces logging to stdout.
#
# Usage: enforce_logging_to_stdout <buildpack_dir>
#
enforce_logging_to_stdout() {
    local buildpack_d
    local url
    local user
    local pass

    buildpack_d="${1}"
    url="${2}"
    user="${3}"
    pass="${4}"

    mkdir -p "${GEOSERVER_DATA_DIR}/logs"

    cp "${buildpack_d}/config/SCALINGO_LOGGING.xml" \
        "${GEOSERVER_DATA_DIR}/logs/"

    # !! For some reason, using '--fail' with this one makes curl crash.
    # Redirecting outputs to /dev/null instead.
    curl -4 --silent --show-error --request PUT \
        "${url}/rest/logging" \
        --user "${user}":"${pass}" \
        --header "Content-Type: application/json" \
        --data "@${buildpack_d}/config/logging.json" \
        > /dev/null 2>&1
}


# Removes masterpw.info file.
#
# Usage: remove_masterpw
#
remove_masterpw() {
    rm -f "${GEOSERVER_DATA_DIR}/security/masterpw.info"
}


# Sets admin user account password.
#
# Usage: set_admin_password <buildpack_dir> <url> <user> <pass>
#
set_admin_password() {
    local buildpack_d
    local url
    local user
    local pass

    buildpack_d="${1}"
    url="${2}"
    user="${3}"
    pass="${4}"

    curl -4 --silent --fail --show-error --request PUT \
        "${url}/rest/security/self/password" \
        --user "${user}":"${pass}" \
        --header "Content-Type: application/json" \
        --data "@${buildpack_d}/config/adminpw.json"
}


# Creates the GEOSERVER_WORKSPACE_NAME workspace.
#
# Usage: create_workspace <buildpack_dir> <url> <user> <pass>
#
create_workspace() {
    local buildpack_d
    local url
    local user
    local pass

    buildpack_d="${1}"
    url="${2}"
    user="${3}"
    pass="${4}"

    # Make sure the workspace doesn't exist:
    # (also make sure this won't fail when the workspace does not exist yet)

    curl -4 --silent --fail --show-error --request DELETE \
        "${url}/rest/workspaces/${GEOSERVER_WORKSPACE_NAME}?recurse=true" \
        --user "${user}":"${pass}" \
        || true

    curl -4 --silent --fail --show-error --request POST \
        "${url}/rest/workspaces" \
        --user "${user}":"${pass}" \
        --header "Content-Type: application/json" \
        --data "@${buildpack_d}/config/workspace.json"
}


# Creates the GEOSERVER_DATASTORE_NAME datastore in the
# GEOSERVER_WORKSPACE_NAME workspace.
#
# Usage: create_datastore <buildpack_dir> <url> <user> <pass>
#
create_datastore() {
    local buildpack_d
    local url
    local user
    local pass

    buildpack_d="${1}"
    url="${2}"
    user="${3}"
    pass="${4}"

    curl -4 --silent --fail --show-error --request POST \
        "${url}/rest/workspaces/${GEOSERVER_WORKSPACE_NAME}/datastores" \
        --user "${user}":"${pass}" \
        --header "Content-Type: application/json" \
        --data "@${buildpack_d}/config/datastore.json"
}

readonly -f get_geoserver
readonly -f run_geoserver
readonly -f stop_geoserver
readonly -f install_webapp_runner
readonly -f check_environment
readonly -f print_environment
readonly -f export_db_conn
readonly -f do_template
readonly -f enforce_geowebcache_diskquota
readonly -f enforce_logging_to_stdout
readonly -f remove_masterpw
readonly -f set_admin_password
readonly -f create_workspace
readonly -f create_datastore
