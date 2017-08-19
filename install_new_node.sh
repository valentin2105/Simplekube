#! /bin/bash
# -----------------------
# Set ip up :
# -----------------------
nodeIP="__PUBLIC_OR_PRIVATE_IPV4__"
setupFirewall="True"
CAcountry="$CAcountry"

nodeHostname=$(ssh root@$nodeIP 'hostname')

if [ ! -f ca.pem ]; then
        echo "ca.pem don't exist, lauch ./install_k8s --master before !"
	exit 1
fi

if [ ! -f ca-key.pem ]; then
        echo "ca-key.pem don't exist, lauch ./install_k8s --master before !"
	exit 1
fi

if [ ! -f ca-config.json ]; then
        echo "ca-config.json don't exist, lauch ./install_k8s --master before !"
	exit 1
fi

if [[ "$setupFirewall" == "True" ]]; then
       # apt-get update && apt-get -y install ufw
	ufw allow from $nodeIP
fi


cat > $nodeHostname-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "$nodeIP",
    "$nodeHostname",
    "10.32.0.1",
    "$clusterDomain",
    "127.0.0.1"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "$CAcountry",
      "L": "Cloud",
      "O": "Kubernetes",
      "OU": "Cluster"
    }
  ]
}
EOF


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  $nodeHostname-csr.json | cfssljson -bare $nodeHostname

ssh root@$nodeIP 'mkdir /var/lib/kubernetes && mkdir /var/lib/kubelet && mkdir /opt/Simplekube'

scp $nodeHostname.pem root@$nodeIP:/var/lib/kubernetes/
scp $nodeHostname-key.pem root@$nodeIP:/var/lib/kubernetes/
scp ca.pem root@$nodeIP:/var/lib/kubernetes/
scp install_k8s.sh root@$nodeIP:/opt/Simplekube/
scp /var/lib/kubelet/kubeconfig root@$nodeIP:/var/lib/kubelet/
ssh root@$nodeIP 'echo $nodeIP > /tmp/IP'

ssh root@$nodeIP  '/opt/Simplekube/install_k8s.sh --worker'
