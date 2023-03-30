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

~~~bash
minikube start
~~~

### 1. Кubectl debug / strace

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
curl -Lo strace/agent_daemonset.yml https://raw.githubusercontent.com/aylei/kubectl-debug/dd7e4965e4ae5c4f53e6cf9fd17acc964274ca5c/scripts/agent_daemonset.yml
~~~
~~~bash
kubectl apply -f strace/agent_daemonset.yml
~~~
~~~console
error: resource mapping not found for name: "debug-agent" namespace: "" from "strace/agent_daemonset.yml": no matches for kind "DaemonSet" in version "extensions/v1beta1"
ensure CRDs are installed first
~~~

- правим `apiVersion: apps/v1` и перезапускаем установку
~~~bash
kubectl apply -f strace/agent_daemonset.yml
~~~

- воспроизводим проблему c `kubectl-debug`:
~~~bash
kubectl run nginx --image=nginx
~~~

~~~bash
kubectl-debug nginx --agentless=false --port-forward=true
~~~
~~~console
...
starting debug container...
container created, open tty...
nginx:~# ps
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   29 101       0:00 nginx: worker process
   30 101       0:00 nginx: worker process
   31 101       0:00 nginx: worker process
   32 101       0:00 nginx: worker process
   33 101       0:00 nginx: worker process
   34 101       0:00 nginx: worker process
   35 101       0:00 nginx: worker process
   36 101       0:00 nginx: worker process
   37 101       0:00 nginx: worker process
   38 101       0:00 nginx: worker process
   39 101       0:00 nginx: worker process
   40 101       0:00 nginx: worker process
   41 root      0:00 bash
   47 root      0:00 ps
nginx:~#  strace -c -p1
strace: attach: ptrace(PTRACE_SEIZE, 1): Operation not permitted
nginx:~# 
~~~
т.к. отсутствует соответствующий capability `SYS_PTRACE`

- Заходим на "ноду" и проверяем `docker capabilities`:
~~~bash
minikube ssh
~~~
~~~console
docker@minikube:~$ docker ps | grep debug-agent
7ae2882f28c1   aylei/debug-agent      "/bin/debug-agent"       2 minutes ago   Up 2 minutes                      k8s_debug-agent_debug-agent-jmr25_default_610d788a-6cf4-4dbb-89da-db67276fa14f_0
447a3f66dfb8   k8s.gcr.io/pause:3.6   "/pause"                 2 minutes ago   Up 2 minutes                      k8s_POD_debug-agent-jmr25_default_610d788a-6cf4-4dbb-89da-db67276fa14f_0
docker@minikube:~$ docker inspect 7ae2882f28c1 | grep CapAdd                     
            "CapAdd": null,
~~~

В исходном же коде `kubectl-debug` присутствует инструкция `CapAdd:      strslice.StrSlice([]string{"SYS_PTRACE", "SYS_ADMIN"}),`
> https://github.com/aylei/kubectl-debug/blob/5364033c9ff968c956e2db896a9f1a57f034ed86/pkg/agent/runtime.go#L152

- Удаляем `DaemonSet` и деплоим более "свежую" версию `debug-agent`
~~~bash
kubectl delete -f strace/agent_daemonset.yml
#curl -Lo strace/agent_daemonset.yml https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
kubectl apply -f https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
~~~

- Пробуем повторно запустить `strace`
~~~bash
kubectl-debug nginx --agentless=false --port-forward=true
~~~
~~~console
container created, open tty...
nginx:~# strace -c -p1
strace: Process 1 attached
^Cstrace: Process 1 detached
~~~

#### Ура!!  Мы успешно приаттачились к мастер процессу nginx ))

- Сносим локальный кластер
~~~bash
minikube delete
~~~

### 2. Iptables-tailer

Т.к. ДЗ явно c `A LOT OF DEPRECATED` ссылок, инструментов, манифестов & etc,
- запускаем кластер с версией кубера `1.19.6`
~~~bash
kind create cluster --config kind-config.yaml
~~~ 

- установим Сalico
> https://alexbrand.dev/post/creating-a-kind-cluster-with-calico-networking/

~~~bash
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
~~~

- проверим успешный запуск `calico`
~~~bash
kubectl -n kube-system get pods -l k8s-app="calico-node" -w
~~~
~~~console
calico-node-xsgnc   1/1     Running           0          61s
calico-node-b8pk6   0/1     Running           0          64s
calico-node-42cnj   0/1     Running           0          65s
calico-node-b8pk6   1/1     Running           0          70s
calico-node-42cnj   1/1     Running           0          77s
~~~

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

~~~bash
kubectl get pods -l name=netperf-operator 
~~~
~~~console
NAME                                READY   STATUS    RESTARTS   AGE
netperf-operator-55b49546b5-psgqw   1/1     Running   0          103s
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
~~~console
35  2100 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:He8TRqGPuUw3VGwk */
~~~

