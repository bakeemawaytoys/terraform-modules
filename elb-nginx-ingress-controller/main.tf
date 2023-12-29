terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }
  required_version = ">= 1.5"
}

data "aws_default_tags" "current" {}

# Use a post condition to ensure the module is only applied to k8s versions supported by the controller.
# https://github.com/kubernetes/ingress-nginx#supported-versions-table
# tflint-ignore: terraform_unused_declarations
data "kubectl_server_version" "current" {
  lifecycle {
    postcondition {
      condition     = (contains(range(24, 27), parseint(self.minor, 10)) && startswith(var.chart_version, "4.7.")) || (contains(range(25, 28), parseint(self.minor, 10)) && (startswith(var.chart_version, "4.8.") || startswith(var.chart_version, "4.9.")))
      error_message = "The Kubernetes cluster's version is not suppored by version ${var.chart_version} of the Nginx ingress controller Helm chart.  See https://github.com/kubernetes/ingress-nginx#supported-versions-table for the compatible versions."
    }
  }
}

locals {

  labels = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
    },
    var.labels,
  )

  elb_tags = merge(
    data.aws_default_tags.current.tags,
    var.tags,
    {
      managed_with = "nginx-ingress-controller"
    }
  )
  elb_tag_list = [for k, v in local.elb_tags : "${k}=${v}"]

  access_logs_annotations = var.access_logging.enabled ? {
    "service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval" = "5"
    "service.beta.kubernetes.io/aws-load-balancer-access-log-enabled"       = "true"
    # Push the access logs to the bucket defined by load-balancer-access-logs-bucket module.
    "service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name"   = var.access_logging.bucket
    "service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-prefix" = var.access_logging.prefix
  } : {}

  # Set the controller ports to something above 1024 so that privilege escalation can be disabled.
  # https://github.com/kubernetes/ingress-nginx/issues/7055#issuecomment-950571065
  # https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers#Well-known_ports
  controller_ports = {
    http = 8080
    # A defacto standard when using 8080 for HTTP is to use 8443 for HTTPS.
    # We have to use something else because the admission webhook is configured for 8443.
    https = 8081
  }

  node_selector = merge(
    var.node_selector,
    # Include the chart's default node selector
    {
      "kubernetes.io/os" = "linux"
    },
  )

  node_tolerations = concat(
    [
      # Include default tolerations for the standard architecture label to support clusters with mixed architectures
      {
        effect   = "NoSchedule"
        key      = "kubernetes.io/arch"
        operator = "Equal"
        value    = "amd64"
      },
      {
        effect   = "NoSchedule"
        key      = "kubernetes.io/arch"
        operator = "Equal"
        value    = "arm64"
      },
    ],
    var.node_tolerations,
  )

  # declare a local for the chart name because the name is used to construct labels in the chart's templates.
  chart_name = "ingress-nginx"
}

