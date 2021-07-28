#!/bin/bash -eu

set -o pipefail

STACK_VER="${ELASTIC_STACK_VERSION:-7.13.4}"
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1:5601}"
KIBANA_AUTH="${KIBANA_URL:-vagrant:vagrant}"
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://127.0.0.1:9200}"

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

    #SERVICE_TOKEN=$(curl --silent -u vagrant:vagrant -H "kbn-xrsf: fleet" http://127.0.0.1:5601/api/fleet/service-tokens | jq -r '.value')

    sudo ./elastic-agent install --force --fleet-server-es="${ELASTICSEARCH_URL}" --fleet-server-service-token="${SERVICE_TOKEN}"
    # Cleanup temporary directory
    cd ..
    rm -rf "$(pwd)"
}

# Create and retrieve service token
function get_fleet_server_service_token() {
    declare -a AUTH=()
    declare -a HEADERS=(
        "-H" "Content-Type: application/json"
        "-H" "kbn-xrsf: fleet"
    )

    if [ -n "${KIBANA_AUTH}" ]; then
        AUTH=("-u" "${KIBANA_AUTH}")
    fi

    fleet_service_token=$(curl -XPOST --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/service-tokens" | jq -r '.value')
    
    echo ${fleet_service_token}
    echo ${AUTH[@]}
    echo ${HEADERS[@]}
    echo -n "${fleet_service_token}"
}

install_jq
download_and_install_fleet_server
