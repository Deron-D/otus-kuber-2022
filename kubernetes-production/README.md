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

### 1. Создание нод для кластера
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
+----------------------+----------------+---------------+---------+----------------+-------------+
|          ID          |      NAME      |    ZONE ID    | STATUS  |  EXTERNAL IP   | INTERNAL IP |
+----------------------+----------------+---------------+---------+----------------+-------------+
| ef33erjmugn7m1fhovvp | worker-node-03 | ru-central1-c | RUNNING | 51.250.39.248  | 10.130.0.25 |
| ef35dcb9tmbackr7dies | worker-node-02 | ru-central1-c | RUNNING | 84.201.171.59  | 10.130.0.7  |
| ef3bv650omqcfa8cunn8 | master-node    | ru-central1-c | RUNNING | 84.201.170.27  | 10.130.0.32 |
| ef3ipbvjim8uumov3e1s | worker-node-01 | ru-central1-c | RUNNING | 84.201.170.250 | 10.130.0.22 |
+----------------------+----------------+---------------+---------+----------------+-------------+
~~~

- Подготовка машин
Отключим на машинах swap

~~~bash
ssh  yc-user@84.201.170.27 sudo swapoff -a
~~~
~~~bash
ssh  yc-user@84.201.170.250 sudo swapoff -a
~~~
~~~bash
ssh  yc-user@84.201.171.59 sudo swapoff -a
~~~
~~~bash
ssh  yc-user@51.250.39.248 sudo swapoff -a
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

