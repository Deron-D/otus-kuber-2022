# **Лекция №24: Подходы к развертыванию и обновлению production-grade кластера // ДЗ**
> _Подходы к развертыванию_
<details>
  <summary>kubernetes-production</summary>

## **Задание:**
Создание и обновление кластера при помощи kubeadm

Цель:
Научимся пользоваться kubeadm для создания и обновления кластеров

Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.

Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

### Подготовка

В этом ДЗ через kubeadm мы поднимем кластер версии 1.17 и обновим его

### Выполнено:

### 1. Создание кластера версии 1.17 и обновление его с помощью Kubeadm

В YandexCloud создадим 4 ноды с образом Ubuntu 18.04 LTS:
- master - 1 экземпляр (standard-v2)
- worker - 3 экземпляра (standard-v1)

- Создаем `master-node`
~~~bash
yc compute instance create \
  --name master-node \
  --platform=standard-v2 \
  --cores=4 \
  --memory=4 \
  --zone ru-central1-c \
  --network-interface subnet-name=default-ru-central1-c,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=30,type=network-ssd \
  --ssh-key ~/.ssh/id_rsa.pub
~~~

- Создаем `worker-nodes`
~~~bash
yc compute instance create \
  --name worker-node-01 \
  --platform=standard-v1 \
  --cores=4 \
  --memory=4 \
  --zone ru-central1-c \
  --network-interface subnet-name=default-ru-central1-c,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=30,type=network-ssd \
  --ssh-key ~/.ssh/id_rsa.pub
yc compute instance create \
  --name worker-node-02 \
  --platform=standard-v1 \
  --cores=4 \
  --memory=4 \
  --zone ru-central1-c \
  --network-interface subnet-name=default-ru-central1-c,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=30,type=network-ssd \
  --ssh-key ~/.ssh/id_rsa.pub
yc compute instance create \
  --name worker-node-03 \
  --platform=standard-v1 \
  --cores=4 \
  --memory=4 \
  --zone ru-central1-c \
  --network-interface subnet-name=default-ru-central1-c,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=30,type=network-ssd \
  --ssh-key ~/.ssh/id_rsa.pub
~~~

~~~bash
yc compute instance list
~~~

~~~console
+----------------------+-----------------+---------------+---------+----------------+-------------+
|          ID          |      NAME       |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+-----------------+---------------+---------+----------------+-------------+
| ef361eajucamkc51bfl2 | worker-node-02  | ru-central1-c | RUNNING | 84.201.149.9   | 10.130.0.12 |
| ef3di3tm580d0q8usv73 | worker-node-03  | ru-central1-c | RUNNING | 84.201.147.121 | 10.130.0.34 |
| ef3em44tpsbqb6ms324m | worker-node-01  | ru-central1-c | RUNNING | 84.201.145.140 | 10.130.0.8  |
| ef3l9p9usmvb78aih3i1 | master-node     | ru-central1-c | RUNNING | 51.250.32.15   | 10.130.0.21 |
+----------------------+-----------------+---------------+---------+----------------+-------------+
~~~


- Подготовка машин
Отключим на машинах swap

~~~bash
ssh  yc-user@84.201.149.9 sudo swapoff -a
~~~
~~~bash
ssh  yc-user@84.201.147.121 sudo swapoff -a
~~~
~~~bash
ssh  yc-user@84.201.145.140  sudo swapoff -a
~~~
~~~bash
ssh  yc-user@51.250.32.15 sudo swapoff -a
~~~

- Включаем маршрутизацию пакетов на всех нодах и применяем её.
~~~bash
ssh yc-user@84.201.149.9
sudo -s
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
~~~
~~~bash
ssh yc-user@84.201.147.121
sudo -s
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
~~~
~~~bash
ssh yc-user@84.201.145.140
sudo -s
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
~~~
~~~bash
ssh yc-user@51.250.32.15
sudo -s
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
~~~

- Установим Docker
  - 84.201.149.9
~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
apt update && apt-get install -y \
    apt-transport-https ca-certificates curl software-properties-common gnupg2
~~~
~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt-get install -y \
          containerd.io=1.2.13-1 \
          docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
          docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)
~~~
~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
     },
    "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d && systemctl daemon-reload && systemctl restart docker
~~~

