# **Лекция №5: Хранение данных в Kubernetes: Volumes, Storages, Statefull-приложения // ДЗ**
> _kubernetes-volumes_
<details>
  <summary>Volumes, Storages, StatefulSetStatefulSet</summary>

## **Задание:**
Цель:
В данном дз студенты научатся работать с volume, PV и PVC. Разберутся с жизненным циклом PV.
Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.

Критерии оценки:

0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### 1. Установка и запуск kind
> [Установка](https://kind.sigs.k8s.io/docs/user/quick-start#installation)

Запуск
~~~bash
kind create cluster
#export KUBECONFIG="$(kind get kubeconfig)"
~~~

### 2. Применение StatefulSet

Применим конфигурацию под именем [minio-statefulset](minio-statefulset.yaml)
~~~bash
kubectl apply -f minio-statefulset.yaml
~~~

В результате применения конфигурации должно произойти следующее:
- Запуститься под с MinIO
- Создаться PVC
- Динамически создаться PV на этом PVC с помощью дефолотного StorageClass

~~~bash
kubectl get pods
~~~
~~~
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          5m33s
~~~
~~~bash
kubectl get statefulsets
~~~
~~~
NAME    READY   AGE
minio   1/1     6m21s
~~~
~~~bash
kubectl get pv -o wide
~~~
~~~
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE    VOLUMEMODE
pvc-9513b6f7-faab-465f-8824-679d8d0135d5   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                7m2s   Filesystem
~~~
~~~bash
kubectl get pvc -o wide
~~~
~~~
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE     VOLUMEMODE
data-minio-0   Bound    pvc-9513b6f7-faab-465f-8824-679d8d0135d5   10Gi       RWO            standard       9m27s   Filesystem
~~~
~~~bash
kubectl describe pv/pvc-9513b6f7-faab-465f-8824-679d8d0135d5 
~~~
~~~
Name:              pvc-9513b6f7-faab-465f-8824-679d8d0135d5
Labels:            <none>
Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
Finalizers:        [kubernetes.io/pv-protection]
StorageClass:      standard
Status:            Bound
Claim:             default/data-minio-0
Reclaim Policy:    Delete
Access Modes:      RWO
VolumeMode:        Filesystem
Capacity:          10Gi
Node Affinity:     
  Required Terms:  
    Term 0:        kubernetes.io/hostname in [kind-control-plane]
Message:           
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /var/local-path-provisioner/pvc-9513b6f7-faab-465f-8824-679d8d0135d5_default_data-minio-0
    HostPathType:  DirectoryOrCreate
Events:            <none>
~~~

## 3. Применение Headless Service

Для того, чтобы наш StatefulSet был доступен изнутри кластера, создадим Headless Service.
Применим конфигурацию под именем [minio-headlessservice.yaml](kubernetes-volumes/minio-headlessservice.yaml)
~~~bash
kubectl apply -f minio-headlessservice.yaml
~~~
~~~bash
kubectl get svc
~~~
~~~
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP    94m
minio        ClusterIP   None         <none>        9000/TCP   25m
~~~
~~~bash
kubectl port-forward  service/minio 8080:9000 &
~~~

Проверка работы MinIO с помощью MinIO Client:
- Установка:
~~~bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc ~/bin/mc_cmd
mc_cmd ls
~~~

- Проверка:
~~~bash
mc_cmd config host add minio-local http://localhost:8080 minio minio123
~~~
~~~bash
mc_cmd mb minio-local/test-bucket
~~~
~~~bash
mc_cmd ls minio-local
~~~
~~~
[2023-01-16 00:14:58 MSK]     0B test-bucket/
~~~

## Задание со ⭐️

В конфигурации нашего StatefulSet данные указаны в открытом виде, что небезопасно.
Поместим данные в 'secrets' и настроим конфигурацию на их использование

"Зашифруем" для примера в base64
~~~yaml
...
        env:
        - name: MINIO_ACCESS_KEY
          value: "minio"
        - name: MINIO_SECRET_KEY
          value: "minio123"
...
~~~

~~~bash
echo -n minio | base64
bWluaW8=
echo -n minio123 | base64
bWluaW8xMjM=
~~~

Создадим [secrets-minio.yaml](kubernetes-volumes/secrets-minio.yaml)

Применим
~~~bash
kubectl apply -f .
~~~
~~~bash
kubectl get secret
~~~
~~~
NAME            TYPE     DATA   AGE
minio-secrets   Opaque   2      87s
~~~
~~~bash
kubectl describe secret minio-secrets
~~~
~~~
Name:         minio-secrets
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
minio-password:  8 bytes
minio-username:  5 bytes
~~~
~~~bash
kubectl get secret minio-secrets -o yaml
~~~
~~~yaml
apiVersion: v1
data:
  minio-password: bWluaW8xMjM=
  minio-username: bWluaW8=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"minio-password":"bWluaW8xMjM=","minio-username":"bWluaW8="},"kind":"Secret","metadata":{"annotations":{},"name":"minio-secrets","namespace":"default"},"type":"Opaque"}
  creationTimestamp: "2023-01-15T20:28:40Z"
  name: minio-secrets
  namespace: default
  resourceVersion: "3631"
  uid: 1ea50696-dab4-4e61-ba20-518911269308
type: Opaque
~~~
~~~bash
kubectl describe statefulsets minio
~~~
~~~
Name:               minio
Namespace:          default
CreationTimestamp:  Sun, 15 Jan 2023 22:53:36 +0300
Selector:           app=minio
Labels:             <none>
Annotations:        <none>
Replicas:           1 desired | 1 total
Update Strategy:    RollingUpdate
  Partition:        0
Pods Status:        1 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=minio
  Containers:
   minio:
    Image:      minio/minio:RELEASE.2019-07-10T00-34-56Z
    Port:       9000/TCP
    Host Port:  0/TCP
    Args:
      server
      /data
    Liveness:  http-get http://:9000/minio/health/live delay=120s timeout=1s period=20s #success=1 #failure=3
    Environment:
      MINIO_ACCESS_KEY:  <set to the key 'minio-username' in secret 'minio-secrets'>  Optional: false
      MINIO_SECRET_KEY:  <set to the key 'minio-password' in secret 'minio-secrets'>  Optional: false
    Mounts:
      /data from data (rw)
  Volumes:  <none>
Volume Claims:
  Name:          data
  StorageClass:  
  Labels:        <none>
  Annotations:   <none>
  Capacity:      10Gi
  Access Modes:  [ReadWriteOnce]
Events:          <none>
~~~

# **Полезное:**


</details>