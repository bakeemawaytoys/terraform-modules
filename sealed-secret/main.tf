terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16.0"
    }
  }
  required_version = ">= 1.3.0"
}

locals {


  labels = merge(
    var.labels,
    {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  )

  # Construct a map of valid values of the "scope" variable to annotation maps that will be merged with the annotations variable to
  # construct the full set of annotations to apply to the SealedSecret resource.
  scope_annotations = {
    "strict" = {}
    "cluster-wide" = {
      "sealedsecrets.bitnami.com/cluster-wide" = "true"
    }
    "namespace-wide" = {
      "sealedsecrets.bitnami.com/namespace-wide" = "true"
    }
  }

  # Encode and decode the map variables to work around a bug in the kuberenetes_manifest resource.
  # The encode/decode roundtrip "casts" them to Terraform's object type.
  # The bug stems from the fact that the sealed secret CRD doesn't have an OpenAPI schema.
  # https://github.com/hashicorp/terraform-provider-kubernetes/issues/1482
  # https://github.com/bitnami-labs/sealed-secrets/issues/82
  annotations = jsondecode(jsonencode(
    merge(
      var.annotations,
      local.scope_annotations[var.scope]
    )
  ))

  encrypted_data = jsondecode(jsonencode(var.encrypted_data))

  templated_secret_data = jsondecode(jsonencode(var.templated_secret_data))

  secret_metadata = {
    annotations = jsondecode(jsonencode(var.secret_metadata.annotations))
    labels = jsondecode(jsonencode(
      merge(
        local.labels,
        var.secret_metadata.labels,
        {
          "app.kubernetes.io/created-by" = "sealed-secrets-controller"
          "app.kubernetes.io/managed-by" = "sealed-secrets"
        }
    )))
  }
}

resource "kubernetes_manifest" "sealed_secret" {
  manifest = {
    apiVersion = "bitnami.com/v1alpha1"
    kind       = "SealedSecret"
    metadata = {
      annotations = tomap(local.annotations)
      labels      = tomap(local.labels)
      name        = var.name
      namespace   = var.namespace
    }

    spec = {
      encryptedData = local.encrypted_data
      template = {
        data = local.templated_secret_data
        type = var.secret_type
        metadata = {
          annotations = local.secret_metadata.annotations
          labels      = local.secret_metadata.labels
        }
      }
    }
  }

  wait {
    fields = {
      # Wait for the controller to process the resource.
      "status.conditions[0].status" = "*"
    }
  }

  timeouts {
    create = "${var.timeouts.create}s"
    update = "${var.timeouts.update}s"
    delete = "${var.timeouts.delete}s"
  }

  lifecycle {
    precondition {
      condition     = length(setintersection(keys(var.templated_secret_data), keys(var.encrypted_data))) == 0
      error_message = "The 'templated_secret_data' variable and the 'encrypted_data' variable cannot contain the same key."
    }

    precondition {
      condition     = can(tomap(var.templated_secret_data))
      error_message = "The 'templated_secret_data' variable must have the type map(string)."
    }
  }
}

# Due to the limitations of the kubernetes_manifest resource, the kubernetes_resource data resource is used to determine if the secret was successfully unsealed.
# Unlike the kubernetes_manifest resource, the data resource includes the resource's status attribute.
data "kubernetes_resource" "sealed_secret" {
  #TODO: Reference the manifest resource's object attribute to set theses values instead of using depends_on
  api_version = kubernetes_manifest.sealed_secret.object.apiVersion
  kind        = kubernetes_manifest.sealed_secret.object.kind
  metadata {
    name      = kubernetes_manifest.sealed_secret.object.metadata.name
    namespace = kubernetes_manifest.sealed_secret.object.metadata.namespace
  }

  depends_on = [
    kubernetes_manifest.sealed_secret
  ]

  lifecycle {

    postcondition {
      condition     = self.object.status.conditions[0].message == null
      error_message = "The status message will be null if the controller successfully unsealed the secret."
    }

    postcondition {
      condition     = self.object.status.conditions[0].status == "True"
      error_message = "The status will be 'True' if the controller successfully unsealed the secret."
    }

    postcondition {
      condition     = self.object.status.conditions[0].type == "Synced"
      error_message = "The status type is expected to be 'Synced' if the controller successfully unsealed the secret."
    }
  }
}
