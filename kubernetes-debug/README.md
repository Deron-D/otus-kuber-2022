# **Лекция №23: Диагностика и отладка кластера и приложений в нем // ДЗ**
> _Отладка и тестирование в Kubernetes_
<details>
  <summary>kubernetes-debug</summary>

## **Задание:**
Проведение диагностики состояния кластера, знакомство с инструментами для диагностики

Цель:
В данном дз студенты научатся пользоваться инструментами для отладки кластера kubernetes. Такими как strace, kubectl-debug, iptables-tailer.

Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.

Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

### Выполнено:

### Подготовка

Т.к. ДЗ явно c `A LOT OF DEPRECATED` ссылок, инструментов, манифестов & etc,  
- запускаем кластер с версией кубера `1.19.6`
~~~bash
kind create cluster --config kind-config.yaml
~~~ 

- установим Сalico
> https://docs.tigera.io/calico/latest/getting-started/kubernetes/minikube

~~~bash
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
~~~

- проверим успешный запуск `calico`
~~~bash
kubectl -n kube-system get pods -l k8s-app="calico-node" -w
~~~

### 1. Кubectl debug / strace

- воспроизводим проблему c `kubectl debug`:
~~~bash
kubectl run nginx --image=nginx
~~~
~~~bash
kubectl debug nginx -it --image=nicolaka/netshoot --copy-to=debug-nginx
~~~
~~~
debug-nginx# strace -c -p1
strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted
~~~
т.к. отсутствует соответствующий capability `SYS_PTRACE`

В исходном же коде `kubectl-debug` присутствует инструкция `CapAdd:      strslice.StrSlice([]string{"SYS_PTRACE", "SYS_ADMIN"}),`  
> https://github.com/aylei/kubectl-debug/blob/5364033c9ff968c956e2db896a9f1a57f034ed86/pkg/agent/runtime.go#L152

- Установим бинарь `kubectl-debug`:
> https://github.com/aylei/kubectl-debug/releases

~~~bash
# linux x86_64
curl -Lo kubectl-debug.tar.gz https://github.com/aylei/kubectl-debug/releases/download/v0.1.1/kubectl-debug_0.1.1_linux_amd64.tar.gz
tar -zxvf kubectl-debug.tar.gz kubectl-debug
sudo mv kubectl-debug /usr/local/bin/
~~~
~~~bash
kubectl-debug --version
~~~
~~~
debug version v0.0.0-master+$Format:%h$
~~~

- Install the debug agent DaemonSet
~~~bash
curl -Lo strace/agent_daemonset.yml https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
~~~
~~~bash
kubectl apply -f strace/agent_daemonset.yml
~~~

- Пробуем повторно запустить `strace`
~~~bash
kubectl delete pod nginx
kubectl delete pod debug-nginx
kubectl run nginx --image=nginx
~~~
~~~bash
kubectl-debug --namespace default nginx                                            
~~~
~~~
container created, open tty...
nginx:~# strace -c -p1
strace: Process 1 attached
^Cstrace: Process 1 detached
~~~

### 2. Iptables-tailer

> https://github.com/box/kube-iptables-tailer

Один из полезных инструментов - это `iptables-tailer`. 
Он предназначен для того, чтобы выводить информацию об отброшенных iptables пакетах в журнал событий Kubernetes 
( `kubectl get events` ).
Основной кейс - сообщить разработчикам сервисов о проблемах с NetworkPolicy.

> https://github.com/piontec/netperf-operator

Для нашего задания в качестве тестового приложения возьмем `netperf-operator`
Это Kubernetes-оператор, который позволяет запускать тесты пропускной способности сети между нодами кластера.
Сам проект - не очень production-grade, но иногда выручает.

Установим манифесты для запуска оператора в кластере (лежат в папке deploy в репозитории проекта):
Custom Resource Definition - схема манифестов для запуска тестов Netperf
RBAC - политики и разрешения для нашего оператора
И сам оператор, который будет следить за появлением ресурсов с `Kind: Netperf` и запускать поды с клиентом и сервером утилиты
NetPerf
~~~bash
kubectl apply -f ./kit/deploy/crd.yaml
~~~
~~~bash
kubectl apply -f ./kit/deploy/rbac.yaml
~~~
~~~bash
kubectl apply -f ./kit/deploy/operator.yaml
~~~

