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
  - Как минимум 4 ноды типа `standard-v1` (Terraform способ) 
~~~bash
cd terraform-k8s
terraform init
terraform plan
terraform apply
~~~
  - Как минимум 4 ноды типа `standard-v1` (yc cli)
~~~bash
yc managed-kubernetes cluster create k8s-4otus \
--network-id "enp4jp0tqr08ga9s2db6" \
--zone "ru-central1-c" \
--subnet-id "b0cano23aicjlcfpskk3" \
--public-ip \
--release-channel RAPID \
--version 1.24 \
--node-service-account-name tfuser \
--service-account-id "aje43vf2rvfqf5tahtuf" \
--cloud-id "b1g85rkpqt0ukuce35r3" \
--folder-id "b1go8bvc3bokuukkbj26" \
--token "TOKEN" \
--no-user-output
~~~

~~~bash
yc managed-kubernetes node-group create k8s-4otus-node-pool \
--cluster-name k8s-4otus \
--fixed-size 2 \
--platform standard-v1 \
--memory 4 \
--cores 2 \
--disk-size 30 \
--disk-type network-hdd \
--version 1.24 \
--cloud-id "b1g85rkpqt0ukuce35r3" \
--folder-id "b1go8bvc3bokuukkbj26" \
--token "TOKEN"
~~~

~~~bash
yc managed-kubernetes cluster get-credentials k8s-4otus --external --force --folder-id b1go8bvc3bokuukkbj26
~~~

 - Проверяем
~~~bash
kubectl get nodes
~~~
~~~
NAME                        STATUS   ROLES    AGE    VERSION
cl1cm56gb3duo2nvbfcb-asun   Ready    <none>   159m   v1.23.6
cl1cm56gb3duo2nvbfcb-ovaq   Ready    <none>   159m   v1.23.6
cl1cm56gb3duo2nvbfcb-ycod   Ready    <none>   159m   v1.23.6
cl1cm56gb3duo2nvbfcb-yjem   Ready    <none>   159m   v1.23.6
~~~

 - Т.к. в `YandexCloud` не реализована установка `Istio` как аддона, ставим `Istio` через Helm:
~~~bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update istio
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system --version 1.17.1
helm install istiod istio/istiod -n istio-system --wait --version 1.17.1
~~~

Проверяем
~~~bash
helm ls -n istio-system
~~~
~~~
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
istio-base      istio-system    1               2023-03-08 22:59:12.30553833 +0300 MSK  deployed        base-1.17.1     1.17.1     
istiod          istio-system    1               2023-03-08 22:59:15.366238727 +0300 MSK deployed        istiod-1.17.1   1.17.1 
~~~

~~~bash
helm status istiod -n istio-system
~~~
~~~
NAME: istiod
LAST DEPLOYED: Wed Mar  8 22:59:15 2023
NAMESPACE: istio-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
"istiod" successfully installed!

To learn more about the release, try:
  $ helm status istiod
  $ helm get all istiod

Next steps:
  * Deploy a Gateway: https://istio.io/latest/docs/setup/additional-setup/gateway/
  * Try out our tasks to get started on common configurations:
    * https://istio.io/latest/docs/tasks/traffic-management
    * https://istio.io/latest/docs/tasks/security/
    * https://istio.io/latest/docs/tasks/policy-enforcement/
    * https://istio.io/latest/docs/tasks/policy-enforcement/
  * Review the list of actively supported releases, CVE publications and our hardening guide:
    * https://istio.io/latest/docs/releases/supported-releases/
    * https://istio.io/latest/news/security/
    * https://istio.io/latest/docs/ops/best-practices/security/

For further documentation see https://istio.io website

Tell us how your install/upgrade experience went at https://forms.gle/hMHGiwZHPU7UQRWe9
~~~

~~~bash
kubectl get deployments -n istio-system --output wide
~~~

~~~
NAME     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                         SELECTOR
istiod   1/1     1            1           20s   discovery    docker.io/istio/pilot:1.17.1   istio=pilot
~~~

Install an Istio ingress gateway
~~~bash
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled
helm install istio-ingress istio/gateway -n istio-ingress --wait --version 1.17.1
~~~

### Подготовка Kubernetes кластера | Задание со ⭐
- Автоматизируйте создание Kubernetes кластера
- Кластер должен разворачиваться после запуска pipeline в GitLab

Подготовлен следующие манифесты для автоматического разворачивания кластера с `Istio` после запуска pipeline в GitLab 
<details>
  <summary>.gitlab-ci.yaml, .variables.yaml </summary>

