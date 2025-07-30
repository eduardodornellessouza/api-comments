terraform {
  backend "azurerm" {
    resource_group_name   = "terraform-rg"
    storage_account_name  = "tfstateeduardo20250730"
    container_name        = "tfstate"
    key                   = "infraestrutura.tfstate"
  }
}
