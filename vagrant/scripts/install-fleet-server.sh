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
    
    systemctl is-active --quiet elasticsearch && echo Elasticsearch is running. Checking Kibana
    systemctl is-active --quiet kibana && echo Kibana service is running, making sure we can login..


    # Wait for Kibana to become available
    echo "This part could take a few minutes, please let it complete."
    while true
    do
      STATUS=$(curl -I http://192.168.33.10:5601/login 2>/dev/null | head -n 1 | cut -d$' ' -f2)
      if [ "${STATUS}" == "200" ]; then
        echo "Setting up Fleet Server";
        break
      else
        echo "Kibana isn't up yet. Trying again in 10 seconds"
      fi
      sleep 10
    done

    sudo firewall-cmd --add-port=8220/tcp --permanent
    sudo firewall-cmd --reload

    POLICY_ID=$(curl --silent -XGET "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/agent_policies" | jq --raw-output '.items[] | select(.name | startswith("Default Fleet")) | .id')

    SERVICE_TOKEN=$(curl --silent -XPOST "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/service-tokens" | jq -r '.value')

    curl --silent -XPOST "${AUTH[@]}" "${HEADERS[@]}" "${KIBANA_URL}/api/fleet/setup" | jq;
    
    echo "Enrolling agent using policy ID: "${POLICY_ID}" and service token: "${SERVICE_TOKEN}""

    cd "$(mktemp -d)"
    curl --silent -LJ "${AGENT_URL}" | tar xzf -
    cd "$(basename "$(basename "${AGENT_URL}")" .tar.gz)"
    sudo ./elastic-agent install -f --fleet-server-es="${ELASTICSEARCH_URL}" --fleet-server-service-token="${SERVICE_TOKEN}" --fleet-server-policy "${POLICY_ID}"
    
    # Cleanup temporary directory
    cd ..
    rm -rf "$(pwd)"
}

install_jq
download_and_install_agent
