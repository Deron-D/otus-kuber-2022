# **Лекция №10: Сервисы централизованного логирования для компонентов Kubernetes и приложений // ДЗ**
> _Сервисы централизованного логирования для Kubernetes_
<details>
  <summary>kubernetes-logging</summary>

## **Задание:**
Сервисы централизованного логирования для Kubernetes

Цель:
В домашнем задании развернем сервисы для централизованного логирования (EFK/Loki) внутри Kubernetes, научимся отправлять туда структурированные логи продукта и инфраструктурных компонентов, рассмотрим способы визуализировать информацию из логов


Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.


Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### 1. Подготовка Kubernetes кластера

- Поднимаем кластер k8s в yandex-cloud со следующими параметрами:
  - Как минимум 1 нода типа `standard-v2` в группе узлов `default-pool`
  - Как минимум 3 ноды типа `standard-v2` в группе узлов `infra-pool`
~~~bash
cd terraform-k8s
terraform init
terraform plan
terraform apply
~~~

~~~bash
yc managed-kubernetes cluster list-node-groups k8s-4otus
yc managed-kubernetes node-group list
yc managed-kubernetes node-group list-nodes infra-pool
~~~
~~~
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
|         CLOUD INSTANCE         |      KUBERNETES NODE      |           RESOURCES            |    DISK     | STATUS |
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
| ef3pdkf839gkc5n0o9rh           | cl14c492d4hm419b06ho-anuh | 2 100% core(s), 8.0 GB of      | 30.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
| ef37n1rdp4n92hes4vl0           | cl14c492d4hm419b06ho-eqog | 2 100% core(s), 8.0 GB of      | 30.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
| ef3deolh8fk91t79omv6           | cl14c492d4hm419b06ho-ixov | 2 100% core(s), 8.0 GB of      | 30.0 GB hdd | READY  |
| RUNNING_ACTUAL                 |                           | memory                         |             |        |
+--------------------------------+---------------------------+--------------------------------+-------------+--------+
~~~

В результате должна получиться следующая конфигурация кластера:
~~~bash
kubectl get nodes -o wide
~~~

~~~
NAME                        STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP     OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
cl14c492d4hm419b06ho-anuh   Ready    <none>   24m   v1.23.6   10.130.0.10   51.250.47.239   Ubuntu 20.04.4 LTS   5.4.0-124-generic   containerd://1.6.7
cl14c492d4hm419b06ho-eqog   Ready    <none>   24m   v1.23.6   10.130.0.33   51.250.36.137   Ubuntu 20.04.4 LTS   5.4.0-124-generic   containerd://1.6.7
cl14c492d4hm419b06ho-ixov   Ready    <none>   24m   v1.23.6   10.130.0.12   51.250.37.122   Ubuntu 20.04.4 LTS   5.4.0-124-generic   containerd://1.6.7
cl1erdumrsmef8ne1tpu-oheq   Ready    <none>   48m   v1.23.6   10.130.0.31   51.250.37.252   Ubuntu 20.04.4 LTS   5.4.0-124-generic   containerd://1.6.7
~~~
~~~bash
yc managed-kubernetes node-group list-nodes infra-pool
~~~

Пометим ноды `infra-pool` тейнтом `node-role=infra:NoSchedule` 
~~~bash
kubectl taint nodes cl19nlrekjkf36otr3kj-emoh node-role=infra:NoSchedule
~~~

Проверим `taints` на нодах
~~~bash
kubectl get nodes -o json | jq '.items[].spec.taints'
~~~
~~~
[
  {
    "effect": "NoSchedule",
    "key": "node-role",
    "value": "infra"
  }
]
[
  {
    "effect": "NoSchedule",
    "key": "node-role",
    "value": "infra"
  }
]
[
  {
    "effect": "NoSchedule",
    "key": "node-role",
    "value": "infra"
  }
]
null
~~~

### 2. Установка HipsterShop

Для начала, установим в Kubernetes кластер уже знакомый нам HipsterShop.
~~~bash
kubectl create ns microservices-demo
kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Logging/microservices-demo-without-resources.yaml \
-n microservices-demo
~~~

Проверим, что все pod развернулись на ноде из default-pool:
~~~bash
kubectl get pods -n microservices-demo -o wide
~~~
~~~
NAME                                     READY   STATUS             RESTARTS      AGE   IP              NODE                        NOMINATED NODE   READINESS GATES
adservice-548889999f-mv2db               0/1     ImagePullBackOff   0             16m   10.112.128.20   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
cartservice-75cc479cdd-wl2xl             1/1     Running            2 (14m ago)   16m   10.112.128.15   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
checkoutservice-699758c6d9-r5w9n         1/1     Running            0             16m   10.112.128.10   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
currencyservice-7fc9cfc9cf-kqk9f         1/1     Running            0             16m   10.112.128.17   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
emailservice-6c8d49f789-9j6hq            1/1     Running            0             16m   10.112.128.9    cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
frontend-5b8c8bf745-csmrr                1/1     Running            0             16m   10.112.128.12   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
loadgenerator-799c7664dd-n4tdq           1/1     Running            4 (14m ago)   16m   10.112.128.16   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
paymentservice-557f767677-jp9fp          1/1     Running            0             16m   10.112.128.13   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
productcatalogservice-7b69d99c89-gl49b   1/1     Running            0             16m   10.112.128.14   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
recommendationservice-7f78d66cc9-v9qz4   1/1     Running            0             16m   10.112.128.11   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
redis-cart-fd8d87cdb-9vmhj               1/1     Running            0             16m   10.112.128.19   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
shippingservice-64999cdc59-vttr8         1/1     Running            0             16m   10.112.128.18   cl1erdumrsmef8ne1tpu-oheq   <none>           <none>
~~~

