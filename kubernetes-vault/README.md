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
#git submodule add https://github.com/hashicorp/consul-helm.git kubernetes-vault/consul-helm
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
Unseal Key 1: /PjeuymEm4nKLIOzkdvbkbxE4uQhTcrqGu2H5bhBtnY=

Initial Root Token: hvs.Z2qijozVn2ANcvn7u0nW1h3W

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
Unseal Key 1: /PjeuymEm4nKLIOzkdvbkbxE4uQhTcrqGu2H5bhBtnY=

Initial Root Token: hvs.Z2qijozVn2ANcvn7u0nW1h3W

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
kubectl exec -it vault-0 -- vault operator unseal '/PjeuymEm4nKLIOzkdvbkbxE4uQhTcrqGu2H5bhBtnY='
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
kubectl exec -it vault-1 -- vault operator unseal '/PjeuymEm4nKLIOzkdvbkbxE4uQhTcrqGu2H5bhBtnY='
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
kubectl exec -it vault-2 -- vault operator unseal '/PjeuymEm4nKLIOzkdvbkbxE4uQhTcrqGu2H5bhBtnY='
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

- Опять проверим состояние vault'а
~~~bash
kubectl exec -it vault-0 -- vault status
~~~
~~~README.md
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
Cluster Name    vault-cluster-1a5d8295
Cluster ID      45facc00-2592-eae7-3b85-7e22d40ba776
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2023-03-28T06:06:48.537949829Z
~~~
- Исчезло сообщение об `exit code 2`
~~~
command terminated with exit code 2
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
token                hvs.Z2qijozVn2ANcvn7u0nW1h3W
token_accessor       uzqjEhHPh88EfcuRiR8f0N8t
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
token/    token    auth_token_258d38b7    token based credentials    n/a
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
cubbyhole/    cubbyhole    cubbyhole_414b10ed    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           6b5ea250-0c0e-5eda-d0d4-9fd348ca0b78    n/a        v1.12.1+builtin.vault    n/a               n/a
identity/     identity     identity_ee1d809a     system         system     false             replicated     false        false                      map[]      identity store                                             2fe657ab-a794-1f41-4e5a-afae8ebfd719    n/a        v1.12.1+builtin.vault    n/a               n/a
otus/         kv           kv_c9ab5d24           system         system     false             replicated     false        false                      map[]      n/a                                                        1a88f639-dccc-5048-bbc5-f5a34aad646f    n/a        v0.13.0+builtin          n/a               supported
sys/          system       system_c0506b1f       n/a            n/a        false             replicated     true         false                      map[]      system endpoints used for control, policy and debugging    85ff6364-72b9-2b34-4a07-a0f73468d77b    n/a        v1.12.1+builtin.vault    n/a               n/a[0m
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

- Создадим yaml для `ServiceAccount` и `ClusterRoleBinding`
~~~bash
tee vault-auth-service-account.yml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
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

~~~bash
# Update the 'vault-auth' service account
kubectl apply -f vault-auth-service-account.yml
~~~
~~~
serviceaccount/vault-auth created
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created
~~~

- Kubernetes 1.24+ only
  The service account generated a secret that is required for configuration automatically in Kubernetes 1.23. In Kubernetes 1.24+, 
  you need to create the secret explicitly.
  Создадим файл `vault-auth-secret.yml`
~~~yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-secret
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
~~~

- Create a vault-auth-secret secret.
~~~bash
kubectl apply --filename vault-auth-secret.yml
~~~
~~~
secret/vault-auth-secret created
~~~

- Подготовим переменные для записи в конфиг кубер авторизации
~~~bash
export SA_SECRET_NAME=$(kubectl get secrets --output=json \
    | jq -r '.items[].metadata | select(.name|startswith("vault-auth-")).name')
export SA_JWT_TOKEN=$(kubectl get secret $SA_SECRET_NAME \
    --output 'go-template={{ .data.token }}' | base64 --decode)
export SA_CA_CRT=$(kubectl config view --raw --minify --flatten \
    --output 'jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
export K8S_HOST=$(kubectl config view --raw --minify --flatten \
    --output 'jsonpath={.clusters[].cluster.server}')
~~~
~~~bash
### alternative way
export K8S_HOST=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/https/ {print $NF}' | sed 's/\x1b[[0-9;]*m//g')
~~~

~~~bash
echo $SA_SECRET_NAME
~~~
~~~
vault-auth-token-9wdrd
~~~
~~~bash
echo $SA_JWT_TOKEN
~~~
~~~
eyJhbGciOiJSUzI1NiIsImtpZCI6IklZU01UNmdmM2VPa1hrMDV1dUpQWW1zQVh5Q2FNM2t1N1p2YlFoYXZPNEEifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InZhdWx0LWF1dGgtc2VjcmV0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6InZhdWx0LWF1dGgiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJmYWU1Y2ZmOS1kYTVlLTQ1ZGUtOGJhNS1iN2YyMDc2ZGRmZDYiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDp2YXVsdC1hdXRoIn0.Q7y2o9y-7KwmCiRK7azOQMkFi1xPIDtc8D43VqErY-3FFkl2fmHZakXsiHv3g0UG4SG_cdCzfRIpr1QEO04ujQtOF3i3Hwf4g0vau6-Pc0lYv9tKrj3lj8laVXVAbnxeq8XIofULk-r72_uZJBKnvgVW6jn_IAM8jB4dFKxjNjGVCRvfXlZveo4NBbS1_o6_qAqFK4w7si3mug1yO7LLZwCDG-iPaB4XcIV5hXByaaJzr33eHv9jhxISAcUwobm45_SfLp6uGGpcx0NMPA5uqHZ3SJtdolC1CmQt22f0V_aQ7xVBNFcsFlzc9BlM25knLTmfEozndZE8MH6xGT02lg
~~~
~~~bash
echo $SA_CA_CRT
~~~
~~~
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIzMDMyODA0MjA1NFoXDTMzMDMyNTA0MjA1NFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALQc
c8yTeI8W+5P2RRU9rrgoMHTs0etrC0mxipi5Lp4kDJxjEGMxXH90abPah4XFKKss
Nm+Wys3pfPSUrXYPsAyaV33kGxgoNzDRaSzolMLtCa6LzdCuFOR5TJvwMg9dSG8a
FcE9rQuFq7Lmj5jAQOO21w5t7k5X2DtlT5SVCb26W3Q3JWOyS/wEg3Foq4nVpzPp
mrhkbIMgygGeAPbCoH2SXzBlbIFmx6k334JUTvOxGQ7NefQFParpO5PW30LBHNPZ
iyipFsMzFCUJRkPXLQv0gHohFjsrnZiNsbB5jfaWwQNej86oRzrGLn281J5ECH1U
5lFwbQHwVJIxFDkTwtMCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFBkJ1WySXgTLd0UE43xKjJVKI2TKMA0GCSqGSIb3
DQEBCwUAA4IBAQCAxhv/T5ANQ+XjfQm63dxkg8Le/Kwu806/Ocrx9bPxVmGn70ox
+VJPgRhEswvKgnLVf6kITPucm3JdFE/zsHLauVNuS2UrdVN+IpK6zcqcIdnbRSZL
PuKjmmfEC/VkZnHUeNIHU3fhzogsXa6oY77GoZ/VClvWlrPBVoXpypIHLp/pKwOk
5m8eCihmKK/9vPMKqIe1PnScZzkNYWW3OxsJV8B+2KEWoJ65IYyaiwsSTHfKX8Mx
GuH0HPgsD5st5RPJJcrJIWLgt7n1PDMKFK+PmUlZsEg9F35mM7EPYU+g8QXIUziA
Hjw+1+ywzq9hrfToltidUz2OTeDJAgD81mlL
-----END CERTIFICATE-----
~~~
~~~bash
echo $K8S_HOST
~~~
~~~
https://51.250.47.135
~~~

- Запишем конфиг в vault
~~~bash
kubectl exec -it vault-0 -- vault write auth/kubernetes/config \
     token_reviewer_jwt="$SA_JWT_TOKEN" \
     kubernetes_host="$K8S_HOST" \
     kubernetes_ca_cert="$SA_CA_CRT" \
     issuer="https://kubernetes.default.svc.cluster.local"
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
     bound_service_account_namespaces=default \
     token_policies=otus-policy \
     ttl=24h
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
  "request_id": "fd777b17-c022-172c-e3bf-b5e480ea7d7b",
"lease_id": "",
"renewable": false,
"lease_duration": 0,
"data": null,
"wrap_info": null,
"warnings": null,
"auth": {
"client_token": "hvs.CAESICOqM8MWaZ4JsCPKYZUsfaFDRnFOmwKH_ALZP_Mwl5-nGh4KHGh2cy5UWlVNMUVhaXhSbzN1NkpzQW16djgzWU0",
"accessor": "lyoyeHJdLc1TFZd8mEcOWSj9",
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
"service_account_uid": "fae5cff9-da5e-45de-8ba5-b7f2076ddfd6"
},
"lease_duration": 86400,
"renewable": true,
"entity_id": "555850ab-2ca5-e03a-7fe9-f26c889feb1a",
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
hvs.CAESIKTEuigjN0JDtnI_2xq7UNWon3X_nGCGBwCJR397qbZbGh4KHGh2cy5qdXdwaUNtQTBORGhweDY2b29EWnE4VHc
~~~

- Прочитаем записанные ранее секреты и попробуем их обновить, используя свой клиентский токен
~~~bash
curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
~~~
~~~
{"request_id":"0ba7b989-6b07-dc7e-4d1c-272182f80db3","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
~~~
~~~bash
curl --header "X-Vault-Token:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
~~~
~~~
{"request_id":"45f8532f-5dbf-ec11-2c97-4a656f55d65a","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
~~~

- Проверим запись
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:$TOKEN" $VAULT_ADDR/v1/otus/otus-ro/config
~~~
~~~
{"errors":["permission denied"]}
~~~
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config
~~~
~~~
{"errors":["permission denied"]}
~~~
~~~bash
curl --request POST --data '{"bar": "baz"}' --header "X-VaultToken:$TOKEN" $VAULT_ADDR/v1/otus/otus-rw/config1
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

- Verify the Kubernetes auth method configuration
~~~bash
kubectl apply --filename devwebapp.yaml --namespace default
kubectl get pods -l app=devwebapp -w
~~~

- Start an interactive shell session on the devwebapp pod.
~~~bash
kubectl exec --stdin=true --tty=true devwebapp -- /bin/sh
~~~
~~~
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
~~~
~~~
curl --request POST \
       --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "otus"}' \
       $VAULT_ADDR/v1/auth/kubernetes/login

~~~
~~~json
{"request_id":"30335051-6faa-2882-eec7-58ffc13b2485","lease_id":"","renewable":false,"lease_duration":0,"data":null,"wrap_info":null,"warnings":null,"auth":{"client_token":"hvs.CAESIOo2CgG1wtp6xVlMzT7va-dnTKBkM_OEDMXeoKVtiGYVGh4KHGh2cy4yOFg3NjE3TjlxU0hpUXY5ckllWWVZeDg","accessor":"IUIK6SSDAzNzTumfgIwKEU3K","policies":["default","otus-policy"],"token_policies":["default","otus-policy"],"metadata":{"role":"otus","service_account_name":"vault-auth","service_account_namespace":"default","service_account_secret_name":"","service_account_uid":"fae5cff9-da5e-45de-8ba5-b7f2076ddfd6"},"lease_duration":86400,"renewable":true,"entity_id":"555850ab-2ca5-e03a-7fe9-f26c889feb1a","token_type":"service","orphan":true,"mfa_requirement":null,"num_uses":0}}
~~~

- Заберем репозиторий с примерами
~~~bash
cd ..
git submodule add https://github.com/hashicorp/vault-guides.git kubernetes-vault/vault-guides
~~~

В каталоге `configs-k8s` скорректируем конфиги с учетом ранее созданных ролей и секретов.
Проверим и скорректируем конфиг `example-k8s-spec.yml`,`configmap.yaml`

- Запускаем пример
~~~bash
# Create a ConfigMap, example-vault-agent-config
kubectl create --filename ./configs-k8s/configmap.yaml 
~~~
~~~bash
# View the created ConfigMap
kubectl get configmap example-vault-agent-config -o yaml
~~~

<details>
  <summary>example-vault-agent-config</summary>

~~~yaml
apiVersion: v1
data:
  configmap.yaml: |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: example-vault-agent-config
      namespace: default
    data:
      vault-agent-config.hcl: |
        # Comment this out if running as sidecar instead of initContainer
        exit_after_auth = true

        pid_file = "/home/vault/pidfile"

        auto_auth {
            method "kubernetes" {
                mount_path = "auth/kubernetes"
                config = {
                    role = "otus"
                }
            }

            sink "file" {
                config = {
                    path = "/home/vault/.vault-token"
                }
            }
        }

        template {
        destination = "/etc/secrets/index.html"
        contents = <<EOT
        <html>
        <body>
        <p>Some secrets:</p>
        {{- with secret "otus/otus-ro/config" }}
        <ul>
        <li><pre>username: {{ .Data.data.username }}</pre></li>
        <li><pre>password: {{ .Data.data.password }}</pre></li>
        </ul>
        {{ end }}
        </body>
        </html>
        EOT
        }
  example-k8s-spec.yaml: |
    apiVersion: v1
    kind: Pod
    metadata:
      name: vault-agent-example
      namespace: default
    spec:
      serviceAccountName: vault-auth

      volumes:
      - configMap:
          items:
          - key: vault-agent-config.hcl
            path: vault-agent-config.hcl
          name: example-vault-agent-config
        name: config
      - emptyDir: {}
        name: shared-data

      initContainers:
      - args:
        - agent
        - -config=/etc/vault/vault-agent-config.hcl
        - -log-level=debug
        env:
        - name: VAULT_ADDR
          value: http://vault:8200
        image: vault
        name: vault-agent
        volumeMounts:
        - mountPath: /etc/vault
          name: config
        - mountPath: /etc/secrets
          name: shared-data

      containers:
      - image: nginx
        name: nginx-container
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: shared-data
kind: ConfigMap
metadata:
  creationTimestamp: "2023-03-27T21:26:05Z"
  name: example-vault-agent-config
  namespace: default
  resourceVersion: "53122"
  uid: 15f443ff-ec76-4d6c-96a9-820a081014de
~~~

</details>

~~~bash
# Finally, create vault-agent-example Pod
kubectl apply --filename apiVersion: v1
data:
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }

    template {
    destination = "/etc/secrets/index.html"
    contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/otus-ro/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{ end }}
    </body>
    </html>
    EOT
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2023-03-28T07:57:16Z"
  name: example-vault-agent-config
  namespace: default
  resourceVersion: "57538"
  uid: 8daf4a16-0b40-415c-b248-66cda153d799
~~~
~~~
Flag --record has been deprecated, --record will be removed in the future
pod/vault-agent-example created
~~~

- Проверка
~~~bash
kubectl exec -ti vault-agent-example -c nginx-container  -- cat /usr/share/nginx/html/index.html
~~~
~~~html
<html>
<body>
<p>Some secrets:</p>
<ul>
<li><pre>username: otus</pre></li>
<li><pre>password: asajkjkahs</pre></li>
</ul>

</body>
</html>
~~~

### Создадим CA на базе vault

- Включим pki секрет
~~~bash
kubectl exec -it vault-0 -- vault secrets enable pki
~~~
~~~
Success! Enabled the pki secrets engine at: pki/
~~~
~~~bash
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
~~~
~~~
Success! Tuned the secrets engine at: pki/
~~~
~~~bash
kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal \
common_name="example.ru" ttl=87600h > CA_cert.crt
~~~

- пропишем урлы для CA и отозванных сертификатов
~~~bash
kubectl exec -it vault-0 -- vault write pki/config/urls \
issuing_certificates="http://vault:8200/v1/pki/ca" \
crl_distribution_points="http://vault:8200/v1/pki/crl"
~~~
~~~
Success! Data written to: pki/config/urls
~~~

- создадим промежуточный сертификат
~~~bash
kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
~~~
~~~
Success! Enabled the pki secrets engine at: pki_int/
~~~
~~~bash
kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
~~~
~~~
Success! Tuned the secrets engine at: pki_int/
~~~
~~~bash
kubectl exec -it vault-0 -- vault write -format=json \
pki_int/intermediate/generate/internal \
common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
~~~

- пропишем промежуточный сертификат в vault
~~~bash
kubectl cp pki_intermediate.csr vault-0:/tmp
~~~
~~~bash
kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate \
csr=@/tmp/pki_intermediate.csr \
format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
~~~
~~~bash
kubectl cp intermediate.cert.pem vault-0:/tmp
~~~
~~~bash
kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed \
certificate=@/tmp/intermediate.cert.pem
~~~
~~~
WARNING! The following warnings were returned from Vault:

  * This mount hasn't configured any authority information access (AIA)
  fields; this may make it harder for systems to find missing certificates
  in the chain or to validate revocation status of certificates. Consider
  updating /config/urls or the newly generated issuer with this information.

Key                 Value
---                 -----
imported_issuers    [5af7aa08-a4ba-f955-e2c6-81235eeca63d c6b6fb90-4148-9d16-c784-5abc3317e54c]
imported_keys       <nil>
mapping             map[5af7aa08-a4ba-f955-e2c6-81235eeca63d:cd13faa1-6317-f444-871a-582b1b310c61 c6b6fb90-4148-9d16-c784-5abc3317e54c:]
~~~

### Создадим и отзовем новые сертификаты
- Создадим роль для выдачи сертификатов
~~~bash
kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru \
allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
~~~
~~~README.md
Success! Data written to: pki_int/roles/example-dot-ru
~~~

- Создадим и отзовем сертификат
~~~bash
kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru \
common_name="gitlab.example.ru" ttl="24h"
~~~
~~~
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUbPdYVPtzv9Pt1QkcnQYfQJtHDN0wDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMzAzMjgwODU4MTdaFw0yODAz
MjYwODU4NDdaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALs0TaN0oKjZ
vfl+TwjqcEfe7GX4pMI6usmApdUGB04wT5QP6BUZrpol4x1YEMrt8xA4sDUdiNNi
570oAiuBlawF7J1mUTT5swFE+W6+jl+EKQKyhcjXiVSRs+FEQ7b/2LhP0CpWah+u
djmNIqh4E0m8Dr2FqsD44oUhkEmCUUi5JbmnGr8EHHV8lda8HyycJSXdj2obSFT8
syvJ+hAnSOe4XaCobOJXNcD1OapDslfvZh1TNIGd+Mb6XEwjvEgroZSSNBG4NAPE
OT3GPBbp4RMsaH06yNMZBoz1Btl7uTgcm1rZRLuF2udUK9qz8cJ39Y/FkiQKpYrj
xe5fLWKWF9ECAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQU7rkOWhRqlO6pcCxeeNE70TQhRhwwHwYDVR0jBBgwFoAU
8aA2+0Y7ldDyZRgtLy40YRJQ1BUwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
upwJHEb4+bqbYAlNv8wqzzjvN0smBrILrzeMMst11i6rHZuuPyO5IObhJWONJXzI
X0IHWaRqRfmdBzjjNHiz/JeNVGEytkqLbofN5wtRR68gly7eoSBRlTa0ihgGsdo/
DK/Frtv2X0IyXIr2y5g0X0Sla0TUNBIeRyzhBgY/iIvtJtc4S2HrQw2CcKAkzBvo
hmhMT7xMpJEcpwLJSbpLEB5BhKDuNuSRXx0CnHpZX4Dh6s7KWIH/UpOWyY9Z5z3f
SBiYTDhLlq3c0iI59ato3v6Ns2kmBLjBxKkpnArNcyALoxrHwGVPM6slVaPxHCkS
+sM3ZryNHAX7dmsQE7zIHA==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUfKrsyazvd8Cy5cPKxCPCf2s/MhcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMzAzMjgwODQ5MzdaFw0zMzAz
MjUwODUwMDdaMBUxEzARBgNVBAMTCmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDLS4dUV5rehRiLXtFSPkZezWW6wwH3G/xoiysdv1Gw
ZzxLd/ruFgmkfg9pZUfRCvLw2zOSSAyT958zIgPqHAv4QDvLgWkuD9ml0WYUGtEV
KkkRKF1W+Xw1z6Ok2DY4skuiq4Zaduh5yAPdR3iOAqXKSJop64GLiaSXpLRwqV4A
/3Bc3gKnUvxfBtSKhI/mQIbev7nIonvTBEmczHMGhzATXoeto0K/CdAbBvgBuVed
1ExocKBICOGwP84OzW4FmUQ6diJDIZNAdb7YODUSOMcZq8fEHYtdZNuHCDi7mC0h
HTRK3T/O1lhqQ1e18DjRUm+Z6pwU42vYuzzKDe+OMOy9AgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTxoDb7RjuV0PJl
GC0vLjRhElDUFTAfBgNVHSMEGDAWgBTxoDb7RjuV0PJlGC0vLjRhElDUFTAVBgNV
HREEDjAMggpleGFtcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQAARMBndZzVe0zg
17+jLSnwXAPY0aB2gHqApZbLL4BfPCeMhD9Kk/Rg8Zh0hAA7Dyjyr0cVfqKkBi4O
oqrXMbXqxx4WyD0Mfrn5YUCOPRyl2S9n0pOZYAmk8qeuS4IN208kuG5WuOS1Qdiv
TY0atIPbEa4JvRyGvKd8PCD1+tKKH5QUXt50PM1DFrcSYL9XCdaX9cTLzI8FwIaJ
3NdnfDCOSuE91zzavFC4roPtteTiPKG959hARhd26+KwR548sz/4FhsnTs6uw0Qd
Ap+SM+nsHNSmRvCPCs3KAhcTh6HxxJ3E/TQqWUqciA8njoJyOk9E/KYIVP1Z7qiJ
fOesvkfB
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUIadbA2ZSNHIXQnWAln1P7hX9BmkwDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTIzMDMyODA5MDQzMVoXDTIzMDMyOTA5MDUwMVowHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDR
Z9k10E/NoYlfsdSxGCEPef1Lb55teXjnRCJpFhc9t67t5QSkY4Zv6h74JGSjNcXX
BDZ3mP1gFDrapLN3JIMwJf8bF7YsxxG/oVrq9Nm0N3yom64pdwp7KlBDjknVykPt
eSiqWzmpnHITrmm+cNCEsYgqreaETqUfjVuKd7IUc60ewRniAxFxx76wqO8Z1Mh+
NV6n5RZMZkxQ5lSdRsCfj5Wa/8SLYUTMVaPhTo9CCOYA754vopVIMNzk9Xb9EJPP
jAPpJ2U6RglBcgFuRoadl6J2YAq7tDdz1KHKOPWwINbBtXcaMN5OR+rtlQIm+CH8
f7++Egu7u1a5wlbZw3s/AgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUCBGgejthmKEwuNXe
gzypjZmJZbwwHwYDVR0jBBgwFoAU7rkOWhRqlO6pcCxeeNE70TQhRhwwHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBAC5bQ9uw
OhxdDrAkxqXpzJaYYMpLB17T9PctgyeVE6o8l1E+MMFS8CkVvqOi7deCEmRnaSly
Klv4DmWjk7resV7d+xOj0ENOluVaATkHeLfpsZnbQo/dXq3skN06m7eYvBh3Kfuu
vzcqCB2eXM+iwX7Gz5ytIvRhrM7mfKYLBNE8K+0WwdztAkWtvXtZTEElT5OdBKgZ
13MhXrCk+H/+1HZtykyKK034ZOxGyqnw6d6xI8Kiy+AeyuHOZsRCQ2LfQjZthKWV
w3k17VT+syGT0aeWG+rmN+6mlWiiDSSfxvXUwcHhtRjt+mxM1G+uUBxuUGBIVIw/
pm3u/8WE07FNDBs=
-----END CERTIFICATE-----
expiration          1680080701
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUbPdYVPtzv9Pt1QkcnQYfQJtHDN0wDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMzAzMjgwODU4MTdaFw0yODAz
MjYwODU4NDdaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALs0TaN0oKjZ
vfl+TwjqcEfe7GX4pMI6usmApdUGB04wT5QP6BUZrpol4x1YEMrt8xA4sDUdiNNi
570oAiuBlawF7J1mUTT5swFE+W6+jl+EKQKyhcjXiVSRs+FEQ7b/2LhP0CpWah+u
djmNIqh4E0m8Dr2FqsD44oUhkEmCUUi5JbmnGr8EHHV8lda8HyycJSXdj2obSFT8
syvJ+hAnSOe4XaCobOJXNcD1OapDslfvZh1TNIGd+Mb6XEwjvEgroZSSNBG4NAPE
OT3GPBbp4RMsaH06yNMZBoz1Btl7uTgcm1rZRLuF2udUK9qz8cJ39Y/FkiQKpYrj
xe5fLWKWF9ECAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQU7rkOWhRqlO6pcCxeeNE70TQhRhwwHwYDVR0jBBgwFoAU
8aA2+0Y7ldDyZRgtLy40YRJQ1BUwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
upwJHEb4+bqbYAlNv8wqzzjvN0smBrILrzeMMst11i6rHZuuPyO5IObhJWONJXzI
X0IHWaRqRfmdBzjjNHiz/JeNVGEytkqLbofN5wtRR68gly7eoSBRlTa0ihgGsdo/
DK/Frtv2X0IyXIr2y5g0X0Sla0TUNBIeRyzhBgY/iIvtJtc4S2HrQw2CcKAkzBvo
hmhMT7xMpJEcpwLJSbpLEB5BhKDuNuSRXx0CnHpZX4Dh6s7KWIH/UpOWyY9Z5z3f
SBiYTDhLlq3c0iI59ato3v6Ns2kmBLjBxKkpnArNcyALoxrHwGVPM6slVaPxHCkS
+sM3ZryNHAX7dmsQE7zIHA==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0WfZNdBPzaGJX7HUsRghD3n9S2+ebXl450QiaRYXPbeu7eUE
pGOGb+oe+CRkozXF1wQ2d5j9YBQ62qSzdySDMCX/Gxe2LMcRv6Fa6vTZtDd8qJuu
KXcKeypQQ45J1cpD7Xkoqls5qZxyE65pvnDQhLGIKq3mhE6lH41bineyFHOtHsEZ
4gMRcce+sKjvGdTIfjVep+UWTGZMUOZUnUbAn4+Vmv/Ei2FEzFWj4U6PQgjmAO+e
L6KVSDDc5PV2/RCTz4wD6SdlOkYJQXIBbkaGnZeidmAKu7Q3c9Shyjj1sCDWwbV3
GjDeTkfq7ZUCJvgh/H+/vhILu7tWucJW2cN7PwIDAQABAoIBACY6SxDj4m2rm6R4
llduDDsDDhaDXeymTEgLzCxa+AswSSLsuBg6gwRTPSwXmLeizWcfQcI7j6XGi6f2
gTyy0bAsf5G2lm8+OCM/lZVm9YdMydkN8pFnReaOJvDuPNRmhFgJ0j6nQLOR99FX
+b3mYmqW7kC8VmS45rQH3jo896l7z+iaTUKV+9B+ybBciFcrN2lVJO8s8p2XAfLp
oz8U9Z8RXgZf/BownllKCWWGdPIBXB9GvKIoDR2wJq+S+AUBOItpHs6WHrhjnpoQ
EbqobZ9ECUBJ1MetsjDguE5+njB1oCw8ZPMCWNftTymBigA/eZOrc9hGCuY81ZWi
9kZ9ZGECgYEA2xSdRpD+0ENN5bDveN8u/FTpNG331xxioPEKDjA/eE+lmyVIYVQF
XJ3iET59wqZnqpEFX1aTsr2UsDk/wN8aMMz4Zc9rjCNT5BgofxLvf9YGfCLeUCAc
AAeugkV6SFbTAmH/w281mh0akyNEqgHF1DK9bT1W2/duZNEd+KmQo3UCgYEA9LHZ
aGU7aKvPTjCibE6ZgL6j7pApSvHXV/f2gUvmkm6/gJXFB2rIgl++PEjy+4Bc4sCQ
uF3hHBs676af5QVfHasnTHQuxH6LoTseSmh5g2fBlSiPZoaoWl+tEshMZlQsLdx8
7iOB5xtkI9zJSy7WK3wbWKvUBoGhrta99hRjkWMCgYBTp6Z6qKk0W07mc06uCAMI
BWBbTdaChGtA62mci13hEgC5ol3mFFBL0lndndAlwKb7IY88nXGeofeh5upqOobk
tY/wSGjXxTGmencUNuXPGam2QxZC4E/wzv4a7m7IKqc+VK92MAP2ykA4iRISHMUu
xwVALlj5e5zi0FsydYUudQKBgQDgnmH0cvkWHKEwJXTz9zLx/A5/79X39gi3t+eQ
yRvfT8p7PwCezmdBRqJatJxYQn0BqcMvev4pztVLKKmekk+97F8mz4Ae4AtM9ffY
Vg81kQki4xjABNyGGU3G8Bcx2BK2BrCn6fBVNc+3G/WsDlKLmGGCBDmdv2GsHXRD
cHP2AQKBgBsopN+pEG9M2y8EfTlJzDvngqr3orQ4XycKVbrHPZS/Moo06h6X3VTP
zC7etNcCgiISD+qtflXAgguL1hn7rFpGj4C76+IIlvlKFk0OMwKbL1J8v+RtlyqF
D4wDAufgRtoe5fvoQShyZ4vqN7OaPR1pLIUiDit8+N3qQ/mlzVL3
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       21:a7:5b:03:66:52:34:72:17:42:75:80:96:7d:4f:ee:15:fd:06:69
~~~

~~~bash
kubectl exec -it vault-0 -- vault write pki_int/revoke \
serial_number="21:a7:5b:03:66:52:34:72:17:42:75:80:96:7d:4f:ee:15:fd:06:69"
~~~
~~~README.md
Key                        Value
---                        -----
revocation_time            1679994349
revocation_time_rfc3339    2023-03-28T09:05:49.650972696Z
~~~


## **Полезное:**

>https://developer.hashicorp.com/vault/tutorials/kubernetes/agent-kubernetes

Start
~~~bash
yc managed-kubernetes cluster start k8s-4otus
~~~

Stop
~~~bash
yc managed-kubernetes cluster stop k8s-4otus
~~~