~~~yaml
include: '.variables.yaml'

stages:
- k8s-ycloud
- dismiss

.base_yc:
before_script:
# Install YC CLI.
    - curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash -s -- -a && cp /root/yandex-cloud/bin/yc /usr/bin/
    - |
      cat <<EOF >> /root/.config/yandex-cloud/config.yaml
      current: default
      profiles:
        default:
          token: ${CI_YC_TOKEN}
          cloud-id: ${CI_CLOUD_ID}
          folder-id: ${CI_CLOUD_ID}
          compute-default-zone: ru-central1-c
      EOF
    - cat /root/.config/yandex-cloud/config.yaml


.managed_kubernetes_create: &managed_kubernetes_create
# Create yc managed kubernetes cluster
- >-
  yc managed-kubernetes cluster create ${CI_CLUSTER_NAME} --network-id ${CI_NETWORK_ID}
  --zone ${CI_ZONE} --subnet-id ${CI_SUBNET_ID} --public-ip --release-channel RAPID
  --version ${CI_K8S_VERSION} --node-service-account-name ${CI_NODE_SERVICE_ACCOUNT_NAME}
  --service-account-id ${CI_SERVICE_ACCOUNT_ID} --cloud-id ${CI_CLOUD_ID}
  --folder-id ${CI_FOLDER_ID} --token ${CI_YC_TOKEN} --no-user-output --enable-network-policy

.managed_node_group_create: &managed_node_group_create
- >-
  yc managed-kubernetes node-group create ${CI_NODE_POOL} --cluster-name ${CI_CLUSTER_NAME}
  --auto-scale min=${CI_AUTO_SCALE_INITIAL},max=${CI_AUTO_SCALE_MAX},initial=${CI_AUTO_SCALE_INITIAL}
  --platform ${CI_NODE_PLATFORM} --memory ${CI_NODE_MEMORY} --cores ${CI_NODE_CORES}
  --disk-type ${CI_NODE_DISK_TYPE} --disk-size ${CI_NODE_DISK_SIZE} --version ${CI_K8S_VERSION}
  --cloud-id ${CI_CLOUD_ID} --folder-id ${CI_FOLDER_ID} --token ${CI_YC_TOKEN}
  --network-interface subnets=${CI_SUBNET_ID},ipv4-address=nat


.kubectl_install: &kubectl_install
- wget -O /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/${CI_KUBECTL_VER}/bin/linux/amd64/kubectl"
- chmod +x /usr/local/bin/kubectl
- |
      yc managed-kubernetes cluster get-credentials ${CI_CLUSTER_NAME} --context-name default \
  --external --force --cloud-id ${CI_CLOUD_ID} --folder-id ${CI_FOLDER_ID} --token ${CI_YC_TOKEN}
- ls -la /root/.kube/
- cat /root/.kube/config
- kubectl cluster-info --kubeconfig /root/.kube/config

.helm_install: &helm_install
- |
      export HELM_URL="https://get.helm.sh"
  export HELM_TAR_FILE="helm-${CI_HELM_VER}-linux-amd64.tar.gz"
  echo "install HELM ${CI_HELM_VER} from \"${HELM_URL}/${HELM_TAR_FILE}\""
  mkdir -p /tmp/helm
  wget -O "/tmp/${HELM_TAR_FILE}" "${HELM_URL}/${HELM_TAR_FILE}"
  tar -xzvf "/tmp/${HELM_TAR_FILE}" -C /tmp/helm
  mv /tmp/helm/linux-amd64/helm /usr/bin/helm
  rm -rf /tmp/helm
  chmod +x /usr/bin/helm
  helm version

.istio_install: &istio_install
- helm repo add istio https://istio-release.storage.googleapis.com/charts
- helm repo update istio
- kubectl create namespace istio-system || true
- helm upgrade --install istio-base istio/base -n istio-system --version ${CI_ISTIO_VERSION}
- helm ls -n istio-system
- helm upgrade --install istiod istio/istiod -n istio-system --version ${CI_ISTIO_VERSION} --wait
- helm ls -n istio-system
- helm status istiod -n istio-system
- kubectl create namespace istio-ingress || true
- kubectl label namespace istio-ingress istio-injection=enabled
- helm upgrade --install istio-ingress istio/gateway -n istio-ingress --version ${CI_ISTIO_VERSION} --wait

.dismiss:
extends: .base_yc
script:
- yc managed-kubernetes cluster delete ${CI_CLUSTER_NAME} --cloud-id ${CI_CLOUD_ID} --folder-id ${CI_FOLDER_ID} --token ${CI_YC_TOKEN}

