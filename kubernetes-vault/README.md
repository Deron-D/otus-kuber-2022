# **Лекция №18: Хранилище секретов для приложений. Vault // ДЗ**
> _Hashicorp Vault + K8sHashicorp Vault + K_
<details>
  <summary>kubernetes-vault</summary>

## **Задание:**
Устанавливаем и настраиваем Vault для нужд платформенной команды и команд разработки

Цель:
В данном домашнем задании студенты установят Hashicrop Vault в кластер kubernetes. Научатся управлять секретами и использовать их в кластере.


Описание/Пошаговая инструкция выполнения домашнего задания:
Все действия описаны в методическом указании.


Критерии оценки:
0 б. - задание не выполнено
1 б. - задание выполнено
2 б. - выполнены все дополнительные задания

---

## **Выполнено:**

### План работ
В ходе работы мы: 
- установим кластер vault в kubernetes
- научимся создавать секреты и политики
- настроим авторизацию в vault через kubernetes sa
- сделаем под с контейнером nginx, в который прокинем
- секреты из vault через consul-template

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
NAME              STATUS   ROLES    AGE    VERSION
k8s-4otus-node1   Ready    <none>   105s   v1.24.6
k8s-4otus-node2   Ready    <none>   108s   v1.24.6
k8s-4otus-node3   Ready    <none>   98s    v1.24.6
~~~

### 2. Инсталляция hashicorp vault HA в k8s
 
- "склонируем" репозиторий `consul` (необходимо минимум 3 ноды)
~~~bash
#git clone https://github.com/hashicorp/consul-helm.git
git submodule add https://github.com/hashicorp/consul-helm.git kubernetes-vault/consul-helm
helm install consul consul-helm
~~~
~~~bash
kubectl get pods
~~~
~~~
NAME                     READY   STATUS    RESTARTS   AGE
consul-consul-d2hcw      1/1     Running   0          3m22s
consul-consul-g6fdr      1/1     Running   0          3m22s
consul-consul-mmqs2      1/1     Running   0          3m22s
consul-consul-server-0   1/1     Running   0          3m22s
consul-consul-server-1   1/1     Running   0          3m21s
consul-consul-server-2   1/1     Running   0          3m21s
~~~
~~~bash
kubectl get pvc
~~~
~~~
NAME                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
data-default-consul-consul-server-0   Bound    pvc-3c130f13-e89c-4df6-9850-9f2a01d25415   10Gi       RWO            yc-network-hdd   27s
data-default-consul-consul-server-1   Bound    pvc-87edc4b9-0711-4a11-a3b4-d1861a5a52f7   10Gi       RWO            yc-network-hdd   27s
data-default-consul-consul-server-2   Bound    pvc-7c3392f9-8867-4fae-a8b9-c175b111b918   10Gi       RWO            yc-network-hdd   27s
~~~

- "склонируем" репозиторий `vault`
~~~bash
#git clone https://github.com/hashicorp/vault-helm.git
git submodule add https://github.com/hashicorp/vault-helm.git  kubernetes-vault/vault-helm
~~~
- Отредактируем параметры установки в `values.yaml`
~~~yaml
standalone:
  enabled: false
....
ha:
  enabled: true
...
ui:
  enabled: true
  serviceType: "ClusterIP"
~~~

- Установим `vault`
~~~bash
helm install vault vault-helm -f ./vault.values.yaml
helm status vault
~~~
~~~README.md
NAME: vault
LAST DEPLOYED: Sat Mar 25 19:38:46 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
~~~
~~~bash
kubectl logs vault-0
~~~
~~~
==> Vault server configuration:

             Api Address: http://10.112.130.8:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
              Go Version: go1.19.2
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
               Log Level: info
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.12.1, built 2022-10-27T12:32:05Z
             Version Sha: e34f8a14fb7a88af4640b09f3ddbb5646b946d9c

2023-03-25T16:39:03.722Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2023-03-25T16:39:03.722Z [WARN]  storage.consul: appending trailing forward slash to path
2023-03-25T16:39:03.760Z [INFO]  core: Initializing version history cache for core
==> Vault server started! Log data will stream in below:

2023-03-25T16:39:09.893Z [INFO]  core: security barrier not initialized
2023-03-25T16:39:09.896Z [INFO]  core: seal configuration missing, not initialized
2023-03-25T16:39:14.897Z [INFO]  core: security barrier not initialized
2023-03-25T16:39:14.900Z [INFO]  core: seal configuration missing, not initialized
~~~