- 84.201.147.121
~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
apt update && apt-get install -y \
    apt-transport-https ca-certificates curl software-properties-common gnupg2
~~~
~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt-get install -y \
          containerd.io=1.2.13-1 \
          docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
          docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)
~~~
~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
     },
    "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d && systemctl daemon-reload && systemctl restart docker
~~~

- 84.201.145.140
~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
apt update && apt-get install -y \
    apt-transport-https ca-certificates curl software-properties-common gnupg2
~~~
~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt-get install -y \
          containerd.io=1.2.13-1 \
          docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
          docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)
~~~
~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
     },
    "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d && systemctl daemon-reload && systemctl restart docker
~~~

- 51.250.32.15
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
apt update && apt-get install -y \
    apt-transport-https ca-certificates curl software-properties-common gnupg2
~~~
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update && apt-get install -y \
          containerd.io=1.2.13-1 \
          docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
          docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)
~~~
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
     },
    "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d && systemctl daemon-reload && systemctl restart docker
~~~


- Установим kubeadm, kubectl, kubelet на всех нодах

  - 84.201.149.9
  - 84.201.147.121
  - 84.201.145.140
  - 51.250.32.15
~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
apt update && apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00
exit
~~~

~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
apt update && apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00
exit
~~~

~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
apt update && apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00
exit
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
apt update && apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update && apt install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00
exit
~~~

- Создание кластера
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubeadm init --pod-network-cidr=192.168.0.0/24
~~~ 

~~~console
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.130.0.21:6443 --token rdm3cx.snehsevni71vjel8 \
    --discovery-token-ca-cert-hash sha256:1301077b456a8902848b4498ba7cdcaa7437f34a3db2ed59e9d2aa268619facc 
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl get nodes
~~~
~~~console
NAME                   STATUS     ROLES    AGE    VERSION
ef3l9p9usmvb78aih3i1   NotReady   master   100s   v1.17.4
~~~

- Устанавливаем сетевой плагин `Calico`
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl apply -f https://docs.projectcalico.org/archive/v3.12/manifests/calico.yaml
~~~


- Подключаем worker-ноды
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubeadm token list
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'
~~~ 
~~~console
root@ef3l9p9usmvb78aih3i1:~# kubeadm token list
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION                                                EXTRA GROUPS
rdm3cx.snehsevni71vjel8   23h         2023-05-16T20:36:33Z   authentication,signing   The default bootstrap token generated by 'kubeadm init'.   system:bootstrappers:kubeadm:default-node-token
root@ef3l9p9usmvb78aih3i1:~# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
>   openssl dgst -sha256 -hex | sed 's/^.* //'
1301077b456a8902848b4498ba7cdcaa7437f34a3db2ed59e9d2aa268619facc
~~~

  - 84.201.149.9
  - 84.201.147.121
  - 84.201.145.140
  - 51.250.32.15

~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
kubeadm join 10.130.0.21:6443 --token rdm3cx.snehsevni71vjel8 \
    --discovery-token-ca-cert-hash sha256:1301077b456a8902848b4498ba7cdcaa7437f34a3db2ed59e9d2aa268619facc
~~~
~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
kubeadm join 10.130.0.21:6443 --token rdm3cx.snehsevni71vjel8 \
    --discovery-token-ca-cert-hash sha256:1301077b456a8902848b4498ba7cdcaa7437f34a3db2ed59e9d2aa268619facc
~~~
~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
kubeadm join 10.130.0.21:6443 --token rdm3cx.snehsevni71vjel8 \
    --discovery-token-ca-cert-hash sha256:1301077b456a8902848b4498ba7cdcaa7437f34a3db2ed59e9d2aa268619facc
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl get nodes
~~~
~~~console
NAME                   STATUS   ROLES    AGE   VERSION
ef361eajucamkc51bfl2   Ready    <none>   95s   v1.17.4
ef3di3tm580d0q8usv73   Ready    <none>   88s   v1.17.4
ef3em44tpsbqb6ms324m   Ready    <none>   82s   v1.17.4
ef3l9p9usmvb78aih3i1   Ready    master   38m   v1.17.4
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 4
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.17.2
        ports:
        - containerPort: 80
EOF
kubectl apply -f deployment.yaml
watch kubectl get pod -o wide    
~~~

