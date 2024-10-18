# Set up script to install Kubernetes using Kubernetes documentation as reference.
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# The following will be installed and is universal for both control and worker nodes:
# OS: RHEL 9
# Container Runtime: containerd v1.7.22
# Kubernetes Version: v1.31
# runc version: v1.1.15
# cniplugin :amd64-v1.5.1


#Turn off swap in /etc/fstab
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Open required ports
sudo firewall-cmd --zone=public --add-port=6443/tcp --add-port=2379-2380/tcp \
  --add-port=10250/tcp --add-port=10259/tcp --add-port=10257/tcp --permanent
sudo firewall-cmd --reload

# Install socat
sudo yum install socat -y

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Add the Kubernetes yum repository for Kubernetes 1.31
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install kubelet, kubeadm, and kubectl
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable the kubelet service before running kubeadm
sudo systemctl enable --now kubelet

# Installing containerd
# Refer to https://github.com/containerd/containerd/releases to get the latest release

# Install wget and tar if not already installed
sudo yum install -y wget tar

# Change directory to ~/Downloads/
cd ~/Downloads/

# Download containerd
wget -Nv https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-1.7.22-linux-amd64.tar.gz
wget -Nv https://github.com/containerd/containerd/releases/download/v1.7.22/containerd-1.7.22-linux-amd64.tar.gz.sha256sum

# Verify checksum and stop if verification fails
sha256sum -c containerd-1.7.22-linux-amd64.tar.gz.sha256sum || { echo "Checksum verification failed."; exit 1; }

# Extract to /usr/local/
sudo tar Cxzvf /usr/local containerd-1.7.22-linux-amd64.tar.gz

# To start containerd via systemd, download containerd.service
sudo mkdir -p /usr/local/lib/systemd/system/
cd /usr/local/lib/systemd/system/
wget -Nv https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# Run containerd.service
sudo systemctl daemon-reload && sudo systemctl enable --now containerd

# Download runc
wget -Nv https://github.com/opencontainers/runc/releases/download/v1.1.15/runc.amd64
wget -Nv https://github.com/opencontainers/runc/releases/download/v1.1.15/runc.sha256sum

# Verify checksum
#sha256sum -c runc.sha256sum || { echo "Checksum verification failed."; exit 1; }
# Verify the checksum
# Extract the checksum for runc.amd64 and ignore others
CHECKSUM=$(grep 'runc.amd64' runc.sha256sum | awk '{print $1}')

# Calculate the checksum of the downloaded file
CALCULATED_CHECKSUM=$(sha256sum runc.amd64 | awk '{print $1}')

# Compare the checksums
if [[ "$CHECKSUM" == "$CALCULATED_CHECKSUM" ]]; then
    echo "Checksum verification passed. Continuing installation..."
    
    # Install runc
    sudo install -m 755 runc.amd64 /usr/local/sbin/runc
else
    echo "Checksum verification failed. Exiting."
    exit 1
fi

# Install runc
#sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# Download CNI plugins
cd ~/Downloads/
wget -Nv https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz
wget -Nv https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz.sha256

# Verify checksum
sha256sum -c cni-plugins-linux-amd64-v1.5.1.tgz.sha256 || { echo "Checksum verification failed."; exit 1; }

# Extract CNI plugins
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin/ cni-plugins-linux-amd64-v1.5.1.tgz

# Use containerd to generate a default config file
sudo mkdir -p /etc/containerd/
#sudo containerd config default | sudo tee /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml

# Configure systemd cgroup driver
#sudo tee -a /etc/containerd/config.toml > /dev/null <<EOF
#[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#    SystemdCgroup = true
#EOF

# Path to the containerd configuration file
CONFIG_FILE="/etc/containerd/config.toml"

# Check if the config file exists
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check for the specific SystemdCgroup setting
SYSTEMD_CGROUP_LINE=$(grep -A 12 '\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]' "$CONFIG_FILE" | grep 'SystemdCgroup')

if [[ $SYSTEMD_CGROUP_LINE == *"SystemdCgroup = false"* ]]; then
    echo "Changing SystemdCgroup from false to true in $CONFIG_FILE"
    sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/,/^\s*$/s/SystemdCgroup = false/SystemdCgroup = true/' "$CONFIG_FILE"
    sudo systemctl restart containerd
    echo "Containerd service restarted."
elif [[ -z $SYSTEMD_CGROUP_LINE ]]; then
    echo "Adding SystemdCgroup = true to the configuration in $CONFIG_FILE"
    # Add the SystemdCgroup setting if it doesn't exist
    sudo tee -a "$CONFIG_FILE" > /dev/null <<EOF

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF
    sudo systemctl restart containerd
    echo "Containerd service restarted."
else
    echo "SystemdCgroup is already set to true in $CONFIG_FILE."
fi

# Display the current setting
echo "Current setting of SystemdCgroup:"
grep 'SystemdCgroup' "$CONFIG_FILE"

# Restart containerd
sudo systemctl restart containerd

# Configure kubelet cgroup driver
sudo tee /var/lib/kubelet/config.yaml > /dev/null <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: "systemd"
EOF

echo "Kubernetes installation setup is complete."
