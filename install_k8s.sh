#! /bin/bash


## Set ip up :
k8Version="v1.7.3"
etcdVersion="v3.2.5"
dockerVersion="17.05.0-ce"
hostIP="10.244.0.104"

adminToken="maeshah8Xee9ema9xahwohlaek9evoep3edaihio9Theib3ohSh7phoh9zo5aiv3"
kubeletToken="ooshoovoh2quee0fe2OoshukaiNg9nooveiGaechiothiyequiel2uphie0uenai"

hostname=$(cat /etc/hostname)


###############################
## Let's go :
###############################

## Certs
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json


echo '{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}' > ca-csr.json


cfssl gencert -initca ca-csr.json | cfssljson -bare ca


cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "$hostIP",
    "$hostname",
    "10.32.0.1",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

## ETCD
sudo mkdir -p /etc/etcd/
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

wget https://github.com/coreos/etcd/releases/download/"$etcdVersion"/etcd-"$etcdVersion"-linux-amd64.tar.gz
tar -xvf etcd-"$etcdVersion"-linux-amd64.tar.gz
sudo mv etcd-"$etcdVersion"-linux-amd64/etcd* /usr/bin/

sudo mkdir -p /var/lib/etcd

cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name etcd0 \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --initial-advertise-peer-urls https://$hostIP:2380 \
  --listen-peer-urls https://$hostIP:2380 \
  --listen-client-urls https://$hostIP:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://$hostIP:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster etcd0=https://$hostIP:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv etcd.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

sleep 3
etcdctl --ca-file=/etc/etcd/ca.pem cluster-health


## K8 Master
sudo mkdir -p /var/lib/kubernetes
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/

wget https://storage.googleapis.com/kubernetes-release/release/"$k8Version"/bin/linux/amd64/kube-apiserver
wget https://storage.googleapis.com/kubernetes-release/release/"$k8Version"/bin/linux/amd64/kube-controller-manager
wget https://storage.googleapis.com/kubernetes-release/release/"$k8Version"/bin/linux/amd64/kube-scheduler
wget https://storage.googleapis.com/kubernetes-release/release/"$k8Version"/bin/linux/amd64/kubectl


chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/

cat > /var/lib/kubernetes/token.csv <<EOF
$adminToken,admin,admin
$kubeletToken,kubelet,kubelet
EOF

cat > /var/lib/kubernetes/authorization-policy.jsonl <<"EOF"
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "*", "readonly": true}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
EOF

cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \
  --advertise-address=$hostIP \
  --allow-privileged=true \
  --apiserver-count=1 \
  --authorization-mode=RBAC,ABAC \
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \
  --bind-address=0.0.0.0 \
  --enable-swagger-ui=true \
  --etcd-cafile=/var/lib/kubernetes/ca.pem \
  --insecure-bind-address=127.0.0.1 \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --etcd-servers=https://$hostIP:2379 \
  --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=10.32.0.0/16 \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --token-auth-file=/var/lib/kubernetes/token.csv \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv kube-apiserver.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver
sudo systemctl start kube-apiserver

cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \
  --allocate-node-cidrs=true \
  --cluster-cidr=10.200.0.0/16 \
  --cluster-name=kubernetes \
  --leader-elect=true \
  --master=http://127.0.0.1:8080 \
  --root-ca-file=/var/lib/kubernetes/ca.pem \
  --service-account-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv kube-controller-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kube-controller-manager
sudo systemctl start kube-controller-manager

cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler \
  --leader-elect=true \
  --master=http://127.0.0.1:8080 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv kube-scheduler.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler

sleep 3
kubectl get cs


## Worker
wget https://get.docker.com/builds/Linux/x86_64/docker-"$dockerVersion".tgz
tar -xvf docker-"$dockerVersion".tgz
sudo cp docker/docker* /usr/bin/

cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
ExecStart=/usr/bin/docker daemon \
  --iptables=false \
  --ip-masq=false \
  --host=unix:///var/run/docker.sock \
  --log-level=error \
  --storage-driver=overlay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
sudo docker version

sudo mkdir -p /opt/cni
wget https://storage.googleapis.com/kubernetes-release/network-plugins/cni-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz
sudo tar -xvf cni-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz -C /opt/cni


wget https://storage.googleapis.com/kubernetes-release/release/$k8Version/bin/linux/amd64/kubelet
wget https://storage.googleapis.com/kubernetes-release/release/$k8Version/bin/linux/amd64/kube-proxy

chmod +x  kube-proxy kubelet
sudo mv kube-proxy kubelet /usr/bin/
sudo mkdir -p /var/lib/kubelet/

cat > kubeconfig  <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://$hostIP:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: $kubeletToken
EOF

mv kubeconfig /var/lib/kubelet/

cat > kubelet.service  <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --cloud-provider= \
  --cluster-dns=10.32.0.10 \
  --cluster-domain=cluster.local \
  --container-runtime=docker \
  --docker=unix:///var/run/docker.sock \
  --network-plugin=kubenet \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --serialize-image-pulls=false \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --api-servers=https://$hostIP:6443 \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mv kubelet.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet

cat > kube-proxy.service  <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://$hostIP:6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mv kube-proxy.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy

sleep 3
echo "" 
kubectl get cs ; echo "" ;  kubectl get nodes
