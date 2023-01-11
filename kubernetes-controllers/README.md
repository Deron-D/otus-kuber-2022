# **Лекция №3: Механика запуска и взаимодействия контейнеров в Kubernetes // ДЗ**
> _kubernetes-controllers_
<details>
  <summary>Kubernetes controllers. ReplicaSet, Deployment, DaemonSet</summary>

## **Задание:**
Kubernetes controllers. ReplicaSet, Deployment, DaemonSet
Цель:
В данном дз студенты научатся формировать Replicaset, Deployment для своего приложения. Научатся управлять обновлением своего приложения. Так же научатся использовать механизм Probes для проверки работоспособности своих приложений.
Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.

Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

# **Полезное:**
### 1. Подготовка

- Установка kind (Linux)

~~~bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
~~~

Создадим `kind-config.yaml` со следующим содержимым:
~~~yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
~~~

- Запустим кластер
~~~bash
kind create cluster --config kind-config.yaml
~~~
~~~
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼 
 ✓ Preparing nodes 📦 📦 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a nice day! 👋
~~~
- Проверим получившуюся конфигурацию кластера
~~~bash
kubectl get nodes
~~~
~~~
NAME                 STATUS   ROLES           AGE    VERSION
kind-control-plane   Ready    control-plane   2m6s   v1.25.3
kind-worker          Ready    <none>          100s   v1.25.3
kind-worker2         Ready    <none>          100s   v1.25.3
kind-worker3         Ready    <none>          100s   v1.25.3
~~~

### 2. ReplicaSet
 
- Создадим `frontend-replicaset.yaml` со следующим содержимым:
~~~yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: deron73/hipster-frontend:0.3
        env:
        - name: PORT
          value: "8080"
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"
~~~

- Деплоим и проверяем:
~~~bash
kubectl apply -f frontend-replicaset.yaml
kubectl get replicaset
~~~
~~~
NAME       DESIRED   CURRENT   READY   AGE
frontend   1         1         1       3m7s
~~~
~~~bash
kubectl get pods -l app=frontend
~~~
~~~
NAME             READY   STATUS    RESTARTS   AGE
frontend-4h5vj   1/1     Running   0          105s
~~~

- Пробуем увеличить количество реплик сервиса ad-hoc командой:
~~~bash
kubectl scale replicaset frontend --replicas=3
kubectl get rs frontend
~~~
~~~
NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       6m1s
~~~

- Проверим, что благодаря контроллеру pod’ы действительно восстанавливаются после их ручного удаления:
~~~bash
kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w
~~~
~~~
NAME             READY   STATUS    RESTARTS   AGE
frontend-4h5vj   1/1     Running   0          5m
frontend-82bst   1/1     Running   0          99s
frontend-nhhxt   1/1     Running   0          99s
frontend-4h5vj   1/1     Terminating   0          5m
frontend-82bst   1/1     Terminating   0          99s
frontend-755kd   0/1     Pending       0          0s
frontend-nhhxt   1/1     Terminating   0          99s
frontend-755kd   0/1     Pending       0          0s
frontend-5z6mz   0/1     Pending       0          0s
frontend-755kd   0/1     ContainerCreating   0          0s
frontend-5z6mz   0/1     Pending             0          0s
frontend-8xkpz   0/1     Pending             0          0s
frontend-8xkpz   0/1     Pending             0          0s
frontend-5z6mz   0/1     ContainerCreating   0          0s
frontend-8xkpz   0/1     ContainerCreating   0          0s
frontend-nhhxt   0/1     Terminating         0          99s
frontend-4h5vj   0/1     Terminating         0          5m
frontend-nhhxt   0/1     Terminating         0          99s
frontend-nhhxt   0/1     Terminating         0          99s
frontend-82bst   0/1     Terminating         0          99s
frontend-82bst   0/1     Terminating         0          99s
frontend-82bst   0/1     Terminating         0          99s
frontend-5z6mz   1/1     Running             0          0s
frontend-4h5vj   0/1     Terminating         0          5m
frontend-4h5vj   0/1     Terminating         0          5m
frontend-8xkpz   1/1     Running             0          1s
frontend-755kd   1/1     Running             0          1s
~~~

