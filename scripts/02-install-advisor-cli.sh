#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 02-install-advisor-cli.sh
#
# Downloads and installs the Advisor CLI from Artifactory.
#
# Required environment variables:
#   ARTIFACTORY_TOKEN  - Bearer token for Artifactory authentication
#   ADVISOR_VERSION    - Version of the Advisor CLI to download
# ------------------------------------------------------------------------------
set -euo pipefail

: "${ARTIFACTORY_TOKEN:?ARTIFACTORY_TOKEN is required}"
: "${ADVISOR_VERSION:?ADVISOR_VERSION is required}"

echo "Downloading advisor CLI version ${ADVISOR_VERSION}..."
curl -fsSL \
  -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
  -o advisor-cli.tar \
  "https://packages.broadcom.com/artifactory/spring-enterprise/com/vmware/tanzu/spring/application-advisor-cli-linux/${ADVISOR_VERSION}/application-advisor-cli-linux-${ADVISOR_VERSION}.tar"

tar -xf advisor-cli.tar --strip-components=1 --exclude=META-INF
chmod +x advisor
sudo mv advisor /usr/local/bin/
rm -f advisor-cli.tar

echo "Advisor CLI installed:"
advisor --version || echo "advisor CLI ready"
