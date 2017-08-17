<img src="https://i.imgur.com/gMGVimd.png" width="500">

A simple installation script for easily deploy a single node Kubernetes cluster. (tested on Ubuntu / Debian)

> Simple as a shell script. It allow you to deploy easily k8s for test or dev purposes.

The idea between Simplekube is to give a way to install Kubernetes on simple Linux VM without have to plug with any cloud provider or Hypervisor. Just take a Linux VM, clone the git repo, launch the script and play with k8s !

### How-to use it ?

1- Tweak the script `install_k8s.sh`
 
 ```
k8sVersion="v1.7.3"
etcdVersion="v3.2.5"
dockerVersion="17.05.0-ce"
cniVersion="v0.5.2"
calicoctlVersion="v1.3.0"
cfsslVersion="v1.2.0"
hostIP="10.220.1.100"
 ```
2- Launch the script as user (with sudo right)

`./install_k8s.sh`

3- You can play now with k8s 

```
kubectl get cs 

NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health": "true"}

kubectl get node

NAME                  STATUS    AGE
local.machine.com     Ready     1d
```

### Tweak you cluster :

- KubeDNS
- Heapster (InfluxDB/Grafana)
- EFK (Elasticsearch/FluentD/Kibana)
- NginxIngress Controller
- Kube-lego for Let's Encrypt certs
- Kubernetes Dashboard
- Wordpress template