- проведем инициализацию через любой под vault'а
~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Unseal Key 1: zWPVT9d4JYVWqIJdwr+DeqE8gi3pl2V2aa4hsvT1aQo=

Initial Root Token: hvs.7l6Cuei6wjRMIo6eVjvZILxL

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

- поэкспериментируем с разными значениями `--key-shares` `--key-threshold`

> -key-shares (int: 5) - Number of key shares to split the generated master key into. This is the number of "unseal keys" to generate. This is aliased as -n.

> -key-threshold (int: 3) - Number of key shares required to reconstruct the root key. This must be less than or equal to -key-shares. This is aliased as -t.


~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=2 --key-threshold=1
~~~
~~~
Error initializing: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/init
Code: 400. Errors:

* invalid seal configuration: threshold must be greater than one for multiple shares
command terminated with exit code 2
~~~

~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=5 --key-threshold=3
~~~~
~~~
Unseal Key 1: AkbLwOGYPGVn36KtvOL9/HN75G6ZPRBbq1nVNJwMy+it
Unseal Key 2: kTqC+TgNCTdMfxcSbGTFjWQOaOJRET06SMFgsO0+tbq8
Unseal Key 3: h+vzPyk33QdCLWn0rcmUnyZ8aF/tAM/LFFyt6tVDpGva
Unseal Key 4: yfzrshFsPw5RFqub/gJ4Nl1I9hGEFFc4WAPujtAmQFcS
Unseal Key 5: 77d9+KICIBVSJ76vaDaj1pIlj7xZwdGyTIe2/tJQEItZ

Initial Root Token: hvs.pyYm3cuxvd5a50u6GPDt3Jrg

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Error initializing: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/init
Code: 400. Errors:

* Vault is already initialized
  command terminated with exit code 2
~~~

Переустанавливаем:
~~~bash
#helm uninstall vault
#helm uninstall consul
#kubectl delete pvc data-default-consul-consul-server-{0,1,2}

helm install consul consul-helm
helm install vault vault-helm -f ./vault.values.yaml
kubectl get pvc
kubectl get pods -w
~~~
~~~bash
kubectl exec -it vault-0 -- vault operator init --key-shares=1 --key-threshold=1
~~~
~~~
Unseal Key 1: ZKRQnOBdF3wW3OLKzUqoOJr9K6d+2ODE1xgjJVpyzhM=

Initial Root Token: hvs.BColGpGYMMuT09AgDOqpPTU5

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
~~~

- Проверим состояние vault'а
~~~bash
kubectl exec -it vault-0 -- vault status
~~~
~~~README.md
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.12.1
Build Date         2022-10-27T12:32:05Z
Storage Type       consul
HA Enabled         true
command terminated with exit code 2
~~~

### Распечатаем vault
- Обратим внимание на переменные окружения в подах
~~~bash
kubectl exec vault-0 -- env | grep VAULT_ADDR
~~~
~~~
VAULT_ADDR=http://127.0.0.1:8200
~~~
- Распечатать нужно каждый под
~~~bash
kubectl exec -it vault-0 -- vault operator unseal 'ZKRQnOBdF3wW3OLKzUqoOJr9K6d+2ODE1xgjJVpyzhM='
~~~
~~~
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.12.1
Build Date      2022-10-27T12:32:05Z
Storage Type    consul
Cluster Name    vault-cluster-7d190848
Cluster ID      e9174465-dae6-7d01-f363-7f716f471226
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2023-03-27T18:47:18.964964745Z
~~~

~~~bash
kubectl exec -it vault-1 -- vault operator unseal 'ZKRQnOBdF3wW3OLKzUqoOJr9K6d+2ODE1xgjJVpyzhM='
~~~
~~~
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7d190848
Cluster ID             e9174465-dae6-7d01-f363-7f716f471226
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.112.128.9:8200
~~~
~~~bash
kubectl exec -it vault-2 -- vault operator unseal 'ZKRQnOBdF3wW3OLKzUqoOJr9K6d+2ODE1xgjJVpyzhM='
~~~
~~~
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7d190848
Cluster ID             e9174465-dae6-7d01-f363-7f716f471226
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.112.128.9:8200

~~~

- Посмотрим список доступных авторизаций
~~~bash
kubectl exec -it vault-0 -- vault auth list
~~~

- получим ошибку
~~~
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 403. Errors:

* permission denied
command terminated with exit code 2
~~~

- Залогинимся в vault (у нас есть root token)
~~~bash
kubectl exec -it vault-0 -- vault login
~~~
~~~README.md
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.BColGpGYMMuT09AgDOqpPTU5
token_accessor       A8r6a0UHpgnB98tDaCvZQ9N6
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
~~~

