# **Лекция №14: GitOps и инструменты поставки // ДЗ**
> _GitOps и инструменты поставки_
<details>
  <summary>kubernetes-gitops</summary>

## **Задание:**
Цель:
В данном дз студенты познакомятся с такими инструментами как ArgoCD, Flux, Flagger. Научатся при помощи этих инструментов деплоить приложение в кластер.

Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.

Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### 1. Подготовка GitLab репозитария

~~~bash
git clone https://github.com/GoogleCloudPlatform/microservices-demo
cd microservices-demo
git remote add gitlab git@gitlab.com:dpnev/microservices-demo.git
git remote remove origin
git push -uf gitlab main
~~~

### 2. Создание Helm чартов
Скопируем готовые чарты из [демонстрационного репозитория](https://gitlab.com/express42/kubernetes-platform-demo/microservices-demo/) (директория `deploy/charts` )
~~~bash
tree -L 1 deploy/charts
~~~
~~~
deploy/charts
├── adservice
├── cartservice
├── checkoutservice
├── currencyservice
├── emailservice
├── frontend
├── grafana-load-dashboards
├── loadgenerator
├── paymentservice
├── productcatalogservice
├── recommendationservice
└── shippingservice
~~~

### 3. Подготовка Kubernetes кластера

Поднимаем кластер k8s в yandex-cloud со следующими параметрами:
  - Как минимум 4 ноды типа `standard-v1` 
~~~bash
cd terraform-k8s
terraform init
terraform plan
terraform apply
~~~


# **Полезное:**

~~~bash
yc managed-kubernetes cluster stop k8s-4otus
~~~

~~~bash
yc managed-kubernetes cluster start k8s-4otus
~~~

</details>
