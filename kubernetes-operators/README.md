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

~~~bash
kubectl apply -f deploy/cr.yml
~~~
~~~
secret/mysql-secrets created
error: resource mapping not found for name: "mysql-instance" namespace: "" from "deploy/cr.yml": no matches for kind "MySQL" in version "otus.homework/v1"
ensure CRDs are installed first
~~~

### 4. CustomResourceDefinition
>CustomResourceDefinition - это ресурс для определения других ресурсов (далее CRD)

Создадим CRD deploy/crd.yml
~~~yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.otus.homework # имя CRD должно иметь формат plural.group
spec:
  scope: Namespaced     # Данный CRD будет работать в рамках namespace
  group: otus.homework  # Группа, отражается в поле apiVersion CR
  versions:             # Список версий
    - name: v1
      served: true      # Будет ли обслуживаться API-сервером данная версия
      storage: true     # Фиксирует версию описания, которая будет сохраняться в etcd
  names:                # различные форматы имени объекта CR
    kind: MySQL         # kind CR
    plural: mysqls
    singular: mysql
    shortNames:
      - ms
~~~

Создадим CRD:
~~~bash
kubectl apply -f deploy/crd.yml
~~~
~~~
The CustomResourceDefinition "mysqls.otus.homework" is invalid: spec.versions[0].schema.openAPIV3Schema: Required value: schemas are required
~~~

Определим `schema.openAPIV3Schema`
~~~yaml
     schema:
        openAPIV3Schema:
          type: object
          properties:
            apiVersion:
              type: string # Тип данных поля ApiVersion
            kind:
              type: string # Тип данных поля kind
            metadata:
              type: object # Тип поля metadata
              properties: # Доступные параметры и их тип данных поля metadata (словарь)
                name:
                  type: string
~~~

~~~bash
kubectl apply -f deploy/crd.yml
~~~
~~~
customresourcedefinition.apiextensions.k8s.io/mysqls.otus.homework created
~~~

Создадим CR:
~~~bash
kubectl apply -f deploy/cr.yml
~~~
~~~
mysql.otus.homework/mysql-instance created
~~~

### 5. Взаимодействие с объектами CR CRD

~~~bash
kubectl get crd
~~~
~~~
NAME                   CREATED AT
mysqls.otus.homework   2023-02-04T17:49:29Z
~~~
~~~bash
kubectl get mysqls.otus.homework
~~~
~~~
NAME             AGE
mysql-instance   20h
~~~
~~~bash
kubectl describe mysqls.otus.homework mysql-instance
~~~
~~~
Name:         mysql-instance
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  otus.homework/v1
Kind:         MySQL
Metadata:
  Creation Timestamp:  2023-02-04T18:40:11Z
  Generation:          1
  Managed Fields:
    API Version:  otus.homework/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:database:
        f:image:
        f:password:
        f:storage_size:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2023-02-04T18:40:11Z
  Resource Version:  116579
  UID:               52875ae0-ba31-458e-8320-c66dc4d624ab
Spec:
  Database:      otus-database
  Image:         mysql:5.7
  Password:      otuspassword
  storage_size:  1Gi
Events:          <none>
~~~

### 6. Validation
На данный момент мы никак не описали схему нашего `CustomResource`. Объекты типа mysql могут иметь абсолютно произвольные поля, нам бы
хотелось этого избежать, для этого будем использовать `validation`. Для начала удалим CR mysql-instance:
~~~bash
kubectl delete mysqls.otus.homework mysql-instance
~~~
Добавим в спецификацию CRD ( `spec` ) параметры `validation`
~~~yaml
  validation:
    openAPIV3Schema:
      type: object
      properties:
        apiVersion:
          type: string
        kind:
          type: string
        metadata:
          type: object
          properties:
            name:
              type: string
        spec:
          type: object
          properties:
            image: 
              type: string
            database:
              type: string
            password:
              type: string
            storage_size:
              type: string
~~~

