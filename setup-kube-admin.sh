#!/bin/bash

set -e
set -x

ARCH=$(uname -m | sed 's/aarch64/arm64/g')

KUBEADM_VERSION=${KUBEADM_VERSION:-1.33.0}
CRICTL_VERSION=${CRICTL_VERSION:-1.33.0}
RELEASE_VERSION=0.4.0 # TODO: Bump this to 0.18.0 (service links are missing)
CONTAINERD_VERSION=1.6.4
RUNC_VERSION=1.3.0
CNI_PLUGINS=1.7.1

pushd /usr/bin/
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | tar -C /usr/bin/ -xz
curl -L --remote-name-all https://dl.k8s.io/v${KUBEADM_VERSION}/bin/linux/${ARCH}/kubeadm
curl -L --remote-name-all https://dl.k8s.io/v${KUBEADM_VERSION}/bin/linux/${ARCH}/kubelet
curl -L --remote-name-all https://dl.k8s.io/v${KUBEADM_VERSION}/bin/linux/${ARCH}/kubectl

chmod +x kubeadm
chmod +x kubelet
chmod +x kubectl
popd

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | tee /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Setup containerd
mkdir -p /opt/cni/bin
curl -sSL https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz | tar -C /opt/ -xz
curl -SL -o runc "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}"
curl -sSL https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS}/cni-plugins-linux-${ARCH}-v${CNI_PLUGINS}.tgz | tar -C /opt/cni/bin/ -xz
install -m 755 runc /opt/bin/runc
curl -sSL "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" | sed "s?ExecStart=/usr/local/bin/containerd?ExecStart=/opt/bin/containerd?" | tee /etc/systemd/system/containerd.service

cp -R /opt/bin/ctr /usr/bin/ctr
mkdir -p /opt/kubeadm/scripts

bash /opt/kubeadm/scripts/kube-images-load.sh ${KUBEADM_VERSION}

mkdir -p /etc/modules-load.d/
mkdir -p /etc/sysctl.d/

echo "overlay" >> /etc/modules-load.d/k8s.conf
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.d/k8s.conf
echo net.bridge.bridge-nf-call-ip6tables=1 >> /etc/sysctl.d/k8s.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.d/k8s.conf