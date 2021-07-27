#!/bin/bash -eu

set -o pipefail

STACK_VER="${ELASTIC_STACK_VERSION:-7.12.1}"
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1:5601}"
KIBANA_AUTH="${KIBANA_AUTH:-}"

AGENT_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VER}-linux-x86_64.tar.gz"

function install_jq() {
    if ! command -v jq; then
        sudo yum install -y jq
    fi
}
function download_and_install_fleet_server() {
    SERVICE_TOKEN=$(get_fleet_server_service_token)

    cd "$(mktemp -d)"
    curl --silent -LJ "${AGENT_URL}" | tar xzf -
    cd "$(basename "$(basename "${AGENT_URL}")" .tar.gz)"
    #curl -XPOST -H "Content-Type: application/json" -H "kbn-xsrf: fleet" -u vagrant:vagrant http://localhost:5601/api/fleet/service-tokens
    #sudo ./elastic-agent install --force --insecure --kibana-url="${KIBANA_URL}" --enrollment-token="${ENROLLMENT_TOKEN}"
    sudo ./elastic-agent enroll -f --fleet-server-es=http://localhost:9200 --fleet-server-service-token="$(SERVICE_TOKEN}"
    # Cleanup temporary directory
    cd ..
    rm -rf "$(pwd)"
}

# Retrieve API keys
function get_fleet_server_service_token() {
    declare -a AUTH=()
    declare -a HEADERS=(
        "-H" "Content-Type: application/json",
        "-H" "kbn-xrsf: fleet"
    )

    if [ -n "${KIBANA_AUTH}" ]; then
        AUTH=("-u" "${KIBANA_AUTH}")
    fi

    response=$(curl --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/service-tokens")
    fleet_service_token_value=$(echo -n "${response}" | jq -r '.value'
    fleet_service_token=$(curl --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/service-tokens/${enrollment_key_id}" | jq -r '.item.value')

    echo -n "${fleet_service_token}"
}

install_jq
download_and_install_fleet_server