- повторно запросим список авторизаций
~~~bash
kubectl exec -it vault-0 -- vault auth list
~~~
~~~README.md
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_9dbd3454    token based credentials    n/a
~~~

- Заведем секреты
~~~bash
kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
~~~
~~~
Success! Enabled the kv secrets engine at: otus/
~~~
~~~bash
kubectl exec -it vault-0 -- vault secrets list --detailed
~~~
~~~README.md
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID                                    Version    Running Version          Running SHA256    Deprecation Status
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----                                    -------    ---------------          --------------    ------------------
cubbyhole/    cubbyhole    cubbyhole_2052cf4d    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           c22286d8-ed1e-7086-6163-ade49c38174b    n/a        v1.12.1+builtin.vault    n/a               n/a
identity/     identity     identity_b5fd4b87     system         system     false             replicated     false        false                      map[]      identity store                                             e5f1e0f8-41e2-7078-63d4-4da1273c14b1    n/a        v1.12.1+builtin.vault    n/a               n/a
otus/         kv           kv_12f81852           system         system     false             replicated     false        false                      map[]      n/a                                                        9ff1a4c6-53c1-68cd-9094-eeb947890411    n/a        v0.13.0+builtin          n/a               supported
sys/          system       system_3ace5900       n/a            n/a        false             replicated     true         false   
~~~

~~~bash
kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
~~~
~~~
Success! Data written to: otus/otus-ro/config
~~~
~~~bash
kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
~~~
~~~
Success! Data written to: otus/otus-rw/config
~~~
~~~bash
kubectl exec -it vault-0 -- vault read otus/otus-ro/config
~~~
~~~README.md
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus
~~~
~~~bash
kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
~~~
~~~README.md
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus
~~~

- Включим авторизацию через k8s
~~~bash
kubectl exec -it vault-0 -- vault auth enable kubernetes
~~~
~~~
Success! Enabled kubernetes auth method at: kubernetes/
~~~
~~~bash
kubectl exec -it vault-0 -- vault auth list
~~~
~~~README.md
Path           Type          Accessor                    Description                Version
----           ----          --------                    -----------                -------
kubernetes/    kubernetes    auth_kubernetes_1fefb414    n/a                        n/a
token/         token         auth_token_6ed55b3f         token based credentials    n/a
~~~

- Создадим yaml для `ClusterRoleBinding`
~~~bash
tee vault-auth-service-account.yml <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: default
EOF
~~~

- Создадим Service Account vault-auth и применим ClusterRoleBinding
~~~bash
# Create a service account, 'vault-auth'
kubectl create serviceaccount vault-auth
~~~
~~~
serviceaccount/vault-auth created
~~~
~~~bash
# Update the 'vault-auth' service account
kubectl apply -f vault-auth-service-account.yml
~~~
~~~
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRoleBinding
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created
~~~

