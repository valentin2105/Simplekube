<img src="https://i.imgur.com/gMGVimd.png" width="500">

A simple installation script for easily deploy a single node Kubernetes cluster. (tested on Ubuntu / Debian)

> Simple as a shell script. It allow you to deploy easily k8s for test or dev purposes.

The idea behind Simplekube is to give a way to install Kubernetes on single Linux VM without have to plug with any cloud provider or Hypervisor. Just take a Linux VM, clone the git repo, launch the script and have fun with k8s !

### How-to use it ?

1- Tweak the script `install_k8s.sh`
 
 ```
k8sVersion="v1.7.3"
etcdVersion="v3.2.5"
dockerVersion="17.05.0-ce"
cniVersion="v0.5.2"
calicoCniVersion="v1.10.0"
calicoctlVersion="v1.3.0"
cfsslVersion="v1.2.0"
helmVersion="v2.6.0"
hostIP="__PUBLIC_OR_PRIVATE_IPV4"
clusterDomain="cluster.local"
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

kubectl get pod --all-namespaces

```
4- Cluster's integrated components :

  - KubeDNS
  - HELM ready
  - KubeDashboard
  - RBAC enabled by default
  - Calico CNI plugin
  - Calico Policy controller 
  - Calicoctl

### Requirements

This script download each k8s components with `wget` and launch them with `systemd units`. 
You will need `socat` installed and `git` to fetch the Git repo !

Feel free to open an Issue if you need assistance !