~~~console
NAME                               READY   STATUS    RESTARTS   AGE   IP                NODE                   NOMINATED NODE   READINESS GATES
nginx-deployment-c8fd555cc-h65r2   1/1     Running   0          95s   192.168.249.194   ef3em44tpsbqb6ms324m   <none>           <none>
nginx-deployment-c8fd555cc-tl5pc   1/1     Running   0          95s   192.168.36.65     ef3di3tm580d0q8usv73   <none>           <none>
nginx-deployment-c8fd555cc-xqfl7   1/1     Running   0          95s   192.168.137.65    ef361eajucamkc51bfl2   <none>           <none>
nginx-deployment-c8fd555cc-zlctf   1/1     Running   0          95s   192.168.249.193   ef3em44tpsbqb6ms324m   <none>           <none>
~~~

- Обновление кластера

Так как кластер мы разворачивали с помощью kubeadm, то и производить обновление будем с помощью него.
Обновлять ноды будем по очереди.
Допускается, отставание версий worker-нод от master, но не наоборот.
Поэтому обновление будем начинать с нее master-нода у нас версии 1.16.8
Обновление пакетов
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
apt-get update && apt-get install -y kubeadm=1.18.0-00 \
kubelet=1.18.0-00 kubectl=1.18.0-00
~~~
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubeadm version
~~~
~~~console
kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:56:30Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl version
~~~
~~~console
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:58:59Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.17", GitCommit:"f3abc15296f3a3f54e4ee42e830c61047b13895f", GitTreeState:"clean", BuildDate:"2021-01-13T13:13:00Z", GoVersion:"go1.13.15", Compiler:"gc", Platform:"linux/amd64"}
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl describe pod -l component=kube-apiserver -n kube-system
~~~
~~~console
Name:                 kube-apiserver-ef3l9p9usmvb78aih3i1
Namespace:            kube-system
Priority:             2000000000
Priority Class Name:  system-cluster-critical
Node:                 ef3l9p9usmvb78aih3i1/10.130.0.21
Start Time:           Mon, 15 May 2023 20:36:34 +0000
Labels:               component=kube-apiserver
                      tier=control-plane
Annotations:          kubernetes.io/config.hash: 4a1c9938c9a47cd46cd9b000eebb6259
                      kubernetes.io/config.mirror: 4a1c9938c9a47cd46cd9b000eebb6259
                      kubernetes.io/config.seen: 2023-05-15T21:27:08.098301576Z
                      kubernetes.io/config.source: file
Status:               Running
IP:                   10.130.0.21
IPs:
  IP:           10.130.0.21