- Подготовим переменные для записи в конфиг кубер авторизации
~~~bash
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
### alternative way
export K8S_HOST=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/https/ {print $NF}' | sed 's/\x1b[[0-9;]*m//g')
~~~

~~~bash
echo $VAULT_SA_NAME
~~~
~~~
vault-auth-token-9wdrd
~~~
~~~bash
echo $SA_JWT_TOKEN
~~~
~~~
eyJhbGciOiJSUzI1NiIsImtpZCI6IkFybDY5VDF0UThrcTkzbFplSFppWnBtUG0tUVE4d00wOEp2VEZ5UDFGeUUifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InZhdWx0LWF1dGgtdG9rZW4tOXdkcmQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoidmF1bHQtYXV0aCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjI5ZTNhMmQ0LTE3OGEtNGNiNi1hODJlLTc4NGZjNDk4NDQxYyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OnZhdWx0LWF1dGgifQ.wpcCKFsXTOnfRzt2cDpTOZNys6MJqKbofOYdlH_DB9hBAm_zo3mOniKuQl3AJaqEKb396ruzj2JFOWafqFUpx-ncbIq6Ci-pZ7eLFgwUnzrdvgWkQtzqM3fTUpsh7EIWb8rQgaiqYDJOXoGSC2x2ehBy8r8R8TCzWBKo5MZTwpkKZwb1EairFo32-ZZPK3wylR_qC4eZL74ulOEafZasFqrpYwf8LMCOPaxFo7JRBjQhQocf7NmT7Se5E6vgGt1mZjUwcyU-S6wm3sMxyauvWnGwyaCJTlaSJDZxWClqVVUK2gPjc_g8vEXjzIQd9lDiE6Ym6T-AJcFFIKw3Gck3SQ
~~~
~~~bash
echo $SA_CA_CRT
~~~
~~~
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIzMDMyNzE4MDYzNFoXDTMzMDMyNDE4MDYzNFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKwz
cfdfYt4TWc6F+EbysYAmvfiOQ3J562Dclj2VdD4Hvt/3zHDHgDxCNoMgSllha0ZZ
ZM5YzS8fPzy/BTCTQR/moxSIRNzvcCkABB2VlAly0YJWJbe/IIEVnIx8sYh2urKy
y51ePgf29gCz1RqCPWZkNmI4SSWP0zKaBhe4gbwKA/MasH5g8kMDqkUCa/ePWnn3
U/yHFQ2SzqAicmk9mj0FyJdFuvU4T9MvdUU+VavUi8iaCqCmb5t6FEfd+wTN76ON
NBK0AQeQwZk12k1UZxwiG5q7N8qHd/ifzldKnQ9FTPiiSwM3fEucGVOvV9yqySU9
g2kRFtecgab+9WpdhgcCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFCGLBTH/xe3FL9fdB09fcb3mf3RaMA0GCSqGSIb3
DQEBCwUAA4IBAQCWGqyF65IBpSQ7k7uZq/PmMoJlGusuIPEczhi1ScO3hb7YnuzY
C8GM2KY7RqYuMTwqfEzmf7EeZ4suORnkvXvV4CLOWmA9ahiA1gcTEscut3y6OlOZ
XLhxzAR8rKrSyEnJxf+u0O1CMnd6nFh1wzOH9UhayZG7svGsFJcAr4PBCZu+r7Q1
gRatxaVMpJ/CN3WxHJwJN8GWYgUeOrMlhDEiWnjQTNnQL9SYPtirJgCrQMhwtOSL
CCmnEEQ74mEyF5dQpNSsTyeYOCSixYj+FQgVHOln4TyZr3SvT53yj6OcvN+9Ddy6
Yfoe2U/VTd4ZmCn+zZCoUxViU6w6Q7H56KfX
-----END CERTIFICATE-----
~~~
~~~bash
echo $K8S_HOST
~~~
~~~
https://51.250.35.165
~~~

- Запишем конфиг в vault
~~~bash
kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="$K8S_HOST" \
kubernetes_ca_cert="$SA_CA_CRT"
~~~
~~~
Success! Data written to: auth/kubernetes/config
~~~

- Создадим файл политики
~~~bash
tee otus-policy.hcl <<EOF
path "otus/otus-ro/*" {
capabilities = ["read", "list"]
}
path "otus/otus-rw/*" {
capabilities = ["read", "create", "list"]
}
EOF
~~~

- создадим политику и роль в vault
~~~bash
kubectl cp otus-policy.hcl vault-0:./
~~~
~~~
tar: can't open 'otus-policy.hcl': Permission denied
command terminated with exit code 1
~~~
~~~bash
kubectl cp otus-policy.hcl vault-0:/tmp
kubectl exec -i -t vault-0 -- sh
~~~
~~~
/ $ cd
~ $ pwd
/home/vault
~ $ ls -la
total 20
drwxrwsrwx    3 root     vault         4096 Mar 27 19:14 .
drwxr-xr-x    1 root     root          4096 Oct 27 19:46 ..
-rw-------    1 vault    vault           15 Mar 27 19:15 .ash_history
drwxr-sr-x    3 vault    vault         4096 Mar 27 18:44 .cache
-rw-------    1 vault    vault           28 Mar 27 18:49 .vault-token
~ $ mv /tmp/otus-policy.hcl ./
~ $ ls -la
total 24
drwxrwsrwx    3 root     vault         4096 Mar 27 19:16 .
drwxr-xr-x    1 root     root          4096 Oct 27 19:46 ..
-rw-------    1 vault    vault           56 Mar 27 19:16 .ash_history
drwxr-sr-x    3 vault    vault         4096 Mar 27 18:44 .cache
-rw-------    1 vault    vault           28 Mar 27 18:49 .vault-token
-rw-r--r--    1 vault    vault          126 Mar 27 19:13 otus-policy.hcl
~~~

~~~bash
kubectl exec -it vault-0 -- vault policy write otus-policy /home/vault/otus-policy.hcl
~~~
~~~
Success! Uploaded policy: otus-policy
~~~
~~~bash
kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=default policies=otus-policy ttl=24h
~~~
~~~
Success! Data written to: auth/kubernetes/role/otus
~~~
 
- Проверим как работает авторизация
Создадим под с привязанным сервис аккаунтом и установим туда curl и jq
~~~bash
kubectl run tmp --rm -i --tty --overrides='{ "spec": { "serviceAccount": "vault-auth" }  }' --image alpine:3.7
~~~
~~~
If you don't see a command prompt, try pressing enter.
/ # apk add curl jq
~~~
- 
- Залогинимся и получим клиентский токен
~~~bash
VAULT_ADDR=http://vault:8200
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
~~~
~~~json
  "request_id": "70a878e1-3693-2823-cc41-ba765ea6decd",
"lease_id": "",
"renewable": false,
"lease_duration": 0,
"data": null,
"wrap_info": null,
"warnings": null,
"auth": {
"client_token": "hvs.CAESIEsgHjFN0vZkJnh0PWN3X5LYP5Fxb-BGrQpZ6tVhWXfXGh4KHGh2cy5sZWxCTmNScVFQQW9QcUpCTzExTHlWVlo",
"accessor": "sLdTwN7cXpl74xO0WLVIttCc",
"policies": [
"default",
"otus-policy"
],
"token_policies": [
"default",
"otus-policy"
],
"metadata": {
"role": "otus",
"service_account_name": "vault-auth",
"service_account_namespace": "default",
"service_account_secret_name": "",
"service_account_uid": "29e3a2d4-178a-4cb6-a82e-784fc498441c"
},
"lease_duration": 86400,
"renewable": true,
"entity_id": "28ee187c-9ba3-8a86-3294-0a19bdba759f",
"token_type": "service",
"orphan": true,
"mfa_requirement": null,
"num_uses": 0
}
}
~~~

