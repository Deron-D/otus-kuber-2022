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
~~~



</details>