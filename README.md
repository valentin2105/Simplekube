<img src="https://i.imgur.com/gMGVimd.png" width="500">

> Simple as a shell script. It allow you to deploy easily k8s for tests or learn purposes.

With Simplekube, you can install Kubernetes on Linux servers without have to plug with any cloud provider.

Just take a Linux empty box, clone the git repo, launch the script and have fun with k8s ! 
It come with few things like Kube-DNS, Calico, Helm, Firewall and IPv6 !

If you need, you can easily add new workers (from multi-clouds) !

## How-to use it ?

#### 1- Tweak the head of `install_k8s.sh`
 
```
# please change this value :
hostIP="__PUBLIC_OR_PRIVATE_IPV4__"
# -----------------------
k8sVersion="v1.8.1"
etcdVersion="v3.2.9"
dockerVersion="17.05.0-ce"
cniVersion="v0.6.0"
calicoCNIVersion="v1.11.0"
calicoctlVersion="v1.6.1"
cfsslVersion="v1.2.0"
helmVersion="v2.6.2"
```
#### 2- Launch the script as user (with sudo power)

`./install_k8s.sh --master`

#### 3- You can now play with k8s (...)
```
$- kubectl get cs 
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health": "true"}

$- kubectl get pod --all-namespaces
NAMESPACE     NAME                                        READY     STATUS    RESTARTS   AGE
kube-system   calico-policy-controller-4180354049-63p5v   1/1       Running   0          4m
kube-system   kube-dns-1822236363-zzkdq                   4/4       Running   0          4m
kube-system   kubernetes-dashboard-3313488171-lff6h       1/1       Running   0          4m
kube-system   tiller-deploy-1884622320-0glqq              1/1       Running   0          4m

$- calicoctl get ippool
CIDR
192.168.0.0/16
fd80:24e2:f998:72d6::/64

$- kubectl run -i -t alpine --image=alpine --restart=Never
/ # ping6 google.com
PING google.com (2404:6800:4003:80d::200e): 56 data bytes
64 bytes from 2404:6800:4003:80d::200e: seq=0 ttl=57 time=2.129 ms
```
#### 4- Cluster's integrated components :

  - KubeDNS
  - HELM ready
  - KubeDashboard
  - RBAC only by default
  - Calico CNI plugin
  - Calico Policy controller 
  - Calicoctl tool
  - UFW to secure access (can be disabled)
  - ECDSA cluster certs w/ CFSSL
  - IPv4/IPv6

#### 5- Expose services :

You can expose easily your services with :

  - Only reachable on the machine : `ClusterIP`
  - Expose on high TCP ports : `NodePort`
  - Expose publicly : Service's `ExternalIPs`


#### 6- Add new nodes :

You can easily add new nodes to your cluster by launching `./install_new_worker.sh`

Before launch the script, be sure to tweak the head of the script :
```
nodeIP="__PUBLIC_OR_PRIVATE_IPV4__"
sshUser="root"
setupFirewall="True"
CAcountry="US"
```

## Requirements

This script download each k8s components with `wget` and launch k8s with `systemd units`. 

You will need `socat`, `conntrack`, `sudo` and `git` on your servers. 

To add a node, you will need to setup `key-based` SSH authentification between master & workers.

If you want IPv6 on pods side, you need working IPv6 on hosts.

Simplekube is tested on `Debian 8/9` and `Ubuntu 16.x/17.x`.

Feel free to open an Issue if you need assistance !
