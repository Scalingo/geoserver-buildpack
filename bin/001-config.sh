#!/usr/bin/env bash

echo "---> Creating ${GEOSERVER_WORKSPACE_NAME} workspace"

# Make sure the workspace doesn't exist:
# (also make sure this won't make the buildpack fail)
curl "${curl_opts[@]}" --request "DELETE" \
    "${temp_host}/rest/workspaces/${GEOSERVER_WORKSPACE_NAME}?recurse=true" \
    --user "${default_user}":"${default_pass}" \
    || true

# Create the workspace:
curl "${curl_opts[@]}" --request "POST" \
    "${temp_host}/rest/workspaces" \
    --user "${default_user}":"${default_pass}" \
    --header "Content-Type: application/json" \
    --data "@${buildpack_dir}/config/workspace.json"


echo "---> Creating ${GEOSERVER_DATASTORE_NAME} datastore"

curl "${curl_opts[@]}" --request "POST" \
    "${temp_host}/rest/workspaces/${GEOSERVER_WORKSPACE_NAME}/datastores" \
    --user "${default_user}":"${default_pass}" \
    --header "Content-Type: application/json" \
    --data "@${buildpack_dir}/config/datastore.json"

