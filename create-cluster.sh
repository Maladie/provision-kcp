#!/usr/bin/env bash

set -e

ENV_FILE=${ENV_FILE:=env}

INSTALLER_CR_PATH=$GOPATH/src/github.com/kyma-project/control-plane/installation/resources/installer-cr-kyma-dependencies.yaml
OVERRIDES_KYMA=$GOPATH/src/github.com/kyma-project/control-plane/installation/resources/installer-overrides-kyma.yaml

# Tag for the newly built installer image
KCP_INSTALLER_TAG=${KCP_INSTALLER_TAG:=latest}
# Create cluster. If false will use exisitng one
CREATE_CLUSTER=${CREATE_CLUSTER:=true}
# Kubernetes version
KUBERNETES_VERSION=${KUBERNETES_VERSION:=1.16}

KYMA_VERSION=${KYMA_VERSION:=master}
COMPASS_VERSION=${COMPASS_VERSION:=master}

function applyCommonOverrides() {
  NAMESPACE=${1}

  "${DIR}/create-config-map.sh" --namespace $NAMESPACE --name "installation-config-overrides" \
    --data "global.domainName=${DOMAIN}"

  "${DIR}/create-config-map.sh" --namespace $NAMESPACE --name "global-ingress-overrides" \
    --data "global.ingress.domainName=${DOMAIN}" \
    --data "global.ingress.tlsCrt=${TLS_CERT}" \
    --data "global.ingress.tlsKey=${TLS_KEY}" \
    --data "global.environment.gardener=false"

  "${DIR}/create-config-map.sh" --namespace $NAMESPACE --name "cluster-certificate-overrides" \
    --data "global.tlsCrt=${TLS_CERT}" \
    --data "global.tlsKey=${TLS_KEY}"

  "${DIR}/create-config-map.sh" --namespace $NAMESPACE --name "kyma-overrides" --label "component=compass" \
    --data "global.disableLegacyConnectivity=true"

}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source $DIR/${ENV_FILE}

echo "Starting provisioning runtime on shoot '$CLUSTER_NAME'"
# ----------------------------------------------------------------------------------------------------
kyma provision gardener gcp -n $CLUSTER_NAME -p frog-dev -s my-gcp-secret -c $GARDENER_KUBECONFIG_PATH
# ----------------------------------------------------------------------------------------------------

pushd $GOPATH/src/github.com/kyma-project/control-plane

kyma install -c $INSTALLER_CR_PATH -o $OVERRIDES_KYMA -s $KYMA_VERSION

pushd $GOPATH/src/github.com/kyma-project/kyma
./installation/scripts/is-installed.sh
popd

## Install Compass

"${DIR}/run-compass-installer.sh" ${DOMAIN}

## Install KCP

# Build KCP installer
docker build -t kcp-installer:latest -f tools/kcp-installer/kcp.Dockerfile .
docker tag kcp-installer:latest $DOCKER_ROOT/kcp-installer:$KCP_INSTALLER_TAG
docker push $DOCKER_ROOT/kcp-installer:$KCP_INSTALLER_TAG

kubectl create namespace "kcp-installer"

if [[ "$PROVISIONING_ENABLED" == true ]]; then
  echo "Provisioning is enabled"
  "${DIR}/create-provisioner-overrides.sh"
fi

applyCommonOverrides "kcp-installer"

KCP_INSTALLER_IMAGE="$DOCKER_ROOT/kcp-installer:$KCP_INSTALLER_TAG"
INSTALLER_YAML="installation/resources/installer.yaml"

INSTALLER_CR="installation/resources/installer-cr.yaml.tpl"

sed -e 's;image: eu.gcr.io/kyma-project/.*/installer:.*$;'"image: ${KCP_INSTALLER_IMAGE};" "${INSTALLER_YAML}" |
  kubectl apply -f-

# # Trigger installation
sed -e "s/__VERSION__/0.0.1/g" "${INSTALLER_CR}" | sed -e "s/__.*__//g" | kubectl apply -f-

# Wait
./installation/scripts/is-installed.sh
popd

echo "Installation finished!"
exit 0