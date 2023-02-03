local kube = import "https://github.com/bitnami-labs/kube-libsonnet/raw/52ba963ca44f7a4960aeae9ee0fbee44726e481f/kube.libsonnet";

local common(name) = {
  service: kube.Service(name) {
    target_pod:: $.deployment.spec.template,
  },

  deployment: kube.Deployment(name) {
    apiVersion: "apps/v1",
    spec+: {
      template+: {
        spec+: {
          containers_: {
            common: kube.Container("common") {
              env: [{name: "PORT", value: "50051"}],
              ports: [{containerPort: 50051}],
              resources: {requests: {cpu: "100m", memory: "64Mi"}, limits: {cpu: "200m", memory: "128Mi"}},
            },
          },
        },
      },
    },
  },
};

{
  catalogue: common("paymentservice") {
    deployment+: {
      spec+: {
        selector+: {
          matchLabels+: {
            app: "paymentservice"
          },
        },
        template+: {
          metadata+: {
            labels+: {
              app: "paymentservice"
            },
          },
          spec+: {
            containers_+: {
              common+: {
                name: "server",
                image: "gcr.io/google-samples/microservices-demo/paymentservice:v0.3.0",
              },
            },
          },
        },
      },
    },
  },

  payment: common("shippingservice") {
    deployment+: {
      spec+: {
        selector+: {
          matchLabels+: {
            app: "shippingservice"
          },
        },
        template+: {
          metadata+: {
            labels+: {
              app: "shippingservice"
            },
          },
          spec+: {
            containers_+: {
              common+: {
                name: "server",
                image: "gcr.io/google-samples/microservices-demo/shippingservice:v0.3.4",
              },
            },
          },
        },
      },
    },
  },
}