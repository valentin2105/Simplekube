# SimpleKube

A simple installation script for easily deploy a single node Kubernetes cluster. 
Simple as a shell script. It allow you to deploy easily k8s for test or dev purpuses.

### How-to use it ?

1- Tweak the script `install_k8s.sh`
 
 ```
k8Version="v1.5.2"
etcdVersion="v3.1.11"
dockerVersion="1.13.1"
hostIP="192.268.1.42"
 ```
2- Launch the script as root

`sudo ./install_k8s.sh`

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