- `iptables-legacy  --list -nv | grep LOG` - счетчики с действием логирования ненулевые
~~~console
    0     0 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:XWC9Bycp2Xf7yVk1 */ LOG flags 0 level 5 prefix "calico-packet: "
   42  2520 LOG        all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:B30DykF1ntLW86eD */ LOG flags 0 level 5 prefix "calico-packet: "
~~~
~~~console
journalctl -k | grep calico
~~~
~~~console
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
kubectl describe daemonset kube-iptables-tailer -n kube-system 
~~~
~~~
...
Events:
  Type    Reason            Age   From                  Message
  ----    ------            ----  ----                  -------
  Normal  SuccessfulCreate  64s   daemonset-controller  Created pod: kube-iptables-tailer-5tcrx
  Normal  SuccessfulCreate  64s   daemonset-controller  Created pod: kube-iptables-tailer-ttzzb
...
~~~

Вроде всё норм. Идем дальше )

- Опять перезапускаем netperf
~~~bash
kubectl delete -f ./kit/deploy/cr.yaml 
kubectl apply -f ./kit/deploy/cr.yaml
~~~

- Проверим логи пода `iptables-tailer` и события в кластере ( `kubectl get events -A` )
~~~bash
kubectl get events -A | grep iptables-tailer
kubectl logs daemonsets/kube-iptables-tailer -n kube-system
~~~
~~~console
Found 2 pods, using pod/kube-iptables-tailer-5tcrx
E0330 09:19:28.588276       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 09:19:33.587720       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 09:19:38.587754       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 09:19:43.587809       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
~~~

И опять, мы почти ничего не увидим. А жаль…

В манифесте из репозитория kube-iptables-tailer настроен так,
что ищет текстовый файл с логами iptables в определенной папке.
Но во многих современных Linux-дистрибутивах логи по умолчанию не
будут туда отгружаться, а будут складываться в журнал systemd .
К счастью, iptables-tailer умеет работать с systemd journal - для
этого надо передать ему параметр JOURNAL_DIRECTORY б указав каталог
с файлами журнала (по умолчанию, /var/log/journal ). 

Зададим его в манифесте.

Так же, в манифесте с DaemonSet была переменная, которая задавала префикс
для выбора логов iptables. В ней указан префикс `calico-drop` ,
а по умолчанию Calico логирует пакеты с префиксом `calico-packet`

- Правим `iptables-tailer-daemonset.yaml` и передеплоим
~~~bash
kubectl delete -f kit/iptables-tailer-daemonset.yaml
kubectl apply -f kit/iptables-tailer-daemonset.yaml
~~~
~~~bash
kubectl logs daemonsets/kube-iptables-tailer -n kube-system
~~~
~~~
E0330 10:14:58.990117       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:03.982659       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:08.982725       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:13.982681       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:18.982661       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:23.982752       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
E0330 10:15:28.999287       1 watcher.go:36] Failed to open file: name=/var/log/iptables.log, error=open /var/log/iptables.log: no such file or directory
~~~

Нет прогресса. Идем дальше по `easy way`
~~~bash
curl -Lo kit/iptables-tailer.yaml https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-03/Debugging/iptables-tailer.yaml
~~~
~~~bash
kubectl delete -f kit/iptables-tailer-daemonset.yaml
~~~

~~~bash
kubectl delete -f kit/iptables-tailer.yaml
kubectl apply -f kit/iptables-tailer.yaml
~~~

- Опять перезапускаем netperf
~~~bash
kubectl delete -f ./kit/deploy/cr.yaml 
kubectl apply -f ./kit/deploy/cr.yaml
kubectl describe netperf.app.example.com/example
~~~
~~~console
...
Status:
  Client Pod:          netperf-client-d0d9dd1c735e
  Server Pod:          netperf-server-d0d9dd1c735e
  Speed Bits Per Sec:  6333.91
  Status:              Done
Events:                <none>
~~~

- Проверяем
~~~bash
kubectl describe pod/netperf-client-4e4d7f89dffd 
~~~
~~~console
...
Events:
  Type     Reason      Age                    From                  Message
  ----     ------      ----                   ----                  -------
  Normal   Scheduled   57m                    default-scheduler     Successfully assigned default/netperf-client-4e4d7f89dffd to kind-worker2
  Normal   Created     47m (x5 over 57m)      kubelet               Created container netperf-client-4e4d7f89dffd
  Normal   Started     47m (x5 over 57m)      kubelet               Started container netperf-client-4e4d7f89dffd
  Warning  BackOff     6m58s (x123 over 52m)  kubelet               Back-off restarting failed container
  Normal   Pulled      2m5s (x12 over 57m)    kubelet               Container image "tailoredcloud/netperf:v2.7" already present on machine
  Warning  PacketDrop  2m5s (x11 over 55m)    kube-iptables-tailer  Packet dropped when sending traffic to netperf-server-4e4d7f89dffd (10.244.45.219)
...  
~~~


## **Полезное:**


