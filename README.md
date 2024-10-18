# k8sInstallationScript.sh
Kubernetes Installation Setup Script for RHEL 9
Script is universal to both control and worker node

This script automates the installation of Kubernetes on Red Hat Enterprise Linux 9, leveraging the official Kubernetes documentation as a reference. It installs the following components:

    Container Runtime: Containerd v1.7.22
    Kubernetes Version: v1.31
    Runc Version: v1.1.15
    CNI Plugin: v1.5.1 (amd64)

Features:

    Disables swap and sets SELinux to permissive mode.
    Configures necessary firewall ports for Kubernetes.
    Installs required packages (socat, wget, tar).
    Downloads and installs containerd and its dependencies.
    Configures the containerd and kubelet cgroup drivers.
    Verifies checksums for downloaded binaries to ensure integrity.

# kubeadmconfig.yaml
This provides configurations for setting up a Kubernetes cluster using kubeadm.
Use this to create cluster after kubernetes is installed.
To use run sudo kubeadm init --config kubeadmconfig.yaml
