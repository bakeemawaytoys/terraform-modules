# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 8.0.0

### Upgrade Notes

The kubectl provider's source has changed from `gavinbunney/kubectl` to `alekc/kubectl`.  To upgrade the module to version 8.0+, the following command must be run to change the source in the Terraform state file.

```shell
terraform state replace-provider gavinbunney/kubectl alekc/kubectl
```

### Changed

- **Breaking Change**: The kubectl provider's source has been changed from [`gavinbunney/kubectl`](https://registry.terraform.io/providers/gavinbunney/kubectl/latest) to [`alekc/kubectl`](https://registry.terraform.io/providers/alekc/kubectl/latest).  The `alekc/kubectl` implementation is a fork of `gavinbunney/kubectl`.  It fixes a number of bugs and updates its dependencies to newer versions.  A new version of the `gavinbunney/kubectl` implementation hasn't been released in two years and, based on the lack of activity in its Github project, appears to be dead.  Given that the provider is for managing K8s resources, it is important to use a version that is kept up-to-date with the K8s API.

## 7.1.1

### Fixed

- The `helmHookAnnotations` value has been added to the Helm release and set to `false` to account for [changes to the way the Helm chart installs custom resources](https://github.com/vmware-tanzu/helm-charts/pull/490) in 5.x.

## 7.1.0

### Important Upgrade Note

Prior to version 5.x of the Helm chart, the `schedule` resource and `backupstoragelocation` resources created by the chart were created by Helm hooks.  After version 5.x, they are added to the release's manifest.  Upgrades will fail unless the `meta.helm.sh/release-name: velero` and `meta.helm.sh/release-namespace: velero` annotations are added to the resources to trick Helm into believing that it created the resources.  See <https://github.com/vmware-tanzu/helm-charts/pull/490> for more details.

### Added

- The module now supports Velero 1.12 (Helm chart version 5.1.x) in addition to Velero 1.11.
- The module now creates two new Kubernetes cluster roles, `velero-admin` and `velero-view`, to allow a subject to manage and view, respectively, the Velero custom resources.  Both cluster roles have been labeled to enable [cluster role aggregation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles).  The `velero-admin` role aggregates to the `admin` default cluster role and the `velero-view` role aggregates to `view` default cluster role.

## 7.0.0

### Added

- The module now supports Velero 1.11 (Helm chart version 4.4.x).
- The `storage_location_name` output has been added to expose the name of the `BackupStorageLocation` Kubernetes resource that corresponds to the S3 bucket managed by this module.  It can be useful for defining backup schedules outside of the module.

### Changed

- **Breaking Change**: The minimum supported Terraform version is now 1.5.
- **Breaking Change**: The minimum supported AWS provider version is now 5.0.
- Modified the storage bucket's lifecycle policy to no longer keep one non-concurrent version.  With the previous policy, the size of the bucket would always increase because objects would never be completely deleted.
- Modified the Helm release values to account for [changes made to the chart to support multiple storage locations](https://github.com/vmware-tanzu/helm-charts/pull/413).
- Disabled backend storage location validation to reduce the noise in the pod logs.

### Removed

- **Breaking Change**: Dropped support for Velero 1.10 (Helm chart version 3.1.x) due to the breaking changes made to the Helm chart between 3.1 and 4.4.  Supporting both versions add too much complexity to the module.

## 6.0.0

### Added

- The module now supports Velero 1.10 (Helm chart version 3.1.x).
- Storage analytics have been enabled on the S3 bucket.
- The `enable_goldilocks` variable has been added to enable or disable integration with [Goldilocks](https://github.com/FairwindsOps/goldilocks).  When set to `true`, the `goldilocks.fairwinds.com/enabled` label is added to the namespace to instruct Goldilocks to monitor the Velero deployment.
- The `pod_security_standards` variable has been added to configure the Pod Security Standards namespace labels.  It defaults to enforcing the Restricted standard.
- A pod security context has been added to the Velero pod.  It is configured to ensure it comply with the Restricted pod security standard.
- A security context has been added to the init container to ensure it complies with the Restricted pod security standard.

### Changed

- **Breaking Change**: The `cluster_name` and `service_account_oidc_provider_arn` variables have been combined into the `eks_cluster` variable to make the module consistent with other modules in this project.  The new variable includes the `service_account_oidc_audience_variable` and `service_account_oidc_subject_variable` attributes to eliminate the need to use a data resource to construct the condition keys on the IAM role's trust policy.  The names of all attributes on the `eks_cluster` variable match the names of the [eks-cluster module's](../eks-cluster/) outputs.
- **Breaking Change**: The minimum supported Terraform version has been changed from 1.3 to 1.4.

### Removed

- **Breaking Change**: Dropped support for Velero 1.9.

## 5.2.0

### Added

- Integration with AlertManager is now supported.  The optional `enable_prometheus_rules` variable controls the deployment of [a PrometheusRules resource](https://prometheus-operator.dev/docs/user-guides/alerting/#deploying-prometheus-rules).  The resource contains the example rules from the Helm chart's values file.
- The module now supports the option to deploy Grafana dashboards for cert-manager metrics.  The dashboards are deployed in Kubernetes configmaps to allow [Grafana's sidecar to discover them](https://github.com/grafana/helm-charts/tree/main/charts/grafana#sidecar-for-dashboards).
- The `grafana_dashboard_config` variable has been added to configure the Grafana dashboard deployment.  Its type matches the structure of the `dashboard_config` output in the kube-prometheus-stack module for easy integration.
- The [Velero Stats Grafana dashboard](https://grafana.com/grafana/dashboards/11055-kubernetes-addons-velero-stats/) is included in the module.

## 5.1.0

### Changed

- The module no longer downloads the CRD files from Github because of Github API rate limits.  As more and more of the modules in this project were modified to download CRD files, the risk of hitting the rate limit increased.  To avoid the issue, the CRDs for the supported chart versions are now bundled in the module.  While this increases the maintenance burden of this module, it eliminates a pain point when consuming the module.
- The `chart_version` variable is now restircted to the Helm chart versions whose CRDs are bundled in the module.

### Removed

- The `http` provider is no longer required by the module.  It was only used to download the CRD files.

## 5.0.0

### Upgrade Guide

The Velero Customer Resource Definition resources are now managed by Terraform.  As part of the upgrade process, the CRDs must be imported into the Terraform state.  The following script can be used to import them by replacing `example` with the actual name of your module.

```shell
#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

terraform import 'module.example.kubectl_manifest.crd["backups.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//backups.velero.io
terraform import 'module.example.kubectl_manifest.crd["backupstoragelocations.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//backupstoragelocations.velero.io
terraform import 'module.example.kubectl_manifest.crd["deletebackuprequests.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//deletebackuprequests.velero.io
terraform import 'module.example.kubectl_manifest.crd["downloadrequests.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//downloadrequests.velero.io
terraform import 'module.example.kubectl_manifest.crd["podvolumebackups.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//podvolumebackups.velero.io
terraform import 'module.example.kubectl_manifest.crd["podvolumerestores.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//podvolumerestores.velero.io
terraform import 'module.example.kubectl_manifest.crd["resticrepositories.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//resticrepositories.velero.io
terraform import 'module.example.kubectl_manifest.crd["restores.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//restores.velero.io
terraform import 'module.example.kubectl_manifest.crd["schedules.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//schedules.velero.io
terraform import 'module.example.kubectl_manifest.crd["serverstatusrequests.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//serverstatusrequests.velero.io
terraform import 'module.example.kubectl_manifest.crd["volumesnapshotlocations.yaml"]' apiextensions.k8s.io/v1//CustomResourceDefinition//volumesnapshotlocations.velero.io
```

### Added

- Node selectors and tolerations can now be configured with the optional `node_selector` and `node_tolerations` variables.
- The `http` and `kubectl` Terraform providers have been added to the list of providers required by the module.
- Support for installing a [`ServiceMonitor` resource](https://prometheus-operator.dev/docs/operator/api/#monitoring.coreos.com/v1.ServiceMonitor) to enable metrics scraping with the Prometheus Operator is now available.  The new `enable_service_monitor` variable controls its installation
- A default set of tolerations have been added to the Velero pod spec for the `kubernetes.io/arch` node label to better support running in clusters with mixed architectures.

### Changed

- **Breaking Change**: The Velero custom resource definitions are now managed directly by Terraform instead of delegating management to the Helm chart.  The Helm chart hooks that upgrade and delete the CRDs depend on the bitnami/kubectl container image.  The image is not available for ARM architectures.  Therefore, the hooks do not work on Graviton EC2 instances.  While there are other kubectl images available none of them are published by known sources.  Prior to upgrading to this version of the module, the CRD resources must be imported into the Terraform state file.
- **Breaking Change**: The minimum Terraform version is now 1.3 due to the use of the optional object attributes added to variable type definitions.
- Validation has been added to the `labels` and `namespace` variables.
- The `pod_resources` and `schedules` variables have been reworked to make use of optional object attributes.

### Removed

- The `clean_up_crds` and `kubectl_image_registry` variables have been removed because they are no longer needed with the change to the CRD management.

## 4.0.0

### Update

- **Update to 1.9**: Update variables and documentation to allow for 2.32.x charts and update the aws velero plugin to 1.5.

## 3.0.0

### Changed

- **Breaking Change**: The type constraint on the `schedules` variable has been modified to restrict the attributes allowed on the schedule template.  The `snapshotVolumes`, `storageLocation`, and `volumeSnapshotLocations` attributes are no longer supported.  Instead the module, adds them to every schedule specified in the variable.  This ensures that every schedule has the correct storage location set and does not enable volume snapshots.

## 2.1.1

### Fixed

- Added the AWS region to the backup storage configuration so that the AWS plug-in doesn't have to determine the region dynamically.
- Added the AWS region to the volume snapshot configuration as it is required by the AWS plug-in.  Without it, an error like the one shown below appears in the logs.  The error appears during the back up process.

    ```json
    {
        "backup": "velero/velero-scheduled-backup-20220720110014",
        "error.file": "/go/src/velero-plugin-for-aws/velero-plugin-for-aws/volume_snapshotter.go:82",
        "error.function": "main.(*VolumeSnapshotter).Init",
        "error.message": "rpc error: code = Unknown desc = missing region in aws configuration",
        "level": "error",
        "logSource": "pkg/backup/item_backupper.go:446",
        "msg": "Error getting volume snapshotter for volume snapshot location",
        "name": "pvc-d0dcec41-8f40-45db-aee6-73ccf56dad1a",
        "namespace": "",
        "persistentVolume": "pvc-d0dcec41-8f40-45db-aee6-73ccf56dad1a",
        "resource": "persistentvolumes",
        "time": "2022-07-20T11:00:39Z",
        "volumeSnapshotLocation": "default"
    }
    ```

## 2.1.0

### Fixed

- Added the `tags` value to the back-ups bucket

### Added

- Enabled versioning, bucket logging, and request metrics on the back-ups bucket.
- Configured an S3 lifecycle policy to clean up non-concurrent object versions after seven days.  No rule is needed for current object versions because Velero manages them.
- Set the `app.kubernetes.io/instance` and `app.kubernetes.io/name` labels on the namespace to align with the labels on the resources managed by Helm.

## 2.0.0

### Changed

- Limited the allowed values of the `chart_version` variable to values in the 2.28 or 2.29 releases to restricted the supported Velero versions to 1.8.x.  Version [1.9](https://github.com/vmware-tanzu/velero/releases/tag/v1.8.0) that need to be reviewed before allowing the chart to support it.
- **Breaking Change**: The `clean_up_crds` variable has been added to determine if Helm should run the job to clean up CRDs.  It corresponds to the `cleanUpCRDs` value of the Helm chart.  The `cleanUpCRDs` value had previously been hardcoded to `true` but it now defaults to `false`.
- **Breaking Change**: The storage bucket now has a policy to require requests to go over HTTPS.
- **Breaking Change**: If the `create_namespace` is set to `true`, Terraform will now create and manage the namespace instead of allowing Helm to do it.  This ensures that the namespace is removed if the module is removed.  When upgrading a module call to 2.0.0 or later with `create_namespace` set to `true`, the namespace resource must be imported into the terraform state.

    For example, if the a module call to upgrade to 2.0.0 looks like the following ...

    ```hcl
    module "existing_module_call" {
        source = ".../velero"

        create_namespace = true
        namespace = "foo"
    }
    ```

    ... then the command to import the namespace resource would look like the following.

    ```shell
    terraform import 'module.existing_module_call.kubernetes_namespace_v1.velero["foo"]' foo
    ```

### Added

- The optional variables `kubectl_image_registry` and `velero_image_registry` have been added to allow for pulling images from alternative registries such as an ECR pull-through cache.  They both default to the previously hardcoded values.
- Labels and resource requests/limits have been added to the kubectl pod that runs Helm jobs.
- The values in the `labels` are now applied to the Velero pods.
- The values in the `labels` are now applied to the Velero deployment.
- Added the `bucket_name`, `bucket_arn`, `service_account_role_name`, and `service_account_role_arn` outputs.

## 1.0.0

### Added

- Initial release
