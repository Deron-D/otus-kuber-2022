# **Лекция №22: CSI. Обзор подсистем хранения данных в Kubernetes // ДЗ**
> _Развертывание системы хранения данных_
<details>
  <summary>kubernetes-storage</summary>

## **Задание:**
Развертывание системы хранения данных

Цель:
В данном дз студенты научатся взаимодействовать с CSI. Изучат нюансы хранения данных для Stateful приложений.

Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.


Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

### План работы:

- Обычное домашнее задание
  - установить CSI-драйвер и протестировать функционал снапшотов
- Домашнее задание 🌟
  - развернуть k8s-кластер, к которому добавить хранилище на iSCSI

###  Обычное домашнее задание
- Создать StorageClass для CSI Host Path Driver
  - На своей тестовой машине его нужно установить самостоятельно
- Создать объект PVC c именем `storage-pvc`
- Создать объект Pod c именем `storage-pod`
- Хранилище нужно смонтировать в `/data`


## **Выполнено:**

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
NAME              STATUS   ROLES    AGE     VERSION
k8s-4otus-node1   Ready    <none>   4m10s   v1.24.6
~~~

### 2. Создадим StorageClass для CSI Host Path Driver

- установим CSI-драйвер
~~~bash
cd kubrernetes-csi/csi-driver-host-path/deploy/kubernetes-1.24
./deploy.sh
~~~

- Создадим объект PVC c именем `storage-pvc`
~~~bash
kubectl apply -f ./hw/storage-class.yaml -f ./hw/storage-pvc.yaml
kubectl get pvc
~~~
~~~
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                AGE
storage-pvc   Bound    pvc-8f0f5356-536b-46c6-94bd-eacfea52a566   1Gi        RWO            csi-hostpath-storageclass   2m10s
~~~

- Создадим объект Pod c именем `storage-pod`
~~~bash
kubectl apply -f ./hw/storage-pod.yaml 
~~~

### 3. Протестируем функционал снапшотов

~~~bash
kubectl exec storage-pod -- ls /data/
kubectl exec storage-pod -- touch /data/test.file
kubectl exec storage-pod -- ls /data/
~~~
~~~bash
kubectl apply -f hw/csi-snapshot.yaml
~~~
~~~
volumesnapshot.snapshot.storage.k8s.io/csi-snapshot created
~~~

- Удаляем pod,pvc,pv
~~~bash
kubectl delete -f ./hw/storage-pvc.yaml -f ./hw/storage-pod.yaml  
~~~
~~~
persistentvolumeclaim "storage-pvc" deleted
pod "storage-pod" deleted
~~~

- Создаем pvc из снапшота
~~~bash
kubectl apply -f hw/csi-restore.yaml
~~~

- Заново создадим объект Pod c именем `storage-pod`
~~~bash
kubectl apply -f ./hw/storage-pod.yaml 
~~~

- Проверяем наличие файла
~~~bash
kubectl exec storage-pod -- ls /data/
~~~
~~~
test.file
~~~

## **Полезное:**


