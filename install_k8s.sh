#! /bin/bash
# -----------------------
# Set ip up :
# -----------------------
k8sVersion="v1.7.3"
etcdVersion="v3.2.5"
dockerVersion="17.05.0-ce"
cniVersion="v0.5.2"
calicoctlVersion="v1.3.0"
cfsslVersion="v1.2.0"
hostIP="internalIP"

adminToken="maeshah8Xee9ema9xahwohlaek9evoep3edaihio9Theib3ohSh7phoh9zo5aiv3"
kubeletToken="ooshoovoh2quee0fe2OoshukaiNg9nooveiGaechiothiyequiel2uphie0uenai"

hostname=$(cat /etc/hostname)

## Let's go :
# ----------------------
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
sudo cp ca.pem kubernetes-key.pem kubernetes.pem ca-key.pem /var/lib/kubernetes/

wget https://storage.googleapis.com/kubernetes-release/release/"$k8sVersion"/bin/linux/amd64/kube-apiserver
wget https://storage.googleapis.com/kubernetes-release/release/"$k8sVersion"/bin/linux/amd64/kube-controller-manager
wget https://storage.googleapis.com/kubernetes-release/release/"$k8sVersion"/bin/linux/amd64/kube-scheduler
wget https://storage.googleapis.com/kubernetes-release/release/"$k8sVersion"/bin/linux/amd64/kubectl


chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/

cat > token.csv <<EOF
$adminToken,admin,admin
$kubeletToken,kubelet,kubelet
EOF
sudo mv token.csv /var/lib/kubernetes

#cat > /var/lib/kubernetes/authorization-policy.jsonl <<"EOF"
#{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "*", "readonly": true}}
#{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*"}}
#{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*"}}
#{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*"}}
#{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
#EOF
  #--authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \

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
  --authorization-mode=RBAC \
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
  --cluster-name=kubernetes \
  --leader-elect=true \
  --master=http://127.0.0.1:8080 \
  --root-ca-file=/var/lib/kubernetes/ca.pem \
  --service-cluster-ip-range=10.32.0.0/16 \
  --pod-eviction-timeout 30s \
  --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \
  --service-cluster-ip-range=10.32.0.0/16 \
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
  --storage-driver=overlay2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
sleep 2
sudo docker version

sudo mkdir -p /etc/cni/net.d
wget https://github.com/containernetworking/cni/releases/download/"$cniVersion"/cni-amd64-"$cniVersion".tgz
sudo tar -xvf cni-amd64-"$cniVersion".tgs -C /etc/cni/net.d

cat >  10-calico.conf <<EOF
{
    "name": "calico-k8s-network",
    "type": "calico",
    "etcd_endpoints": "http://$hostIP:2379",
    "etcd_ca_cert_file": "/var/lib/kubernetes/ca.pem",
    "ipam": {
        "type": "calico-ipam",
        "assign_ipv4": "true",
        "assign_ipv6": "false"

    },
    "policy": {
        "type": "k8s"
    },
    "kubernetes": {
        "kubeconfig": "/var/lib/kubelet/kubeconfig"
    }
}

EOF

sudo mv 10-calico.conf /etc/cni/net.d/

cat > calico.service  <<EOF
[Unit]
Description=calico node
After=docker.service
Requires=docker.service

[Service]
User=root
PermissionsStartOnly=true
Environment=ETCD_ENDPOINTS=http://$hostIP:2379
Environment=ETCD_CA_CERT_FILE=/var/lib/kubernetes/ca.pem
ExecStart=/usr/bin/docker run --net=host --privileged --name=calico-node --rm -e CALICO_NETWORKING_BACKEND=bird  \
	-e CALICO_LIBNETWORK_ENABLED=true -e CALICO_LIBNETWORK_IFPREFIX=cali  \
	-e ETCD_AUTHORITY= -e ETCD_SCHEME= -e ETCD_CA_CERT_FILE=/etc/calico/certs/ca_cert.crt \
	-e IP=$hostIP \
        -e NO_DEFAULT_POOLS= -e CALICO_LIBNETWORK_ENABLED=true  \
	-e ETCD_ENDPOINTS=http://$hostIP:2379  \
	-v /var/lib/kubernetes/ca.pem:/etc/calico/certs/ca_cert.crt  \
	-e NODENAME=$hostname -e CALICO_NETWORKING_BACKEND=bird  \
	-v /var/run/calico:/var/run/calico -v /lib/modules:/lib/modules -v /var/log/calico:/var/log/calico  \
	-v /run/docker/plugins:/run/docker/plugins -v /var/run/docker.sock:/var/run/docker.sock  \
	calico/node:latest
ExecStop=/usr/bin/docker rm -f calico-node
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

EOF

sudo mv calico.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable calico
sudo systemctl start calico



wget https://github.com/projectcalico/calicoctl/releases/download/$calicoctlVersion/calicoctl
sudo mv calicoctl /usr/local/bin

wget https://storage.googleapis.com/kubernetes-release/release/$k8sVersion/bin/linux/amd64/kubelet
wget https://storage.googleapis.com/kubernetes-release/release/$k8sVersion/bin/linux/amd64/kube-proxy

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

sudo mv kubeconfig /var/lib/kubelet/

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
  --network-plugin=cni \
  --network-plugin-dir=/etc/cni/net.d \
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

sudo mv kubelet.service /etc/systemd/system/

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

sudo mv kube-proxy.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy

sleep 3
echo "" 
kubectl get cs ; echo "" ;  kubectl get nodes
