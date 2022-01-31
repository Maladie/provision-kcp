#!/usr/bin/env bash

set -o errexit

INSTALLATION_DIR=$GOPATH/src/github.com/kyma-project/control-plane/installation
RESOURCES_DIR="${INSTALLATION_DIR}/resources"
COMPASS_OVERRIDES="${RESOURCES_DIR}/installer-overrides-compass.yaml"
COMPASS_CR="${RESOURCES_DIR}/installer-cr-compass-dependencies.yaml"
TMP_DIR="${INSTALLATION_DIR}/tmp-compass"

DOMAIN=$1

function cleanup {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "
################################################################################
# Prepare Compass artifacts
################################################################################
"

mkdir -p "$TMP_DIR"
readonly RELEASE=$(<"${RESOURCES_DIR}"/COMPASS_VERSION)
curl -L "https://storage.googleapis.com/kyma-development-artifacts/compass/${RELEASE}/compass-installer.yaml" -o "${TMP_DIR}/compass-installer.yaml"
curl -L "https://storage.googleapis.com/kyma-development-artifacts/compass/${RELEASE}/is-installed.sh" -o "${TMP_DIR}/is-compass-installed.sh"

sed -i.bak '/action: install/d' "${TMP_DIR}/compass-installer.yaml"
COMBO_YAML=$(bash ${INSTALLATION_DIR}/scripts/concat-yamls.sh ${COMPASS_OVERRIDES} ${TMP_DIR}/compass-installer.yaml ${COMPASS_CR})
COMBO_YAML=$(sed 's/\.domainName: .*/\.domainName: '"${DOMAIN}"'/g' <<<"$COMBO_YAML")
COMBO_YAML=$(sed 's/\.ingress.domainName: .*/\.ingress.domainName: '"${DOMAIN}"'/g' <<<"$COMBO_YAML")
COMBO_YAML=$(sed 's/\.isLocalEnv: .*/\.isLocalEnv: "false" /g' <<<"$COMBO_YAML")

echo "
################################################################################
# Install Compass version ${RELEASE}
################################################################################
"

echo "Creating Compass Installer Namespace"
kubectl create ns compass-installer
echo "Applying Compass Configuration"
kubectl apply -f - <<< "$COMBO_YAML" --validate=false
bash "${TMP_DIR}/is-compass-installed.sh"