variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
}

variable "location" {
  description = "Localização dos recursos (ex: brazilsouth)"
  type        = string
}

variable "cluster_name" {
  description = "Nome do AKS"
  type        = string
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}