- Повторно применим манифест `frontend-replicaset.yaml` и убедимся, что количество реплик вновь уменьшилось до одной
~~~bash
kubectl apply -f frontend-replicaset.yaml
kubectl get pods -l app=frontend -w
~~~
~~~
replicaset.apps/frontend configured

NAME             READY   STATUS        RESTARTS   AGE
frontend-5z6mz   1/1     Terminating   0          19m
frontend-755kd   1/1     Running       0          19m
frontend-8xkpz   1/1     Terminating   0          19m
frontend-8xkpz   0/1     Terminating   0          19m
frontend-8xkpz   0/1     Terminating   0          19m
frontend-8xkpz   0/1     Terminating   0          19m
frontend-5z6mz   0/1     Terminating   0          19m
frontend-5z6mz   0/1     Terminating   0          19m
frontend-5z6mz   0/1     Terminating   0          19m
~~~

### 3. Обновление ReplicaSet

- Добавим на DockerHub версию образа с новым тегом 0.3
~~~bash
docker tag deron73/hipster-frontend:0.2 deron73/hipster-frontend:0.3
docker push deron73/hipster-frontend:0.3
~~~

- Обновим в манифесте `frontend-replicaset.yaml` версию образа и применим новый манифест, параллельно запустив отслеживание происходящего:
~~~bash
kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w
~~~
~~~
NAME             READY   STATUS    RESTARTS   AGE
frontend-755kd   1/1     Running   0          24m
~~~
>  Ничего не произошло.

- проверим образ, указанный в ReplicaSet:
~~~bash
kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
~~~
~~~
deron73/hipster-frontend:0.3% 
~~~

