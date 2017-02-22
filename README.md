# Kubernetes_Deployment

## K8-SingleNode : 
A simple Kubernetes installation script  from scratch.

### Install Steps :

1- Configure the script `install-kubernetes.sh`
 
 ```
k8Version="v1.5.2"
etcdVersion="v3.1.11"
dockerVersion="1.13.1"
hostIP="IPAddr"
adminToken="aeTeiGheiboth4iecieshooriiReiwah"
kubeletToken="eeso6iel6iR6oorie5vuv7quahseitha"
 ```
2- Launch  the script

`./install-kubernetes.sh`

3- Play with Kubernetes in a single-node cluster

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

### Some Kubernetes ressource & example in this repo :

- KubeDNS
- Heapster (InfluxDB/Grafana)
- EFK (Elasticsearch/FluentD/Kibana)
- Traefik as a Ingress TLS reverse-proxy
- The Kubernetes dashboard
- BusyBox for check the DNS
- MariaDB Percona cluster
- GlusterFS for use as a DataStore


