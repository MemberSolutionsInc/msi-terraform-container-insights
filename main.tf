## -----------------------------------------------------------------------------
## ECS - account-level Container Insights default
##
## aws_ecs_account_setting_default sets the containerInsights default for the
## CURRENT AWS ACCOUNT + REGION that the provider is configured for. Once set,
## every ECS cluster subsequently created in that account/region inherits this
## value unless the cluster's own `setting` block explicitly overrides it.
## This does NOT retroactively change clusters that already exist.
## -----------------------------------------------------------------------------
resource "aws_ecs_account_setting_default" "container_insights" {
  count = var.enable_ecs_container_insights ? 1 : 0

  name  = "containerInsights"
  value = var.container_insights_value
}

## -----------------------------------------------------------------------------
## ECS - per-cluster override via AWS CLI workaround
##
## There is no native Terraform resource that can update the containerInsights
## setting on an ECS cluster that this module does not also create (the
## `setting` block lives on `aws_ecs_cluster` itself, and that cluster is owned
## by another config). To bring an EXISTING cluster in line with the desired
## Container Insights value without importing/adopting it here, this module
## shells out to `aws ecs update-cluster-settings` for each name in
## var.ecs_cluster_names. See README for the tradeoffs of this approach.
## -----------------------------------------------------------------------------
resource "null_resource" "ecs_cluster_container_insights" {
  for_each = toset(var.ecs_cluster_names)

  triggers = {
    cluster_name             = each.value
    container_insights_value = var.container_insights_value
  }

  provisioner "local-exec" {
    command = "aws ecs update-cluster-settings --cluster ${each.value} --settings name=containerInsights,value=${var.container_insights_value}"
  }
}

## -----------------------------------------------------------------------------
## EKS - amazon-cloudwatch-observability add-on (enhanced observability /
## Container Insights for EKS)
## -----------------------------------------------------------------------------
resource "aws_eks_addon" "cloudwatch_observability" {
  for_each = var.enable_eks_container_insights ? toset(var.eks_cluster_names) : toset([])

  cluster_name                = each.value
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = var.eks_addon_version
  resolve_conflicts_on_update = "OVERWRITE"
}