- и образ из которого сейчас запущены pod, управляемые контроллером:
~~~bash
kubectl get pods -l app=frontend -o=jsonpath='{.items[0].spec.containers[0].image}'
~~~
~~~
deron73/hipster-frontend:0.2%   
~~~
> Подробнее с функционалом JSONPath Support в kubectl можно ознакомиться по [ссылке](https://kubernetes.io/docs/reference/kubectl/jsonpath/)

- Удалим все запущенные pod и после их пересоздания еще раз проверим, из какого образа они развернулись
~~~bash
kubectl delete -f frontend-replicaset.yaml
kubectl apply -f frontend-replicaset.yaml
kubectl get pods -l app=frontend -o=jsonpath='{.items[0].spec.containers[0].image}'
~~~
~~~
replicaset.apps "frontend" deleted
replicaset.apps/frontend created
deron73/hipster-frontend:0.3%                 
~~~

> Руководствуясь материалами лекции опишите произошедшую ситуацию, почему обновление ReplicaSet не повлекло обновление запущенных pod?

ReplicaSet гарантирует только факт заданного числа запущенных экземпляров подов в кластере Kubernetes в момент времени. Т.о. ReplicaSet не перезапускает поды при обновлении спецификации пода, в отличие от Deployment.

### 4. Deployment

- Повторим действия, проделанные с микросервисом 'frontend' для микросервиса 'paymentService'. Используем label 'app: paymentservice'.
~~~bash
pushd
cd ../../microservices-demo/src/paymentservice/
docker build -t deron73/hipster-paymentservice:v0.0.1 .
docker build -t deron73/hipster-paymentservice:v0.0.2 .
docker push deron73/hipster-paymentservice:v0.0.1
docker push deron73/hipster-paymentservice:v0.0.2
popd
~~~
~~~bash
kubectl run paymentservice --image deron73/hipster-paymentservice:v0.0.1 --restart=Never
kubectl run paymentservice --image deron73/hipster-paymentservice:v0.0.1 --restart=Never --dry-run=client -o yaml > paymentservice-replicaset.yaml
~~~

- Скопируем содержимое файла `paymentservice-replicaset.yaml` в файл `paymentservice-deployment.yaml`. Изменим поле `kind` с `ReplicaSet` на `Deployment` и  проверим:

~~~bash
kubectl apply -f paymentservice-deployment.yaml
kubectl get pods
~~~
~~~
NAME                   READY   STATUS    RESTARTS   AGE
frontend-rpzrp         1/1     Running   0          5h44m
paymentservice-m4nvk   1/1     Running   0          4h39m
paymentservice-phxxj   1/1     Running   0          4h48m
paymentservice-zmdl5   1/1     Running   0          4h39m
~~~

- помимо Deployments...
~~~bash
kubectl get deployments
~~~
~~~
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
paymentservice   3/3     3            3           75s
~~~

- появился новый ReplicaSet
~~~bash
kubectl get rs
~~~
~~~
NAME             DESIRED   CURRENT   READY   AGE
frontend         1         1         1       5h46m
paymentservice   3         3         3       4h52m
~~~

### 5. Обновление Deployment

Пробуем обновить наш Deployment на версию образа v0.0.2:
~~~bash
kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w
~~~
~~~
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-7964d56bf7-9fq5d   1/1     Running   0          99s
paymentservice-7964d56bf7-cm9zd   1/1     Running   0          99s
paymentservice-7964d56bf7-lhp58   1/1     Running   0          99s
paymentservice-5bc79cd9f6-hgwq6   0/1     Pending   0          0s
paymentservice-5bc79cd9f6-hgwq6   0/1     Pending   0          0s
paymentservice-5bc79cd9f6-hgwq6   0/1     ContainerCreating   0          0s
paymentservice-5bc79cd9f6-hgwq6   1/1     Running             0          3s
paymentservice-7964d56bf7-9fq5d   1/1     Terminating         0          102s
paymentservice-5bc79cd9f6-mxgzl   0/1     Pending             0          0s
paymentservice-5bc79cd9f6-mxgzl   0/1     Pending             0          0s
paymentservice-5bc79cd9f6-mxgzl   0/1     ContainerCreating   0          0s
paymentservice-5bc79cd9f6-mxgzl   1/1     Running             0          3s
paymentservice-7964d56bf7-lhp58   1/1     Terminating         0          105s
paymentservice-5bc79cd9f6-8mkth   0/1     Pending             0          0s
paymentservice-5bc79cd9f6-8mkth   0/1     Pending             0          0s
paymentservice-5bc79cd9f6-8mkth   0/1     ContainerCreating   0          0s
paymentservice-5bc79cd9f6-8mkth   1/1     Running             0          3s
paymentservice-7964d56bf7-cm9zd   1/1     Terminating         0          108s
paymentservice-7964d56bf7-9fq5d   0/1     Terminating         0          2m13s
paymentservice-7964d56bf7-9fq5d   0/1     Terminating         0          2m13s
paymentservice-7964d56bf7-9fq5d   0/1     Terminating         0          2m13s
paymentservice-7964d56bf7-lhp58   0/1     Terminating         0          2m16s
paymentservice-7964d56bf7-lhp58   0/1     Terminating         0          2m16s
paymentservice-7964d56bf7-lhp58   0/1     Terminating         0          2m16s
paymentservice-7964d56bf7-cm9zd   0/1     Terminating         0          2m19s
paymentservice-7964d56bf7-cm9zd   0/1     Terminating         0          2m19s
paymentservice-7964d56bf7-cm9zd   0/1     Terminating         0          2m19s
~~~

Наблюдаем, что по умолчанию применяется стратегия `Rolling Update`:
- Создание одного нового pod с версией образа v0.0.2;
- Удаление одного из старых pod;
- Создание еще одного нового pod;
- …

Убедимся что:
- Все новые pod развернуты из образа v0.0.2;
- Создано два ReplicaSet:
- Один (новый) управляет тремя репликами pod с образом v0.0.2;
- Второй (старый) управляет нулем реплик pod с образом v0.0.1;
~~~bash
kubectl describe pods | grep -i 'pulling image'
~~~
~~~
  Normal  Pulling    3m28s  kubelet            Pulling image "deron73/hipster-paymentservice:v0.0.2"
  Normal  Pulling    3m33s  kubelet            Pulling image "deron73/hipster-paymentservice:v0.0.2"
  Normal  Pulling    3m31s  kubelet            Pulling image "deron73/hipster-paymentservice:v0.0.2"
~~~
~~~bash
kubectl get rs
kubectl describe rs
~~~
~~~
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-5bc79cd9f6   3         3         3       5m35s
paymentservice-7964d56bf7   0         0         0       7m14s
~~~
~~~
Name:           paymentservice-5bc79cd9f6
Namespace:      default
Selector:       app=paymentservice,pod-template-hash=5bc79cd9f6
Labels:         app=paymentservice
                pod-template-hash=5bc79cd9f6
Annotations:    deployment.kubernetes.io/desired-replicas: 3
                deployment.kubernetes.io/max-replicas: 4
                deployment.kubernetes.io/revision: 2
Controlled By:  Deployment/paymentservice
Replicas:       3 current / 3 desired
Pods Status:    3 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=paymentservice
           pod-template-hash=5bc79cd9f6
  Containers:
   server:
    Image:      deron73/hipster-paymentservice:v0.0.2
    Port:       <none>
    Host Port:  <none>
    Environment:
      PORT:              50051
      DISABLE_TRACING:   1
      DISABLE_PROFILER:  1
      DISABLE_DEBUGGER:  1
    Mounts:              <none>
  Volumes:               <none>
Events:
  Type    Reason            Age    From                   Message
  ----    ------            ----   ----                   -------
  Normal  SuccessfulCreate  5m35s  replicaset-controller  Created pod: paymentservice-5bc79cd9f6-hgwq6
  Normal  SuccessfulCreate  5m32s  replicaset-controller  Created pod: paymentservice-5bc79cd9f6-mxgzl
  Normal  SuccessfulCreate  5m29s  replicaset-controller  Created pod: paymentservice-5bc79cd9f6-8mkth
~~~
~~~
Name:           paymentservice-7964d56bf7
Namespace:      default
Selector:       app=paymentservice,pod-template-hash=7964d56bf7
Labels:         app=paymentservice
                pod-template-hash=7964d56bf7
Annotations:    deployment.kubernetes.io/desired-replicas: 3
                deployment.kubernetes.io/max-replicas: 4
                deployment.kubernetes.io/revision: 1
Controlled By:  Deployment/paymentservice
Replicas:       0 current / 0 desired
Pods Status:    0 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=paymentservice
           pod-template-hash=7964d56bf7
  Containers:
   server:
    Image:      deron73/hipster-paymentservice:v0.0.1
    Port:       <none>
    Host Port:  <none>
    Environment:
      PORT:              50051
      DISABLE_TRACING:   1
      DISABLE_PROFILER:  1
      DISABLE_DEBUGGER:  1
    Mounts:              <none>
  Volumes:               <none>
Events:
  Type    Reason            Age    From                   Message
  ----    ------            ----   ----                   -------
  Normal  SuccessfulCreate  7m14s  replicaset-controller  Created pod: paymentservice-7964d56bf7-cm9zd
  Normal  SuccessfulCreate  7m14s  replicaset-controller  Created pod: paymentservice-7964d56bf7-9fq5d
  Normal  SuccessfulCreate  7m14s  replicaset-controller  Created pod: paymentservice-7964d56bf7-lhp58
  Normal  SuccessfulDelete  5m32s  replicaset-controller  Deleted pod: paymentservice-7964d56bf7-9fq5d
  Normal  SuccessfulDelete  5m29s  replicaset-controller  Deleted pod: paymentservice-7964d56bf7-lhp58
  Normal  SuccessfulDelete  5m26s  replicaset-controller  Deleted pod: paymentservice-7964d56bf7-cm9zd
~~~

Также мы можем посмотреть на историю версий нашего Deployment:
~~~bash
kubectl rollout history deployment paymentservice
~~~
~~~
deployment.apps/paymentservice 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
~~~

### 6. Deployment | Rollback

Представим, что обновление по каким-то причинам произошло неудачно и нам необходимо сделать откат. Kubernetes предоставляет такую возможность:
~~~bash
kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w
~~~
~~~
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-5bc79cd9f6   3         3         3       11m
paymentservice-7964d56bf7   0         0         0       12m
paymentservice-7964d56bf7   0         0         0       12m
paymentservice-7964d56bf7   1         0         0       12m
paymentservice-7964d56bf7   1         0         0       12m
paymentservice-7964d56bf7   1         1         0       12m
paymentservice-7964d56bf7   1         1         1       12m
paymentservice-5bc79cd9f6   2         3         3       11m
paymentservice-5bc79cd9f6   2         3         3       11m
paymentservice-7964d56bf7   2         1         1       12m
paymentservice-5bc79cd9f6   2         2         2       11m
paymentservice-7964d56bf7   2         1         1       12m
paymentservice-7964d56bf7   2         2         1       12m
paymentservice-7964d56bf7   2         2         2       12m
paymentservice-5bc79cd9f6   1         2         2       11m
paymentservice-5bc79cd9f6   1         2         2       11m
paymentservice-7964d56bf7   3         2         2       12m
paymentservice-5bc79cd9f6   1         1         1       11m
paymentservice-7964d56bf7   3         2         2       12m
paymentservice-7964d56bf7   3         3         2       12m
paymentservice-7964d56bf7   3         3         3       12m
paymentservice-5bc79cd9f6   0         1         1       11m
paymentservice-5bc79cd9f6   0         1         1       11m
paymentservice-5bc79cd9f6   0         0         0       11m
~~~
В выводе мы можем наблюдать, как происходит постепенное масштабирование вниз “нового” ReplicaSet `paymentservice-5bc79cd9f6`, и масштабирование вверх
“старого” `paymentservice-7964d56bf7`.

~~~bash
kubectl describe pods | grep -i 'Image:'
~~~
~~~
    Image:          deron73/hipster-paymentservice:v0.0.1
    Image:          deron73/hipster-paymentservice:v0.0.1
    Image:          deron73/hipster-paymentservice:v0.0.1
~~~

### 7. Deployment | Задание со ⭐

##### 'Аналог blue-green:' [./paymentservice-deployment-bg.yaml](./paymentservice-deployment-bg.yaml)
1. Развертывание трех новых pod;
2. Удаление трех старых pod;
~~~yaml
...
spec:
  replicas: 3
  strategy:
  rollingUpdate:
    maxSurge: 3
    maxUnavailable: 3
...
~~~

##### 'Аналог Reverse Rolling Update:'[./paymentservice-deployment-reverse.yaml](./paymentservice-deployment-reverse.yaml)
1. Удаление одного старого pod;
2. Создание одного нового pod;
3. …
~~~yaml
...
spec:
  replicas: 3
  strategy:
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
...
~~~

### 8. Probes

Создадим манифест 'frontend-deployment.yaml' из которого можно развернуть три реплики pod с тегом образа '0.1'
Добавим туда описание 'readinessProbe'
~~~yaml
...
        image: deron73/hipster-frontend:0.1
        ports:
        - containerPort: 8080
        readinessProbe:
          initialDelaySeconds: 10
          httpGet:
            path: "/_healthz"
            port: 8080
            httpHeaders:
            - name: "Cookie"
              value: "shop_session-id=x-readiness-probe"
...
~~~

Развернем и проверим:
~~~bash
kubectl apply  -f frontend-deployment.yaml
~~~
~~~bash
kubectl get pods -l app=frontend 
~~~
~~~
NAME                       READY   STATUS    RESTARTS   AGE
frontend-66c64859c-jmwx5   1/1     Running   0          56s
frontend-66c64859c-mlnvb   1/1     Running   0          56s
frontend-66c64859c-pz5lr   1/1     Running   0          56s
~~~
~~~bash
kubectl describe pod -l app=frontend | grep 'Readiness'
~~~
~~~
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3

~~~
Попробуем сымитировать некорректную работу приложения и посмотрим, как будет вести себя обновление:
Исправим описание 'readinessProbe'
~~~yaml
...
        image: deron73/hipster-frontend:0.2 # Развернем версию 0.2.
        ports:
        - containerPort: 8080
        readinessProbe:
          initialDelaySeconds: 10
          httpGet:
            path: "/_health" # Заменим в описании пробы URL /_healthz на /_health ;
            port: 8080
            httpHeaders:
            - name: "Cookie"
              value: "shop_session-id=x-readiness-probe"
...
~~~
Деплоим и проверяем:
~~~bash
kubectl apply -f frontend-deployment.yaml | kubectl get pods -l app=frontend -w
~~~
~~~
NAME                       READY   STATUS    RESTARTS   AGE
frontend-66c64859c-jmwx5   1/1     Running   0          16m
frontend-66c64859c-mlnvb   1/1     Running   0          16m
frontend-66c64859c-pz5lr   1/1     Running   0          16m
frontend-6b546c9f5b-cdrdq   0/1     Pending   0          0s
frontend-6b546c9f5b-cdrdq   0/1     Pending   0          0s
frontend-6b546c9f5b-cdrdq   0/1     ContainerCreating   0          0s
frontend-6b546c9f5b-cdrdq   0/1     Running             0          11s
~~~
~~~bash
kubectl describe pod -l app=frontend | grep 'Readiness'
~~~
~~~
   Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8080/_health delay=10s timeout=1s period=10s #success=1 #failure=3
  Warning  Unhealthy  0s (x19 over 2m40s)  kubelet            Readiness probe failed: HTTP probe failed with statuscode: 404
~~~

Как можно было заметить, пока readinessProbe для нового pod не станет успешной - `Deployment` не будет пытаться продолжить обновление.
На данном этапе может возникнуть вопрос - как автоматически отследить успешность выполнения `Deployment` (например для запуска в
CI/CD).
В этом нам может помочь следующая команда:
~~~bash
kubectl rollout status deployment/frontend
~~~
~~~
Waiting for deployment "frontend" rollout to finish: 1 out of 3 new replicas have been updated...
~~~

Таким образом описание pipeline, включающее в себя шаг развертывания и шаг отката, в самом простом случае может выглядеть так (синтаксис GitLab CI):
~~~yaml
deploy_job:
  stage: deploy
  script:
    - |
      kubectl apply -f frontend-deployment.yaml
      kubectl rollout status deployment/frontend --timeout=60s

rollback_deploy_job:
  stage: rollback
  script:
    - kubectl rollout undo deployment/frontend
  when: on_failure
~~~

### 9. DaemonSet

Отличительная особенность DaemonSet в том, что при его применении на каждом физическом хосте создается по одному экземпляру pod, описанного в спецификации.
Типичные кейсы использования DaemonSet:
- Сетевые плагины;
- Утилиты для сбора и отправки логов (Fluent Bit, Fluentd, etc…);
- Различные утилиты для мониторинга (Node Exporter, etc…);
- ...

#### Задание со ⭐

- Гуглим и берем манифест 'nodeexporter-daemonset.yaml' для развертывания DaemonSet с Node Exporter
[https://github.com/intuit/foremast/blob/master/deploy/prometheus-operator/node-exporter-daemonset.yaml](https://github.com/intuit/foremast/blob/master/deploy/prometheus-operator/node-exporter-daemonset.yaml);

- Деплоим:
~~~bash
kubectl apply -f node-exporter-daemonset.yaml
kubectl get ds
~~~
~~~
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
node-exporter   4         4         0       4            0           kubernetes.io/os=linux   17s
~~~
~~~bash
kubectl port-forward --address 0.0.0.0 ds/node-exporter  9100:9100 &
~~~
~~~bash
curl localhost:9100/metrics
~~~
~~~
Handling connection for 9100
# HELP go_gc_duration_seconds A summary of the GC invocation durations.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 3.1987e-05
go_gc_duration_seconds{quantile="0.25"} 4.2464e-05
go_gc_duration_seconds{quantile="0.5"} 0.000102108
go_gc_duration_seconds{quantile="0.75"} 0.000243675
go_gc_duration_seconds{quantile="1"} 0.004999632
go_gc_duration_seconds_sum 0.005612348
go_gc_duration_seconds_count 7
...
~~~

#### DaemonSet | Задание с ⭐️⭐

> [https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

Модернизируем свой `DaemonSet` таким образом, чтобы Node Exporter был развернут как на master, так и на worker нодах:
~~~yaml
    spec:
      tolerations:
      # these tolerations are to have the daemonset runnable on control plane nodes
      # remove them if your control plane nodes should not run pods
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
~~~
~~~bash
kubectl describe node kind-control-plane
~~~
~~~
...
Non-terminated Pods:          (10 in total)
  Namespace                   Name                                          CPU Requests  CPU Limits  Memory Requests  Memory Limits  Age
  ---------                   ----                                          ------------  ----------  ---------------  -------------  ---
  default                     node-exporter-qwxk9                           112m (0%)     270m (2%)   200Mi (2%)       220Mi (3%)     47s
...git 
~~~

~~~bash
kind delete cluster
~~~

# **Полезное:**
[Документация с описанием стратегий развертывания для Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)

</details>