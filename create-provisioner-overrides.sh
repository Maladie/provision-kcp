#!/usr/bin/env bash

set -e

ENV_FILE=${ENV_FILE:=env}

# Gardener kubeconfig
GARDENER_KUBECONFIG_PATH=${GARDENER_KUBECONFIG_PATH}
# Gardener project name
GARDENER_PROJECT_NAME=${GARDENER_PROJECT_NAME}

NAMESPACE=${NAMESPACE:="kcp-installer"}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/${ENV_FILE}

discoverUnsetVar=false
for var in GARDENER_KUBECONFIG_PATH; do
  if [ -z "${!var}" ] ; then
    echo "ERROR: $var is not set"
    discoverUnsetVar=true
  fi
done
if [ "${discoverUnsetVar}" = true ] ; then
  exit 1
fi

"${DIR}/create-config-map.sh" --namespace "$NAMESPACE" --name "provisioner-overrides" \
    --data "global.provisioning.enabled=true" \
    --data "provisioner.gardener.kubeconfig=$(base64 < "${GARDENER_KUBECONFIG_PATH}")" \
    --data "provisioner.gardener.project=$GARDENER_PROJECT_NAME" \
    --label "component=kcp"

