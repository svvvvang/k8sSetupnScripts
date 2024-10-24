#!/bin/bash

# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then
    CLI_ARCH=arm64
fi

# Download Cilium CLI
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify the SHA256 checksum
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

# Extract Cilium binary to /usr/local/bin
sudo tar xzvf cilium-linux-${CLI_ARCH}.tar.gz -C /usr/local/bin

# Remove downloaded files
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Create folder for cilium if it doesn't exist
sudo mkdir -p /hostbin

# Install Cilium
cilium install

# Change owner to root for /usr/local/bin/cilium
sudo chown root:root /usr/local/bin/cilium

echo "Cilium CLI installation completed successfully."

