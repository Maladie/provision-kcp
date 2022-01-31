# Name of the cluster you want to create
CLUSTER_NAME=
# Name of your docker account
DOCKER_ROOT=
# Your email to generate certificate
YOUR_EMAIL=

# Path to file containing Gardener SA Key
GARDENER_KUBECONFIG_PATH=
# Gardener project name
GARDENER_PROJECT_NAME=

DOMAIN=${CLUSTER_NAME}.${GARDENER_PROJECT_NAME}.shoot.canary.k8s-hana.ondemand.com

PROVISIONING_ENABLED="true"

# Kyma version to install
KYMA_VERSION=1.23.0