k8s-ycloud:
extends: .base_yc
stage: k8s-ycloud
allow_failure: true
script:
- *managed_kubernetes_create
- *managed_node_group_create
- *kubectl_install
- *helm_install
- *istio_install

dismiss:
extends: .dismiss
stage: dismiss
when: manual
~~~
- `.variables.yml`
~~~yaml
variables:
  CI_CLUSTER_NAME: k8s-4otus
  CI_NETWORK_ID: enp4jp0tqr08ga9s2db6
  CI_ZONE: ru-central1-c
  CI_SUBNET_ID: b0cano23aicjlcfpskk3
  CI_K8S_VERSION: "1.24"
  CI_NODE_SERVICE_ACCOUNT_NAME: tfuser
  CI_SERVICE_ACCOUNT_ID: aje43vf2rvfqf5tahtuf
  CI_CLOUD_ID: b1g85rkpqt0ukuce35r3
  CI_FOLDER_ID: b1go8bvc3bokuukkbj26
  CI_NODE_POOL: k8s-4otus-node-pool
  CI_AUTO_SCALE_MIN: 1
  CI_AUTO_SCALE_MAX: 4
  CI_AUTO_SCALE_INITIAL: 1
  CI_NODE_PLATFORM: standard-v1
  CI_NODE_MEMORY: 4
  CI_NODE_CORES: 2
  CI_NODE_DISK_TYPE: network-hdd
  CI_NODE_DISK_SIZE: 30
  CI_KUBECTL_VER: v1.25.3
  CI_HELM_VER: v3.11.2
  CI_ISTIO_VERSION: 1.17.1
~~~

</details>

### 4. Continuous Integration | Задание со ⭐
Подготовим pipeline, который будет содержать следующие стадии: 
- Сборку Docker образа для каждого из микросервисов
- Push данного образа в Docker Hub
В качестве тега образа используем `tag` коммита, инициирующего сборку (переменная `CI_COMMIT_TAG` в GitLab CI)

- Создаем файл `.build.yaml` следующего содержания
~~~yaml
build:adservice:
  extends: build
  variables: 
    SERVICE: adservice
    SRVPATH: adservice

build:checkoutservice:
  extends: build
  variables: 
    SERVICE: checkoutservice
    SRVPATH: checkoutservice
...
~~~

- И добавляем в манифест pipeline описание джобы билда 
~~~yaml
build:
  extends: .docker
  stage: build
  allow_failure: true
  before_script:
    - docker login --username oauth --password ${CI_YC_TOKEN} cr.yandex
  script:
    - cd src/${SRVPATH}
    - docker build . -f Dockerfile -t cr.yandex/${CI_CR_YANDEX_ID}/${SERVICE}:${CI_COMMIT_SHORT_SHA}
    - docker push cr.yandex/${CI_CR_YANDEX_ID}/${SERVICE}:${CI_COMMIT_SHORT_SHA}
~~~

Образы у нас успешно собираются и также удачно у нас заканчивается бесплатный лимит времени на раннерах Гитлаба.
Если что, придется отложить запуск CI/CD до следующего месяца :)  
![img_1.png](img_1.png)

![img.png](img.png)

![img_2.png](img_2.png)

### 5. GitOps

Подготовка
> https://github.com/fluxcd/helm-operator/tree/master/chart/helm-operator

- Установим CRD, добавляющую в кластер новый ресурс - HelmRelease:
~~~bash
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/1.4.4/deploy/crds.yaml
~~~

Добавим официальный репозиторий Flux
~~~bash
helm repo add fluxcd https://charts.fluxcd.io
~~~

Произведем установку Flux в кластер, в namespace flux
~~~bash
kubectl create namespace flux
helm upgrade --install flux fluxcd/flux -f flux.values.yaml --namespace flux
~~~

~~~
NOTES:
Get the Git deploy key by either (a) running

  kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2

or by (b) installing fluxctl through
https://fluxcd.io/legacy/flux/references/fluxctl/#installing-fluxctl
and running:

  fluxctl identity --k8s-fwd-ns flux

---
**Flux v1 is deprecated, please upgrade to v2 as soon as possible!**
~~~
# **Полезное:**

- https://cloud.yandex.ru/docs/security/domains/kubernetes
- https://istio.io/latest/docs/setup/install/helm/

 

~~~bash
yc managed-kubernetes cluster stop k8s-4otus
~~~

~~~bash
yc managed-kubernetes cluster start k8s-4otus
~~~

</details>
