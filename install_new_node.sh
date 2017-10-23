#! /bin/bash
# -----------------------
# Set ip up :
# -----------------------
nodeIP="__PUBLIC_OR_PRIVATE_IPV4__"
sshUser="root"
setupFirewall="False"
CAcountry="US"

nodeHostname=$(ssh $sshUser@$nodeIP 'hostname')

echo "$nodeIP	$nodeHostname" >> /etc/hosts

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

ssh $sshUser@$nodeIP 'mkdir /var/lib/kubernetes && mkdir /var/lib/kubelet && mkdir /opt/Simplekube'

scp $nodeHostname.pem $sshUser@$nodeIP:/var/lib/kubernetes/
scp $nodeHostname-key.pem $sshUser@$nodeIP:/var/lib/kubernetes/
scp ca.pem $sshUser@$nodeIP:/var/lib/kubernetes/
scp install_k8s.sh $sshUser@$nodeIP:/opt/Simplekube/
scp /var/lib/kubelet/kubeconfig $sshUser@$nodeIP:/var/lib/kubelet/
ssh $sshUser@$nodeIP 'echo $nodeIP > /tmp/IP'
ssh $sshUser@$nodeIP 'echo "$nodeIP	$nodeHostname" >> /etc/hosts'

ssh $sshUser@$nodeIP  '/opt/Simplekube/install_k8s.sh --worker'
