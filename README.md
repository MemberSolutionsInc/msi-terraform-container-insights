# msi-terraform-container-insights

Enables CloudWatch Container Insights for ECS (account-level default) and EKS
(enhanced observability add-on), so that container-level CPU/memory/restart
metrics (`CpuUtilized`, `CpuReserved`, `MemoryUtilized`, `MemoryReserved`,
`RestartCount`, etc.) are emitted to CloudWatch.

This module is one of a set of independently-versioned modules that make up
MSI's CloudWatch observability initiative. It only turns metric emission on.
The sibling module [`msi-terraform-cloudwatch-alarms`](https://github.com/MemberSolutionsInc/msi-terraform-cloudwatch-alarms)
consumes those metrics to create alarms. Splitting them lets you bump alarm
thresholds without forcing a version bump (or blast-radius) on the thing that
turns metrics on in the first place, and vice versa.

## Cost callout

**Container Insights is not free and is not enabled by default anywhere in
this org's monitoring standard.** Standard Container Insights and, especially,
EKS "enhanced observability" incur additional CloudWatch charges (extra
metrics, higher-resolution data, and for enhanced observability, additional
per-cluster costs). Per the org standard, enabling it requires an **explicit,
per-account (ECS) or per-cluster (ECS/EKS) decision** — this module never
enables anything unless you opt in via its `enable_*` variables. Do not wire
this module in with `enable_ecs_container_insights = true` or
`enable_eks_container_insights = true` as a blanket default; decide per
account/cluster and document why.

## ECS: account-level default vs. per-cluster CLI workaround

ECS Container Insights can be controlled in two different ways, and this
module supports both because they solve different problems:

1. **Account-level default** (`aws_ecs_account_setting_default`, gated by
   `enable_ecs_container_insights`): this is an **account + region** setting.
   Once applied, it becomes the default `containerInsights` value for every
   ECS cluster created **afterward** in that account/region, unless the
   cluster itself overrides the setting. It has **no effect on clusters that
   already exist** and does not retroactively change anything. Think of it as
   "get this right going forward," not "fix everything today."

2. **Per-existing-cluster override** (`ecs_cluster_names` + the AWS CLI
   workaround, described below): to change Container Insights on a cluster
   that **already exists** and is owned/created by a different Terraform
   config, there is no native Terraform resource this module can use. The
   `containerInsights` value lives inside that cluster's own `setting` block
   on the `aws_ecs_cluster` resource, and Terraform can only manage that block
   from within the same configuration that owns (created, or has imported)
   the cluster. Since this module intentionally does not own other teams'
   clusters (and importing every consumer's clusters into this module would
   defeat the point of a small, reusable module), it instead falls back to a
   `null_resource` + `local-exec` provisioner that runs:

   ```
   aws ecs update-cluster-settings --cluster <name> --settings name=containerInsights,value=<value>
   ```

   for each cluster name in `ecs_cluster_names`. This is a deliberate,
   documented workaround, not an oversight. Caveats:
   - It requires the AWS CLI to be installed and authenticated wherever
     `terraform apply` runs (e.g. the CI runner), with `ecs:UpdateClusterSettings`
     permission on the target cluster(s).
   - It is not visible in `terraform plan` as a real resource diff beyond the
     `null_resource` trigger change, and Terraform cannot read back /
     reconcile drift the way it would for a natively-managed attribute.
   - The `null_resource` re-runs whenever `cluster_name` or
     `container_insights_value` changes (see its `triggers`), not on every
     apply.

## EKS: `amazon-cloudwatch-observability` add-on

For EKS, Container Insights (with "enhanced observability" metrics) is
delivered as a managed EKS add-on, `amazon-cloudwatch-observability`, which
*is* natively supported by Terraform via `aws_eks_addon` — no CLI workaround
needed. This module creates one `aws_eks_addon` per name in
`eks_cluster_names` when `enable_eks_container_insights = true`. Leave
`eks_addon_version` as `null` (the default) to let AWS pick the default
compatible version for the cluster's Kubernetes version, or pin an explicit
version. `resolve_conflicts_on_update` is hardcoded to `"OVERWRITE"` so that
Terraform-managed configuration wins over any manual/out-of-band changes to
the add-on.

## Usage

```hcl
module "container_insights" {
  source = "git::https://github.com/MemberSolutionsInc/msi-terraform-container-insights.git?ref=v0.1.0"

  # ECS account-level default — applies to new clusters in this account/region
  enable_ecs_container_insights = true
  container_insights_value      = "enabled"

  # ECS existing clusters that need to be brought in line today
  ecs_cluster_names = [
    "prod-api-cluster",
    "prod-worker-cluster",
  ]

  # EKS enhanced observability add-on
  enable_eks_container_insights = true
  eks_cluster_names = [
    "prod-eks-cluster",
  ]
  eks_addon_version = null
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `enable_ecs_container_insights` | Set the ECS account-level `containerInsights` default in the current account/region. Affects clusters created afterward unless they override it themselves. | `bool` | `false` |
| `container_insights_value` | Value applied for Container Insights — used for both the ECS account default and the per-cluster CLI-workaround updates. Must be `"enabled"`, `"enhanced"`, or `"disabled"`. | `string` | `"enabled"` |
| `ecs_cluster_names` | Names of existing ECS clusters to update in place via the `aws ecs update-cluster-settings` CLI workaround. | `list(string)` | `[]` |
| `enable_eks_container_insights` | Install the `amazon-cloudwatch-observability` add-on on each cluster in `eks_cluster_names`. | `bool` | `false` |
| `eks_cluster_names` | Names of existing EKS clusters to install the `amazon-cloudwatch-observability` add-on on. | `list(string)` | `[]` |
| `eks_addon_version` | Version of the `amazon-cloudwatch-observability` add-on. `null` lets AWS pick the default compatible version. | `string` | `null` |

## Outputs

| Name | Description |
|---|---|
| `ecs_account_container_insights_value` | The Container Insights value applied as the ECS account-level default, or `null` if not enabled. |
| `ecs_clusters_updated_via_cli` | Names of existing ECS clusters updated via the `aws ecs update-cluster-settings` CLI workaround. |
| `eks_addon_statuses` | Map of EKS cluster name to `amazon-cloudwatch-observability` add-on status. |
| `eks_addon_arns` | Map of EKS cluster name to `amazon-cloudwatch-observability` add-on ARN. |

## Requirements

| Name | Version |
|---|---|
| terraform | `~> 1.0` |
| aws provider | `~> 5.0` |
| AWS CLI (on the apply host, only if `ecs_cluster_names` is non-empty) | any recent version, with `ecs:UpdateClusterSettings` permission |
