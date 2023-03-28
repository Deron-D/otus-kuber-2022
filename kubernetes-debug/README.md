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

- Установим бинарь `kubectl debug`:
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

<details>
    <summary>RELEASE_VERSION=1.0.0</summary>

> https://github.com/JamesTGrant/kubectl-debug
~~~bash
export RELEASE_VERSION=1.0.0
# linux x86_64
curl -Lo kubectl-debug https://github.com/JamesTGrant/kubectl-debug/releases/download/v$RELEASE_VERSION/kubectl-debug

# make the binary executable
chmod +x kubectl-debug
sudo mv kubectl-debug /usr/local/bin/
~~~

~~~bash
kubectl-debug --version
~~~
~~~
kubectl-debug version v0.2.0-rc.76+6508625e7f94c5
~~~
</details>

- Install the debug agent DaemonSet
~~~bash
curl -Lo strace/agent_daemonset.yml https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
~~~
~~~bash
kubectl apply -f strace/agent_daemonset.yml
~~~

- Пробуем повторно запустить `strace`
~~~bash
kubectl-debug --namespace default nginx                                            
~~~
~~~
container created, open tty...
nginx:~# strace -c -p1
strace: Process 1 attached
^Cstrace: Process 1 detached
~~~


## **Полезное:**


