#!/bin/bash

set -euo pipefail

sudo apt-get update

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Add Kubernetes apt keyring, force overwrite without prompt
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /tmp/kubernetes-apt-keyring.gpg
sudo mv -f /tmp/kubernetes-apt-keyring.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Update apt package index
sudo apt-get update

# Install Kubernetes components without prompts
sudo apt-get install -y kubelet kubeadm kubectl

# Hold Kubernetes components to prevent unintended upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# Enable and start kubelet service
sudo systemctl enable kubelet && sudo systemctl start kubelet

# Install and enable containerd
sudo apt-get install -y containerd
sudo systemctl enable containerd && sudo systemctl start containerd

# Update permissions for containerd socket
sudo chmod 666 /run/containerd/containerd.sock

# Install CNI plugins for ARM architecture
sudo mkdir -p /opt/cni/bin
curl -L https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-arm64-v1.2.0.tgz | sudo tar -C /opt/cni/bin -xz

# Configure CNI network
sudo mkdir -p /etc/cni/net.d

# Create a bridge CNI configuration
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
            [{"subnet": "10.244.0.0/16"}]
        ],
        "routes": [
            {"dst": "0.0.0.0/0"}
        ]
    }
}
EOF

# Create a loopback CNI configuration
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

# Create kubelet configuration directory
sudo mkdir -p /etc/systemd/system/kubelet.service.d

# Add kubelet service configuration
sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf > /dev/null <<EOL
[Service]
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS --pod-manifest-path=/etc/kubernetes/manifests
EOL

# Create kubelet main configuration file
sudo mkdir -p /var/lib/kubelet
sudo tee /var/lib/kubelet/config.yaml > /dev/null <<EOL
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
staticPodPath: /etc/kubernetes/manifests
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
failSwapOn: false
cgroupDriver: systemd
EOL



# Create the manifests directory if it doesn't exist
sudo mkdir -p /etc/kubernetes/manifests/

# Create a simple Nginx Pod manifest
cat <<EOF | sudo tee /etc/kubernetes/manifests/static-web.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-web
  labels:
    role: myrole
spec:
  containers:
    - name: web
      image: nginx
      ports:
        - name: web
          containerPort: 80
          protocol: TCP
EOF

# Set permissions for the manifest
sudo chmod 644 /etc/kubernetes/manifests/static-web.yaml

# Reload systemd configuration and restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet