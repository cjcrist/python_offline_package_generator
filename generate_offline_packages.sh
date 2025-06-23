#!/bin/bash

set -euo pipefail

# --- Parse args ---
PKG_TYPE="${1:-deb}"  # deb or rpm
PYTHON_VERSION="${2:-3.10.4}"  # Python version to install

if [[ "$PKG_TYPE" != "deb" && "$PKG_TYPE" != "rpm" ]]; then
    echo "Usage: $0 [deb|rpm] [PYTHON_VERSION]"
    exit 1
fi

REQ_FILE="$(realpath requirements.txt)"
TMPDIR=$(mktemp -d)
TAG="offline-builder:${PKG_TYPE}-${PYTHON_VERSION}"
OUTFILE="offline_packages_${PKG_TYPE}.tar.gz"

# --- Select base image and install commands ---
if [[ "$PKG_TYPE" == "deb" ]]; then
    BASE_IMAGE="ubuntu:22.04"
    INSTALL_DEPS="apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential wget curl libssl-dev libbz2-dev \
        libreadline-dev libffi-dev libsqlite3-dev \
        zlib1g-dev xz-utils make ca-certificates python3-pip && \
        apt-get clean"
else
    BASE_IMAGE="quay.io/centos/centos:stream8"
    INSTALL_DEPS="sed -i \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        /etc/yum.repos.d/CentOS-*.repo && \
        dnf install -y wget curl gcc openssl-devel bzip2-devel \
        libffi-devel readline-devel sqlite-devel zlib-devel \
        make xz tar python3-pip && \
        dnf clean all"
fi

# --- Create Dockerfile ---
cat > "$TMPDIR/Dockerfile" <<EOF
FROM $BASE_IMAGE

RUN $INSTALL_DEPS

WORKDIR /src

RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xzf Python-${PYTHON_VERSION}.tgz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && \
    make -j\$(nproc) && \
    make altinstall

COPY requirements.txt .

RUN mkdir -p /offline_packages && \
    /usr/local/bin/python${PYTHON_VERSION%.*} -m pip install --upgrade pip && \
    /usr/local/bin/python${PYTHON_VERSION%.*} -m pip download \
        --dest /offline_packages \
        --requirement requirements.txt \
        --no-binary=:none: \
        --only-binary=:all: || true

CMD ["tar", "-czf", "/$OUTFILE", "-C", "/", "offline_packages"]
EOF

# Copy requirements into build context
cp "$REQ_FILE" "$TMPDIR/requirements.txt"

# --- Build image (forcing x86_64 for compatibility) ---
DOCKER_BUILDKIT=1 docker build --no-cache --platform linux/amd64 --load -t "$TAG" "$TMPDIR"

# --- Run container and extract archive ---
CID=$(docker create "$TAG")
docker start -a "$CID"
docker cp "$CID:/$OUTFILE" .
docker rm "$CID"
rm -rf "$TMPDIR"

echo "[✔] $OUTFILE created with wheels and source packages for Python $PYTHON_VERSION on $PKG_TYPE (x86_64)"