resource "helm_release" "nginx" {
  atomic           = true
  cleanup_on_fail  = true
  chart            = local.chart_name
  create_namespace = false
  max_history      = 5
  name             = var.release_name
  namespace        = var.namespace
  recreate_pods    = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  version          = var.chart_version
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode(
      {
        commonLabels = local.labels
        controller = {
          admissionWebhooks = {
            enabled = var.enable_admission_webhook
            patch = {
              nodeSelector = local.node_selector
              tolerations  = local.node_tolerations
            }
          }
          affinity = {
            # Prevent controller pods from running on the same node. The selector is copied from an example in the Helm chart's values
            # https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml#L254
            podAntiAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = [
                {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        # The name label is set to the name of the chart UNLESS nameOverride is set in the values.
                        # https://github.com/kubernetes/ingress-nginx/blob/f9cce5a4ed7ef372a18bc826e395ff5660b7a444/charts/ingress-nginx/templates/_helpers.tpl#L6
                        # https://github.com/kubernetes/ingress-nginx/blob/f9cce5a4ed7ef372a18bc826e395ff5660b7a444/charts/ingress-nginx/templates/_helpers.tpl#L141
                        values = [local.chart_name]
                      },
                      {
                        key      = "app.kubernetes.io/instance"
                        operator = "In"
                        # The chart sets the instance label to the name of the release.
                        # https://github.com/kubernetes/ingress-nginx/blob/f9cce5a4ed7ef372a18bc826e395ff5660b7a444/charts/ingress-nginx/templates/_helpers.tpl#L142
                        values = [var.release_name]
                      },
                      {
                        key      = "app.kubernetes.io/component"
                        operator = "In"
                        values   = ["controller"]
                      },
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              ]
            }
          }
          allowSnippetAnnotations = var.allow_snippet_annotations
          config                  = var.nginx_custom_configuration
          containerPort = {
            http  = local.controller_ports.http
            https = local.controller_ports.https
          }
          # Ensure a unique name is used to support multiple controllers in the same namespace.
          # The ingress class resource is used because that is how the pre-v1 controller generated the ID.
          # https://github.com/kubernetes/ingress-nginx/issues/8144
          electionID = "ingress-controller-leader-${var.ingress_class_resource.name}"
          extraArgs = {
            default-ssl-certificate = "${var.namespace}/${var.default_ssl_certificate_name}"
            http-port               = local.controller_ports.http
            https-port              = local.controller_ports.https
          }
          image = {
            # For some reason, the allowPrivilegeEscalation value is an attribute of the controller.image value and not part of the controller.containerSecurityContext value.
            allowPrivilegeEscalation = anytrue([for port in values(local.controller_ports) : port < 1024])
            registry                 = var.image_registry
          }
          ingressClassByName = true
          ingressClassResource = merge(
            var.ingress_class_resource,
            {
              enabled = true,
              # Ensure the controller value is unique to support multiple deployments in a single cluster.
              # The release name variable is used because its default value will generate the same
              # value as the chart's default value fo(as of version 4.x of the chart) for controller.ingressClassResource.controllerValue.
              # https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/
              controllerValue = "k8s.io/ingress-${var.release_name}"
            }
          )
          ingressClass = var.ingress_class_resource.name
          metrics = {
            enabled = true
            serviceMonitor = {
              enabled = var.service_monitor.enabled
              # Prevent the Prometheus Operator from changing the values of the namespace label (among others).
              # Flagger's built-in prometheus queries for the nginx ingress controller don't work when the namespace
              # label is relabled to exported_namespace by the Prometheus operator.
              honorLabels    = true
              scrapeInterval = var.service_monitor.scrape_interval
            }
          }
          patch = {
            labels = local.labels
            image = {
              registry = var.image_registry
            }
            nodeSelector = local.node_selector
            tolerations  = local.node_tolerations
            securityContext = {
              allowPrivilegeEscalation = false
              seccompProfile = {
                type = "RuntimeDefault"
              }
            }
          }
          nodeSelector = local.node_selector
          podAnnotations = {
            # Enable structured logging for the access logs that are written to stdout.
            # https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations
            # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/log-format/
            # https://github.com/fluent/fluent-bit-docker-image/blob/master/conf/parsers.conf#L27
            "fluentbit.io/parser_stdout" = "k8s-nginx-ingress"
            # Ensure the controller is never scheduled on Fargate because ELBs do not support Fargate nodes
            "eks.amazonaws.com/compute-type" = "ec2"
          }
          podSecurityContext = {
            runAsNonRoot = true
            # User 101 comes from the controller.runAsUser value in the chart's values.yaml file.  The default value has to be copied or else it won't be used because the controller.podSecurityContext value is overriden here.
            runAsUser = 101
            seccompProfile = {
              type = "RuntimeDefault"
            }
          }
          priorityClassName = var.priority_class_name
          resources         = var.controller_pod_resources
          replicaCount      = var.controller_replica_count
          service = {
            # See https://cloud-provider-aws.sigs.k8s.io/service_controller/ for the full list of annotations
            annotations = merge(
              local.access_logs_annotations,
              {
                "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = join(",", local.elb_tag_list)
                # Hard code this to true because the load balancers that receive external traffic are still deployed as internal ELBs.  The external is routed to the ELB through Fortigate.
                "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
                # Ensure the AWS Cloud Provider built into EKS clusters creates and manages the load balancer by adding the aws-load-balancer-scheme annotation.
                # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/#legacy-cloud-provider
                "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal"
              }
            )
            internal = {
              enabled = var.internal
            }
          }
          tolerations              = local.node_tolerations
          watchIngressWithoutClass = var.watch_ingress_without_class
        }
      }
    )
  ]
}

data "kubernetes_service_v1" "controller" {
  metadata {
    name      = "${helm_release.nginx.name}-${helm_release.nginx.chart}-controller"
    namespace = helm_release.nginx.namespace
  }
  depends_on = [helm_release.nginx]
}

#####################################
# Grafana Integration
#####################################

# https://github.com/kubernetes/ingress-nginx/tree/main/deploy/grafana/dashboards
locals {
  dashboards_directory = "${path.module}/files/dashboards"
  dashboard_file_names = fileset(local.dashboards_directory, "*")
}

# Install the dashboards as discoverable configmaps as described in the Grafana Helm chart's README file.
# https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards
resource "kubernetes_config_map_v1" "grafana_dashboard" {
  for_each = var.grafana_dashboard_config == null ? [] : local.dashboard_file_names
  metadata {
    annotations = {
      (var.grafana_dashboard_config.folder_annotation_key) = "Nginx Ingress"
    }
    labels = merge(
      local.labels,
      var.grafana_dashboard_config.label,
    )
    name      = split(".", each.key)[0]
    namespace = var.grafana_dashboard_config.namespace
  }

  data = {
    (each.key) = file("${local.dashboards_directory}/${each.key}")
  }
}
