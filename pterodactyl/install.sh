#!/bin/bash
# Pterodactyl install script for the Kyma dedicated server.
# Runs as root in the installer container, with the server files in /mnt/server.
set -euo pipefail

LOVE_VERSION="${LOVE_VERSION:-11.5}"
REPO_URL="${REPO_URL:-https://github.com/0xS4cha/kyma.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

apt-get update
apt-get install -y --no-install-recommends git curl ca-certificates

mkdir -p /mnt/server
cd /mnt/server

echo "Downloading LOVE ${LOVE_VERSION}"
rm -rf love squashfs-root love.AppImage
curl -fsSL -o love.AppImage "https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-x86_64.AppImage"
chmod +x love.AppImage
./love.AppImage --appimage-extract > /dev/null
mv squashfs-root love
rm -f love.AppImage

echo "Fetching Kyma from ${REPO_URL} (${REPO_BRANCH})"
rm -rf /tmp/kyma game
git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" /tmp/kyma
mkdir -p game data
cp -r /tmp/kyma/server/. game/
cp -r /tmp/kyma/src game/
cp -r /tmp/kyma/libs game/
git -C /tmp/kyma rev-parse --short HEAD > game/REVISION
rm -rf /tmp/kyma

echo "Kyma installed at revision $(cat game/REVISION)"