Controlled By:  Node/ef3l9p9usmvb78aih3i1
Containers:
  kube-apiserver:
    Container ID:  docker://a2709261af6da9aef10e0b4c04b13280479a62d63edd47d63ec159a5f4df95b3
    Image:         k8s.gcr.io/kube-apiserver:v1.17.17
    Image ID:      docker-pullable://k8s.gcr.io/kube-apiserver@sha256:71344dfb6a804ff6b2c8bf5f72b1f7941ddee1fbff7369836339a79387aa071a
    Port:          <none>
    Host Port:     <none>
    Command:
      kube-apiserver
      --advertise-address=10.130.0.21
      --allow-privileged=true
      --authorization-mode=Node,RBAC
      --client-ca-file=/etc/kubernetes/pki/ca.crt
      --enable-admission-plugins=NodeRestriction
      --enable-bootstrap-token-auth=true
      --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
      --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
      --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
      --etcd-servers=https://127.0.0.1:2379
      --insecure-port=0
      --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
      --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
      --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
      --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
      --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
      --requestheader-allowed-names=front-proxy-client
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
      --requestheader-extra-headers-prefix=X-Remote-Extra-
      --requestheader-group-headers=X-Remote-Group
      --requestheader-username-headers=X-Remote-User
      --secure-port=6443
      --service-account-key-file=/etc/kubernetes/pki/sa.pub
      --service-cluster-ip-range=10.96.0.0/12
      --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
      --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    State:          Running
      Started:      Mon, 15 May 2023 21:27:21 +0000
    Ready:          True
    Restart Count:  0
    Requests:
      cpu:        250m
    Liveness:     http-get https://10.130.0.21:6443/healthz delay=15s timeout=15s period=10s #success=1 #failure=8
    Environment:  <none>
    Mounts:
      /etc/ca-certificates from etc-ca-certificates (ro)
      /etc/kubernetes/pki from k8s-certs (ro)
      /etc/ssl/certs from ca-certs (ro)
      /usr/local/share/ca-certificates from usr-local-share-ca-certificates (ro)
      /usr/share/ca-certificates from usr-share-ca-certificates (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  ca-certs:
    Type:          HostPath (bare host directory volume)
    Path:          /etc/ssl/certs
    HostPathType:  DirectoryOrCreate
  etc-ca-certificates:
    Type:          HostPath (bare host directory volume)
    Path:          /etc/ca-certificates
    HostPathType:  DirectoryOrCreate
  k8s-certs:
    Type:          HostPath (bare host directory volume)
    Path:          /etc/kubernetes/pki
    HostPathType:  DirectoryOrCreate
  usr-local-share-ca-certificates:
    Type:          HostPath (bare host directory volume)
    Path:          /usr/local/share/ca-certificates
    HostPathType:  DirectoryOrCreate
  usr-share-ca-certificates:
    Type:          HostPath (bare host directory volume)
    Path:          /usr/share/ca-certificates
    HostPathType:  DirectoryOrCreate
QoS Class:         Burstable
Node-Selectors:    <none>
Tolerations:       :NoExecute
Events:
  Type    Reason   Age    From                           Message
  ----    ------   ----   ----                           -------
  Normal  Pulled   5m18s  kubelet, ef3l9p9usmvb78aih3i1  Container image "k8s.gcr.io/kube-apiserver:v1.17.17" already present on machine
  Normal  Created  5m18s  kubelet, ef3l9p9usmvb78aih3i1  Created container kube-apiserver
  Normal  Started  5m18s  kubelet, ef3l9p9usmvb78aih3i1  Started container kube-apiserver
~~~

- Итого
  - kubeadm: v1.18.0
  - kubelet: v1.18.0
  - kubectl client v1.18.0
  - kubectl server v1.17.17
  - api-server: v1.17.17

- Обновим остальные компоненты кластера
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
# просмотр изменений, которые собирает сделать kubeadm
kubeadm upgrade plan
# применение изменений
kubeadm upgrade apply v1.18.0 -f
# проверка
kubeadm version
kubelet --version
kubectl version
kubectl describe pod -l component=kube-apiserver -n kube-system | grep kube-apiserver
~~~

~~~console
Kubernetes v1.18.0
root@ef3l9p9usmvb78aih3i1:~# kubectl version
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:58:59Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:50:46Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
root@ef3l9p9usmvb78aih3i1:~# kubectl describe pod -l component=kube-apiserver -n kube-system | grep kube-apiserver
Name:                 kube-apiserver-ef3l9p9usmvb78aih3i1
Labels:               component=kube-apiserver
Annotations:          kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.130.0.21:6443
  kube-apiserver:
    Image:         k8s.gcr.io/kube-apiserver:v1.18.0
    Image ID:      docker-pullable://k8s.gcr.io/kube-apiserver@sha256:fc4efb55c2a7d4e7b9a858c67e24f00e739df4ef5082500c2b60ea0903f18248
      kube-apiserver
  Normal  Pulled   18s   kubelet, ef3l9p9usmvb78aih3i1  Container image "k8s.gcr.io/kube-apiserver:v1.18.0" already present on machine
  Normal  Created  18s   kubelet, ef3l9p9usmvb78aih3i1  Created container kube-apiserver
  Normal  Started  18s   kubelet, ef3l9p9usmvb78aih3i1  Started container kube-apiserver
~~~


~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl get nodes -o wide
~~~
~~~console
NAME                   STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
ef361eajucamkc51bfl2   Ready    <none>   28m   v1.17.4   10.130.0.12   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3di3tm580d0q8usv73   Ready    <none>   28m   v1.17.4   10.130.0.34   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3em44tpsbqb6ms324m   Ready    <none>   28m   v1.17.4   10.130.0.8    <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3l9p9usmvb78aih3i1   Ready    master   65m   v1.18.0   10.130.0.21   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
~~~

~~~console
root@ef3l9p9usmvb78aih3i1:~# kubectl drain ef361eajucamkc51bfl2
node/ef361eajucamkc51bfl2 cordoned
error: unable to drain node "ef361eajucamkc51bfl2", aborting command...

There are pending nodes to be drained:
 ef361eajucamkc51bfl2
error: cannot delete DaemonSet-managed Pods (use --ignore-daemonsets to ignore): kube-system/calico-node-v8sq9, kube-system/kube-proxy-b6kmx

root@ef3l9p9usmvb78aih3i1:~# kubectl drain ef361eajucamkc51bfl2  --ignore-daemonsets
node/ef361eajucamkc51bfl2 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-v8sq9, kube-system/kube-proxy-b6kmx
evicting pod default/nginx-deployment-c8fd555cc-xqfl7
evicting pod kube-system/coredns-66bff467f8-dx8jv
pod/nginx-deployment-c8fd555cc-xqfl7 evicted
pod/coredns-66bff467f8-dx8jv evicted
node/ef361eajucamkc51bfl2 evicted
~~~

~~~console
# kubectl get nodes -o wide
NAME                   STATUS                     ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
ef361eajucamkc51bfl2   Ready,SchedulingDisabled   <none>   30m   v1.17.4   10.130.0.12   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3di3tm580d0q8usv73   Ready                      <none>   30m   v1.17.4   10.130.0.34   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3em44tpsbqb6ms324m   Ready                      <none>   30m   v1.17.4   10.130.0.8    <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3l9p9usmvb78aih3i1   Ready                      master   67m   v1.18.0   10.130.0.21   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
~~~

- Обновление worker-нод
~~~bash
export HOST=84.201.149.9
ssh yc-user@$HOST
sudo -s
apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
systemctl restart kubelet
~~~
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl get nodes -o wide
~~~
~~~console
NAME                   STATUS                     ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
ef361eajucamkc51bfl2   Ready,SchedulingDisabled   <none>   32m   v1.18.0   10.130.0.12   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3di3tm580d0q8usv73   Ready                      <none>   32m   v1.17.4   10.130.0.34   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3em44tpsbqb6ms324m   Ready                      <none>   32m   v1.17.4   10.130.0.8    <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3l9p9usmvb78aih3i1   Ready                      master   69m   v1.18.0   10.130.0.21   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
~~~
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl uncordon ef361eajucamkc51bfl2
~~~
~~~console
node/ef361eajucamkc51bfl2 uncordoned
~~~

- Задание:
обновим оставшиеся ноды при помощи kubeadm
~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl drain ef3di3tm580d0q8usv73 --ignore-daemonsets
~~~

~~~bash
export HOST=84.201.147.121
ssh yc-user@$HOST
sudo -s
apt install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
systemctl restart kubelet
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl uncordon ef3di3tm580d0q8usv73
kubectl drain ef3em44tpsbqb6ms324m --ignore-daemonsets
~~~

~~~bash
export HOST=84.201.145.140
ssh yc-user@$HOST
sudo -s
apt install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
systemctl restart kubelet
~~~

~~~bash
export HOST=51.250.32.15
ssh yc-user@$HOST
sudo -s
kubectl uncordon ef3em44tpsbqb6ms324m
kubectl get nodes -o wide
~~~

~~~
NAME                   STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
ef361eajucamkc51bfl2   Ready    <none>   53m   v1.18.0   10.130.0.12   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3di3tm580d0q8usv73   Ready    <none>   53m   v1.18.0   10.130.0.34   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3em44tpsbqb6ms324m   Ready    <none>   53m   v1.18.0   10.130.0.8    <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
ef3l9p9usmvb78aih3i1   Ready    master   90m   v1.18.0   10.130.0.21   <none>        Ubuntu 18.04.6 LTS   4.15.0-112-generic   docker://19.3.8
~~~

- Чистим ресурсы
~~~bash
yc compute instance delete  master-node  worker-node-01 worker-node-02 worker-node-03
~~~

## **Полезное:**

- Start
~~~bash
yc compute instance start master-node  
yc compute instance start worker-node-01
yc compute instance start worker-node-02
yc compute instance start worker-node-03
~~~

- Stop
~~~bash
yc compute instance stop master-node  
yc compute instance stop worker-node-01
yc compute instance stop worker-node-02
yc compute instance stop worker-node-03
~~~

