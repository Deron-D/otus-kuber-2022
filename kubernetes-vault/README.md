# **Лекция №18: Хранилище секретов для приложений. Vault // ДЗ**
> _Hashicorp Vault + K8sHashicorp Vault + K_
<details>
  <summary>kubernetes-vault</summary>

## **Задание:**
Устанавливаем и настраиваем Vault для нужд платформенной команды и команд разработки

Цель:
В данном домашнем задании студенты установят Hashicrop Vault в кластер kubernetes. Научатся управлять секретами и использовать их в кластере.


Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.


Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### План работ
В ходе работы мы: 
- установим кластер vault в kubernetes
- научимся создавать секреты и политики
- настроим авторизацию в vault через kubernetes sa
- сделаем под с контейнером nginx, в который прокинем
- секреты из vault через consul-template

### 1. Подготовка

~~~bash
cd ./terraform-k8s
terraform init
terraform apply --auto-approve
~~~
~~~bash
kubectl get nodes
~~~
~~~
NAME              STATUS   ROLES    AGE    VERSION
k8s-4otus-node1   Ready    <none>   105s   v1.24.6
k8s-4otus-node2   Ready    <none>   108s   v1.24.6
k8s-4otus-node3   Ready    <none>   98s    v1.24.6
~~~

### 2. Инсталляция hashicorp vault HA в k8s
 
- склонируем репозиторий `consul` (необходимо минимум 3 ноды)
~~~bash
git clone https://github.com/hashicorp/consul-helm.git
helm install consul consul-helm
~~~
~~~bash
kubectl get pods
~~~
~~~
NAME                     READY   STATUS    RESTARTS   AGE
consul-consul-d2hcw      1/1     Running   0          3m22s
consul-consul-g6fdr      1/1     Running   0          3m22s
consul-consul-mmqs2      1/1     Running   0          3m22s
consul-consul-server-0   1/1     Running   0          3m22s
consul-consul-server-1   1/1     Running   0          3m21s
consul-consul-server-2   1/1     Running   0          3m21s
~~~
~~~bash
kubectl get pvc
~~~
~~~
NAME                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
data-default-consul-consul-server-0   Bound    pvc-3c130f13-e89c-4df6-9850-9f2a01d25415   10Gi       RWO            yc-network-hdd   27s
data-default-consul-consul-server-1   Bound    pvc-87edc4b9-0711-4a11-a3b4-d1861a5a52f7   10Gi       RWO            yc-network-hdd   27s
data-default-consul-consul-server-2   Bound    pvc-7c3392f9-8867-4fae-a8b9-c175b111b918   10Gi       RWO            yc-network-hdd   27s
~~~

- склонируем репозиторий `vault`
~~~bash
git clone https://github.com/hashicorp/vault-helm.git
~~~
- Отредактируем параметры установки в `values.yaml`
~~~yaml
standalone:
  enabled: false
....
ha:
  enabled: true
...
ui:
  enabled: true
  serviceType: "ClusterIP"
~~~

- Установим `vault`
~~~bash
helm install vault vault-helm -f ../vault.values.yaml
helm status vault
~~~
~~~
NAME: vault
LAST DEPLOYED: Sat Mar 25 19:38:46 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
~~~
~~~bash
kubectl logs vault-0
~~~
~~~
==> Vault server configuration:

             Api Address: http://10.112.130.8:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
              Go Version: go1.19.2
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: info
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.12.1, built 2022-10-27T12:32:05Z
             Version Sha: e34f8a14fb7a88af4640b09f3ddbb5646b946d9c

2023-03-25T16:39:03.722Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2023-03-25T16:39:03.722Z [WARN]  storage.consul: appending trailing forward slash to path
2023-03-25T16:39:03.760Z [INFO]  core: Initializing version history cache for core
==> Vault server started! Log data will stream in below:

2023-03-25T16:39:09.893Z [INFO]  core: security barrier not initialized
2023-03-25T16:39:09.896Z [INFO]  core: seal configuration missing, not initialized
2023-03-25T16:39:14.897Z [INFO]  core: security barrier not initialized
2023-03-25T16:39:14.900Z [INFO]  core: seal configuration missing, not initialized
~~~

- проведем инициализацию через любой под vault'а
~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Unseal Key 1: zWPVT9d4JYVWqIJdwr+DeqE8gi3pl2V2aa4hsvT1aQo=

Initial Root Token: hvs.7l6Cuei6wjRMIo6eVjvZILxL

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

> -key-shares (int: 5) - Number of key shares to split the generated master key into. This is the number of "unseal keys" to generate. This is aliased as -n.

> -key-threshold (int: 3) - Number of key shares required to reconstruct the root key. This must be less than or equal to -key-shares. This is aliased as -t.


~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=2 --key-threshold=1
~~~
~~~
Error initializing: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/init
Code: 400. Errors:

* invalid seal configuration: threshold must be greater than one for multiple shares
command terminated with exit code 2
~~~

~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=5 --key-threshold=3
~~~~
~~~
Unseal Key 1: AkbLwOGYPGVn36KtvOL9/HN75G6ZPRBbq1nVNJwMy+it
Unseal Key 2: kTqC+TgNCTdMfxcSbGTFjWQOaOJRET06SMFgsO0+tbq8
Unseal Key 3: h+vzPyk33QdCLWn0rcmUnyZ8aF/tAM/LFFyt6tVDpGva
Unseal Key 4: yfzrshFsPw5RFqub/gJ4Nl1I9hGEFFc4WAPujtAmQFcS
Unseal Key 5: 77d9+KICIBVSJ76vaDaj1pIlj7xZwdGyTIe2/tJQEItZ

Initial Root Token: hvs.pyYm3cuxvd5a50u6GPDt3Jrg

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Error initializing: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/init
Code: 400. Errors:

* Vault is already initialized
  command terminated with exit code 2
~~~

Переустанавливаем:
~~~bash
helm uninstall vault
helm uninstall consul
kubectl delete pvc data-default-consul-consul-server-{0,1,2}

helm install consul consul-helm
helm install vault vault-helm -f ../vault.values.yaml
kubectl get pvc
~~~
~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Unseal Key 1: CSRX+WYAE87N+bbttqpnF9vwSOjqkPLtUhCSojmKeAY=

Initial Root Token: hvs.ussR8jxWWjNSXSRAjpZ8lebL

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

## **Полезное:**