### 3. Установка EFK стека | Helm charts

Начнем с "классического" набора инструментов (ElasticSearch, Fluent Bit, Kibana) и "классического" способа его установки в Kubernetes кластер (Helm).
Рекомендуемый репозиторий с Helm chart для ElasticSearch и Kibana на текущий момент - [https://github.com/elastic/helm-charts](https://github.com/elastic/helm-charts)
Добавим его:
~~~bash
helm repo add elastic https://helm.elastic.co
~~~
И установим нужные нам компоненты, для начала - без какой-либо дополнительной настройки:
~~~bash
kubectl create ns observability
# ElasticSearch
helm upgrade --install elasticsearch elastic/elasticsearch --namespace observability
# Kibana
helm upgrade --install kibana elastic/kibana --namespace observability
# Fluent Bit
helm upgrade --install fluent-bit stable/fluent-bit --namespace observability
~~~

И ловим `403` - `No comments...`
Идем другим путем:
~~~bash
helm repo remove elastic 
helm repo add bitnami https://charts.bitnami.com/bitnami
# ElasticSearch
helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability
# Kibana
helm upgrade --install kibana bitnami/kibana --namespace observability
# Fluent Bit
helm upgrade --install fluent-bit stable/fluent-bit --namespace observability
~~~

Смотрим, что получилось
~~~bash
kubectl get pods -n observability -o wide
~~~

Всё поставилось так же, на ту же первую ноду `cl146c3f8e8j94epo9uf-iwop`
~~~
NAME                           READY   STATUS    RESTARTS   AGE     IP              NODE                        NOMINATED NODE   READINESS GATES
elasticsearch-coordinating-0   0/1     Running   0          2m11s   10.112.131.18   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-coordinating-1   0/1     Running   0          2m11s   10.112.131.20   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-data-0           0/1     Running   0          2m11s   10.112.131.23   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-data-1           0/1     Running   0          2m11s   10.112.131.21   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-ingest-0         0/1     Running   0          2m11s   10.112.131.17   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-ingest-1         0/1     Running   0          2m11s   10.112.131.19   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-master-0         0/1     Running   0          2m11s   10.112.131.22   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
elasticsearch-master-1         0/1     Running   0          2m11s   10.112.131.24   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
fluent-bit-bpr5l               1/1     Running   0          12m     10.112.131.16   cl146c3f8e8j94epo9uf-iwop   <none>           <none>
~~~

Создадим файл `elasticsearch.values.yaml` , будем указывать в этом файле нужные нам values.
Для начала, обратимся к файлу `values.yaml` в и найдем там ключ `tolerations`.

~~~bash
helm inspect values bitnami/elasticsearch | grep -A 5 'tolerations'
~~~
~~~bash
helm inspect values bitnami/elasticsearch | grep -v '^ *#'  | grep -A 5 'tolerations'
~~~

Мы помним, что ноды из infra-pool имеют taint node-role=infra:NoSchedule . Давайте разрешим ElasticSearch запускаться на данных нодах
> elasticsearch.values.yaml
~~~yaml
tolerations:
  - key: node-role
    operator: Equal
    value: infra
    effect: NoSchedule

~~~

Обновим установку:
~~~bash
helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability \
-f elasticsearch.values.yaml
~~~

Смотрим, что получилось
~~~bash
kubectl get pods -n observability -o wide
~~~

Теперь ElasticSearch может запускаться на нодах из `infra-pool`, но это не означает, что он должен это делать.
Исправим этот момент и добавим в `elasticsearch.values.yaml` `NodeSelector`, определяющий, на каких нодах мы можем запускать наши pod.
~~~yaml
nodeSelector:
  yandex.cloud/node-group-id: <group-id> 
~~~
~~~bash
yc managed-kubernetes node-group list
yc managed-kubernetes node-group list-nodes infra-pool
~~~

Опять обновим установку:
~~~bash
helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability \
-f elasticsearch.values.yaml
~~~
~~~
Error: UPGRADE FAILED: release: already exists
~~~
~~~bash
kubectl create ns observability
helm uninstall elasticsearch --namespace observability
helm upgrade --install elasticsearch bitnami/elasticsearch --namespace observability \
-f elasticsearch.values.yaml
~~~
Смотрим, что получилось
~~~bash
kubectl get pods -n observability -o wide
~~~



# **Полезное:**

https://registry.tfpla.net/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group#node_taints
https://cloud.yandex.ru/docs/managed-kubernetes/api-ref/NodeGroup/
https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#spread-constraints-for-pods
https://blog.kubecost.com/blog/kubernetes-taints/
https://docs.comcloud.xyz/

</details>