~~~bash
TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' \
$VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
echo $TOKEN
~~~
~~~
hvs.CAESIPIaVTzAnux4wifkfX1KNyM6iCvbB73K88DWC4IsfqkxGh4KHGh2cy4wYW9DZXVGOEZzNWRNMFUwVnAzdU1IT0g
~~~

- Прочитаем записанные ранее секреты и попробуем их обновить, используя свой клиентский токен
~~~bash
curl --header "X-Vault-Token:hvs.CAESIPIaVTzAnux4wifkfX1KNyM6iCvbB73K88DWC4IsfqkxGh4KHGh2cy4wYW9DZXVGOEZzNWRNMFUwVnAzdU1IT0g" $VAULT_ADDR/v1/otus/otus-ro/config
~~~
~~~
{"request_id":"0ba7b989-6b07-dc7e-4d1c-272182f80db3","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
~~~
~~~bash
curl --header "X-Vault-Token:hvs.CAESIPIaVTzAnux4wifkfX1KNyM6iCvbB73K88DWC4IsfqkxGh4KHGh2cy4wYW9DZXVGOEZzNWRNMFUwVnAzdU1IT0g" $VAULT_ADDR/v1/otus/otus-rw/config
~~~
~~~
{"request_id":"45f8532f-5dbf-ec11-2c97-4a656f55d65a","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
~~~

- Проверим запись
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:hvs.CAESIPIaVTzAnux4wifkfX1KNyM6iCvbB73K88DWC4IsfqkxGh4KHGh2cy4wYW9DZXVGOEZzNWRNMFUwVnAzdU1IT0g" $VAULT_ADDR/v1/otus/otus-ro/config
~~~
~~~
{"errors":["permission denied"]}
~~~
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:hvs.CAESIPIaVTzAnux4wifkfX1KNyM6iCvbB73K88DWC4IsfqkxGh4KHGh2cy4wYW9DZXVGOEZzNWRNMFUwVnAzdU1IT0g" $VAULT_ADDR/v1/otus/otus-rw/config
~~~
~~~
{"errors":["permission denied"]}
~~~
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:hvs.CAESIJ3n6YBExadmhSJ8C1wCU3iamZLxx8as6PB2mYY5_4dqGh4KHGh2cy5kUmpmcjVSdGV5VVRjRVNza3psZEI2cHU" $VAULT_ADDR/v1/otus/otus-rw/config1
~~~
~~~
{"errors":["permission denied"]}
~~~

- Нам не хватает прав, добавляем в `otus-policy.hcl` capabilities:
~~~hcl
path "otus/otus-rw/*" {
capabilities = ["read", "create", "list", "update", "delete"]
}
~~~

## **Полезное:**

Start
~~~bash
yc managed-kubernetes cluster start k8s-4otus
~~~

Stop
~~~bash
yc managed-kubernetes cluster stop k8s-4otus
~~~

