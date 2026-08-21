output "ecs_account_container_insights_value" {
  description = "The Container Insights value applied as the ECS account-level default in this account/region, or null if not enabled."
  value       = var.enable_ecs_container_insights ? aws_ecs_account_setting_default.container_insights[0].value : null
}

output "ecs_clusters_updated_via_cli" {
  description = "Names of existing ECS clusters whose containerInsights setting was updated in place via the `aws ecs update-cluster-settings` CLI workaround."
  value       = [for c in null_resource.ecs_cluster_container_insights : c.triggers.cluster_name]
}

output "eks_addon_statuses" {
  description = "Map of EKS cluster name to the amazon-cloudwatch-observability add-on status."
  value       = { for k, addon in aws_eks_addon.cloudwatch_observability : k => addon.status }
}

output "eks_addon_arns" {
  description = "Map of EKS cluster name to the amazon-cloudwatch-observability add-on ARN."
  value       = { for k, addon in aws_eks_addon.cloudwatch_observability : k => addon.arn }
}
