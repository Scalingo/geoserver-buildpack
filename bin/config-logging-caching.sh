#!/usr/bin/env bash

echo "---> Enforcing GeoWebCache disk quota"

mkdir -p "${GEOSERVER_DATA_DIR}/gwc"

cp "${buildpack_dir}/config/geowebcache-diskquota.xml" \
    "${GEOSERVER_DATA_DIR}/gwc/"

# !! This API call won't persist during the BUILD-->RUN transition.
# Replaced by the above command.
#
#curl --request "PUT" \
#    "${temp_host}/gwc/rest/diskquota.json" \
#    --user "${default_user}":"${default_pass}" \
#    --header "Content-Type: application/json" \
#    --data "@${buildpack_dir}/config/gwc.json"


echo "---> Enforcing logging to stdout"

mkdir -p "${GEOSERVER_DATA_DIR}/logs"

cp "${buildpack_dir}/config/SCALINGO_LOGGING.xml" \
    "${GEOSERVER_DATA_DIR}/logs/"

# !! curl's `--fail` option makes this request fail
#
curl --silent --show-error -4 --request "PUT" \
    "${temp_host}/rest/logging" \
    --user "${default_user}":"${default_pass}" \
    --header "Content-Type: application/json" \
    --data "@${buildpack_dir}/config/logging.json" \
    > /dev/null 2>&1


echo "---> Removing master password file"

rm -f "${GEOSERVER_DATA_DIR}/security/masterpw.info"


echo "---> Setting admin password"

curl "${curl_opts[@]}" --request "PUT" \
    "${temp_host}/rest/security/self/password" \
    --user "${default_user}":"${default_pass}" \
    --header "Content-Type: application/json" \
    --data "@${buildpack_dir}/config/adminpw.json"

curl "${curl_opts[@]}" --request "PUT" \
    "${temp_host}/rest/reload" \
    --user "${default_user}":"${default_pass}"
