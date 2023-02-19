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

1. Подготовка Kubernetes кластера

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
kubectl get nodes -o wide
~~~

~~~bash
yc managed-kubernetes cluster list-node-groups k8s-4otus
yc managed-kubernetes node-group list
yc managed-kubernetes node-group list-nodes infra-pool
~~~
~~~bash
kubectl taint nodes cl19nlrekjkf36otr3kj-emoh node-role=infra:NoSchedule
~~~

# **Полезное:**

https://registry.tfpla.net/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group#node_taints


</details>
