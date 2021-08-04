
#!/bin/bash -eu

set -o pipefail

STACK_VER="${ELASTIC_STACK_VERSION:-7.14.0}"
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1:5601}"
KIBANA_AUTH="${KIBANA_AUTH:-}"
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://127.0.0.1:9200}"

AGENT_URL="https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-${STACK_VER}-linux-x86_64.tar.gz"

function install_jq() {
    if ! command -v jq; then
        sudo yum install -y jq
    fi
}

function download_and_install_agent () {
    declare -a AUTH=()
    declare -a HEADERS=(
        "-H" "Content-Type: application/json" 
        "-H" "kbn-xsrf: fleet"
    )

    if [ -n "${KIBANA_AUTH}" ]; then
        AUTH=("-u" "${KIBANA_AUTH}")
    fi

    echo "Setting up Fleet Server. This could take a minute.."
    curl --silent -XPOST "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/setup" | jq
    sudo firewall-cmd --add-port=8220/tcp --permanent
    sudo firewall-cmd --reload
    
    response_policy_id=$(curl --silent -XGET "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/agent_policies" | jq --raw-output '.items[] | select(.name | startswith("Default Fleet")))" | .id'
    policy_id_api_key=$(curl --silent "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/enrollment-api-keys" | jq --arg response_policy_id "$POLICY_ID" -r '.list[] | select(.id | startswith("$POLICY_ID")) | .policy_id')
    response_service_token=$(curl --silent -XPOST "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/service-tokens" | jq -r '.value')
    POLICY_ID=$(echo -n "${response_policy_id}")
    SERVICE_TOKEN=$(echo -n "${response_service_token}")

    #echo -n "${ENROLLMENT_TOKEN}"

    cd "$(mktemp -d)"
    curl --silent -LJ "${AGENT_URL}" | tar xzf -
    cd "$(basename "$(basename "${AGENT_URL}")" .tar.gz)"
    sudo ./elastic-agent install --force --fleet-server-es="${ELASTICSEARCH_URL}" --fleet-server-service-token="${SERVICE_TOKEN}" --fleet-server-policy "${POLICY_ID}"
    
    # Cleanup temporary directory
    cd ..
    rm -rf "$(pwd)"
}

install_jq
download_and_install_agent