Теперь можно запустить наш первый тест, применив манифест `cr.yaml` из папки `deploy`
~~~bash
kubectl apply -f ./kit/deploy/cr.yaml
~~~
~~~bash
kubectl describe netperf.app.example.com/example
~~~
~~~
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-03-29T19:52:14Z
  Generation:          4
  Managed Fields:
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:clientNode:
        f:serverNode:
    Manager:      kubectl-client-side-apply
    Operation:    Update
    Time:         2023-03-29T19:52:14Z
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:clientPod:
        f:serverPod:
        f:speedBitsPerSec:
        f:status:
    Manager:         netperf-operator
    Operation:       Update
    Time:            2023-03-29T19:53:53Z
  Resource Version:  5714
  Self Link:         /apis/app.example.com/v1alpha1/namespaces/default/netperfs/example
  UID:               db676f41-c225-47a2-b965-d0d9dd1c735e
Spec:
  Client Node:  kind-worker2
  Server Node:  kind-worker
Status:
  Client Pod:          netperf-client-d0d9dd1c735e
  Server Pod:          netperf-server-d0d9dd1c735e
  Speed Bits Per Sec:  6333.91
  Status:              Done
Events:                <none>
~~~

Теперь можно добавить сетевую политику для Calico, чтобы ограничить
доступ к подам Netperf и включить логирование в iptables
~~~bash
kubectl apply -f ./kit/netperf-calico-policy.yaml 
~~~

Перезапускаем наш тест, применив манифест `cr.yaml` из папки `deploy`
~~~bash
kubectl delete -f ./kit/deploy/cr.yaml 
kubectl apply -f ./kit/deploy/cr.yaml
~~~
~~~bash
kubectl describe netperf.app.example.com/example
~~~
~~~
...
Spec:
  Client Node:  kind-worker2
  Server Node:  kind-worker
Status:
  Client Pod:          netperf-client-148ac1cbd2ee
  Server Pod:          netperf-server-148ac1cbd2ee
  Speed Bits Per Sec:  0
  Status:              Started test
Events:                <none>
~~~
Теперь, если повторно запустить тест, мы увидим, что тест висит в состоянии `Started`. 
В нашей сетевой политике есть ошибка.

Проверим, что в логах ноды Kubernetes появились сообщения об отброшенных пакетах:
Подключимся к "ноде" по SSH:
~~~bash
docker exec -it kind-worker2 sh
~~~

- `iptables-legacy --list -nv | grep DROP` - ненулевые счетчики дропов 
~~~
35  2100 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:He8TRqGPuUw3VGwk */
~~~

- `iptables-legacy  --list -nv | grep LOG` - счетчики с действием логирования ненулевые
~~~
    0     0 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:XWC9Bycp2Xf7yVk1 */ LOG flags 0 level 5 prefix "calico-packet: "
   42  2520 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:B30DykF1ntLW86eD */ LOG flags 0 level 5 prefix "calico-packet: "
~~~
~~~
journalctl -k | grep calico
~~~
~~~
 journalctl -k              
-- No entries --
~~~
как-то негусто, идем дальше :)

Попробуем запустить iptables-tailer используя манифест из репозитория проекта

- Install the kube-iptables-tailer DaemonSet
~~~bash
curl -Lo kit/iptables-tailer-daemonset.yaml https://raw.githubusercontent.com/box/kube-iptables-tailer/master/demo/daemonset.yaml
~~~
~~~bash
kubectl apply -f kit/iptables-tailer-daemonset.yaml
~~~

Проверим логи запущенного пода (daemonsets)
~~~bash
kubectl describe daemonsets.apps -n kube-system 
~~~
~~~
...
Events:
  Type     Reason            Age   From                  Message
  ----     ------            ----  ----                  -------
  Warning  FailedCreate      31m   daemonset-controller  Error creating: pods "kube-iptables-tailer-" is forbidden: error looking up service account kube-system/kube-iptables-tailer: serviceaccount "kube-iptables-tailer" not found

...
~~~

- Создаем `./kit/sa-kube-iptables-tailer.yaml` и применяем
~~~bash
kubectl apply -f ./kit/sa-kube-iptables-tailer.yaml
kubectl delete -f ./kit/iptables-tailer-daemonset.yaml
kubectl apply -f ./kit/iptables-tailer-daemonset.yaml
~~~

## **Полезное:**


