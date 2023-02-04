# **Лекция №8: Custom Resource Definitions. Operators // ДЗ**
> _Custom Resource Definitions. Operators_
<details>
  <summary>kubernetes-operators</summary>

## **Задание:**
Описание собственного CRD, использование open-source операторов
Цель:

В данном дз студенты разберутся что такое CRD и как их использовать. Создадут собственный Custom Resource Refinition и собственный Custom Recource. Так же студенты напишут свой собственный оператор для взаимодействия с Mysql сервером в рамках кластера kubernetes.

Описание/Пошаговая инструкция выполнения домашнего задания:

Все действия описаны в методическом указании.

Критерии оценки:

0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### 1. Подготовка

Запустим kubernetes кластер в minikube/создадим поддиректорию `deploy`
~~~bash
mkdir -p ./deploy
minikube start
~~~

### 2. Что должно быть в описании MySQL

Для создания pod с MySQL оператору понадобится знать:
-  Какой образ с MySQL использовать
-  Какую db создать
-  Какой пароль задать для доступа к MySQL

### 3. CustomResource

Создадим CustomResource `deploy/cr.yml` со следующим содержимым:
~~~yaml
apiVersion: otus.homework/v1
kind: MySQL
metadata:
  name: mysql-instance
spec:
  image: mysql:5.7
  database: otus-database
  password: # otuspassword  # Так делать не нужно, следует использовать secret
    valueFrom:
      secretKeyRef:
        name: mysql-secrets
        key: mysql-password
  storage_size: 1Gi
usless_data: "useless info"
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secrets
type: Opaque
data:
  mysql-password: b3R1c3Bhc3N3b3Jk
~~~

~~~bash
echo -n otuspassword | base64
~~~


# **Полезное:**

Start
~~~bash
yc managed-kubernetes cluster start k8s-4otus
~~~

Stop
~~~bash
yc managed-kubernetes cluster stop k8s-4otus
~~~
</details>
