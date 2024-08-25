#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download ollama release binaries (e.g., for v0.3.6) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  echo "CNI version current value is 'latest'"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unknown architecture ('${ARCH}') provided, supported values are 'amd64', 'arm64'."
  exit 1
fi

VERSION="v${VERSION#v}"

BIN_URL="https://github.com/ollama/ollama/releases/download/${VERSION}/ollama-linux-${ARCH}"
SHA_URL="https://github.com/ollama/ollama/releases/download/${VERSION}/sha256sum.txt"

rm -rf "${SYSEXTNAME}"

TMP_DIR="${SYSEXTNAME}/tmp"
mkdir -p "${TMP_DIR}"

curl --parallel --fail --silent --show-error --location \
  --output "${TMP_DIR}/ollama-linux-${ARCH}" "${BIN_URL}" \
  --output "${TMP_DIR}/sha256sums" "${SHA_URL}"

pushd "${TMP_DIR}" > /dev/null
grep "ollama-linux-${ARCH}$" ./sha256sums | sha256sum -c -
popd  > /dev/null

mkdir -p "${SYSEXTNAME}"/usr/local/bin

mv "${TMP_DIR}/ollama-linux-${ARCH}" "${SYSEXTNAME}/usr/local/bin/ollama"
chmod +x "${SYSEXTNAME}/usr/local/bin/ollama"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/ollama.service" <<-'EOF'
[Unit]
Description=Ollama
Documentation=https://github.com/ollama/ollama/tree/main/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
Restart=always

[Install]
WantedBy=multi-user.target
EOF

rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
