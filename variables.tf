variable "enable_ecs_container_insights" {
  description = <<-EOT
    Whether to set the ECS account-level default for Container Insights in the
    current account/region. This is an ACCOUNT-LEVEL setting: when true, it
    applies to every ECS cluster created afterward in this account/region
    unless that cluster explicitly overrides the setting itself. It does NOT
    retroactively change existing clusters. See README for details and cost
    implications.
  EOT
  type        = bool
  default     = false
}

variable "container_insights_value" {
  description = <<-EOT
    Value to apply for Container Insights, used both for the ECS account-level
    default (when enable_ecs_container_insights = true) and for the per-cluster
    CLI-workaround updates (when ecs_cluster_names is non-empty).
    Must be one of: "enabled", "enhanced", "disabled".
  EOT
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "enhanced", "disabled"], var.container_insights_value)
    error_message = "container_insights_value must be one of: \"enabled\", \"enhanced\", \"disabled\"."
  }
}

variable "ecs_cluster_names" {
  description = <<-EOT
    Names of existing ECS clusters (owned by other configs/modules) to update
    in place via the AWS CLI, setting their containerInsights cluster setting
    to var.container_insights_value. This is a workaround: no native Terraform
    resource can update Container Insights on a cluster this module does not
    also create. See README for details.
  EOT
  type        = list(string)
  default     = []
}

variable "enable_eks_container_insights" {
  description = <<-EOT
    Whether to install the amazon-cloudwatch-observability EKS add-on (enhanced
    observability / Container Insights for EKS) on each cluster listed in
    eks_cluster_names.
  EOT
  type        = bool
  default     = false
}

variable "eks_cluster_names" {
  description = "Names of existing EKS clusters to install the amazon-cloudwatch-observability add-on on."
  type        = list(string)
  default     = []
}

variable "eks_addon_version" {
  description = <<-EOT
    Version of the amazon-cloudwatch-observability add-on to install. Defaults
    to null, which lets AWS select the default compatible version for the
    cluster's Kubernetes version.
  EOT
  type        = string
  default     = null
}