Пробуем применить CRD и CR
~~~bash
kubectl apply -f deploy/crd.yml
~~~
~~~
customresourcedefinition.apiextensions.k8s.io/mysqls.otus.homework created
~~~
~~~bash
kubectl apply -f deploy/cr.yml
~~~
~~~
mysql.otus.homework/mysql-instance created
~~~
Эту строку мы убрали ранее, при первых попытках применения `cr.yml` из [gist](https://gist.githubusercontent.com/Evgenikk/b365318d7e1934b41102ff13a7adadc8/raw/5177988a342953caf32d1e6e5ec4f51b2145b75c/bad_cr.yml)
~~~yaml
usless_data: "useless info"
~~~

### Задание по CRD:
Если сейчас из описания mysql убрать строчку из спецификации, то манифест будет принят API сервером. Для того, чтобы этого избежать, 
добавим описание обязательный полей в `CustomResourceDefinition`
> Примера в лекции нет, но все же есть в [Extend the Kubernetes API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)

Вносим соответствующие правки и проверяем:
~~~yaml
...
            spec:
              type: object
              required: ["image", "database", "password", "storage_size"]
...
~~~

~~~bash
kubectl delete -f deploy/crd.yml
kubectl apply -f deploy/crd.yml
~~~
### 8. Деплой оператора

Создадим в папке `./deploy`:
- [service-account.yml](service-account.yml)
- [role.yml](role.yml])
- [role-binding.yml](role-binding.yml])
- [deploy-operator.yml](deploy-operator.yml])

Применим манифесты:
~~~bash
kubectl apply -f ./deploy/service-account.yml
kubectl apply -f ./deploy/role.yml
kubectl apply -f ./deploy/role-binding.yml
kubectl apply -f ./deploy/deploy-operator.yml
kubectl apply -f ./deploy/cr.yml
~~~

### 9. Проверим, что все работает
Проверяем что появились pvc:
~~~bash
kubectl get pvc -A
~~~
~~~
NAMESPACE   NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
default     backup-mysql-instance-pvc   Bound    pvc-7fea0726-fcc0-4512-9d87-b1e1b7a55d51   1Gi        RWO            standard       41s
default     mysql-instance-pvc          Bound    pvc-831ddc3e-3549-41d0-b839-5756889f4f83   1Gi        RWO            standard       41s
~~~

Заполним базу созданного mysql-instance:
~~~bash
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
~~~
~~~bash
kubectl exec -it $MYSQLPOD -- mysql -u root -potuspassword -e "CREATE TABLE test ( id smallint \
  unsigned not null auto_increment, name varchar(20) not null, constraint pk_example primary key \
  (id) );" otus-database
~~~
~~~bash
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name ) VALUES ( \
  null, 'some data' );" otus-database
~~~
~~~bash
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "INSERT INTO test ( id, name ) VALUES ( \
  null, 'some data-2' );" otus-database
~~~

Посмотри содержимое таблицы:
~~~bash
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
~~~
~~~
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+
~~~

Удалим mysql-instance:
~~~bash
kubectl delete mysqls.otus.homework mysql-instance
~~~
~~~bash
kubectl get pv
~~~
~~~
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                               STORAGECLASS   REASON   AGE
backup-mysql-instance-pv                   1Gi        RWO            Retain           Available                                                               8m8s
pvc-7fea0726-fcc0-4512-9d87-b1e1b7a55d51   1Gi        RWO            Delete           Bound       default/backup-mysql-instance-pvc   standard                8m8s
~~~
показывает, что PV для mysql в статусе `Available`. а не `Bound`, а
~~~bash
kubectl get jobs.batch
~~~

показывает 
~~~
NAME                        COMPLETIONS   DURATION   AGE
backup-mysql-instance-job   1/1           5s         3m
~~~
~~~bash
kubectl describe jobs/backup-mysql-instance-job
~~~
~~~
Events:
  Type    Reason            Age    From            Message
  ----    ------            ----   ----            -------
  Normal  SuccessfulCreate  5m12s  job-controller  Created pod: backup-mysql-instance-job-ksv6t
  Normal  Completed         5m7s   job-controller  Job completed
~~~

Создадим заново `mysql-instance`:
~~~bash
kubectl apply -f deploy/cr.yml
~~~

Немного подождем и
~~~bash
export MYSQLPOD=$(kubectl get pods -l app=mysql-instance -o jsonpath="{.items[*].metadata.name}")
kubectl exec -it $MYSQLPOD -- mysql -potuspassword -e "select * from test;" otus-database
~~~
~~~
+----+-------------+
| id | name        |
+----+-------------+
|  1 | some data   |
|  2 | some data-2 |
+----+-------------+
~~~

Еще раз для PR
~~~bash
kubectl get jobs 
~~~
~~~
NAME                         COMPLETIONS   DURATION   AGE
backup-mysql-instance-job    1/1           5s         10m
restore-mysql-instance-job   1/1           52s        3m32s
~~~
~~~bash
kubectl describe jobs/restore-mysql-instance-job
~~~
~~~
...
Events:
  Type    Reason            Age    From            Message
  ----    ------            ----   ----            -------
  Normal  SuccessfulCreate  4m13s  job-controller  Created pod: restore-mysql-instance-job-nl9jr
  Normal  Completed         3m21s  job-controller  Job completed
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
