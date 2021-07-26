#!/bin/bash -eu

set -o pipefail

# Define variables
STACK_VER="${ELASTIC_STACK_VERSION:-7.12.1}"
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1:5601}"
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://127.0.0.1:9200}"
KIBANA_AUTH="${KIBANA_AUTH:-}"

echo "Be sure to edit the Elastic Stack version variable to the version of the Elastic Stack you want before running this script."


# if running stop Elasticsearch and kibana

systemctl stop elasticsearch kibana



# Install wget if it isn't installed

function install_wget() {
    if ! command -v wget >/dev/null; then
        sudo yum install -y wget
    fi
}


wget https://artifacts.elastic.co/downloads/kibana/kibana-${STACK_VER}-x86_64.rpm

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${STACK_VER}-x86_64.rpm

rpm -U elasticsearch-${STACK_VER}-x86_64.rpm
rpm -U kibana-${STACK_VER}-x86_64.rpm

systemctl start elasticsearch kibana