variable "name" {
  description = "Base name used for all resources (prefix)."
  type        = string
  default     = "blogapp"
}

variable "location" {
  description = "Azure region to deploy resources into."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-blogapp"
}

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
  default     = "vnet-blogapp"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_aks" {
  description = "Subnet CIDR for AKS nodes."
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_private_endpoints" {
  description = "Subnet CIDR for Private Endpoints (Key Vault, Storage, SQL)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "node_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "Initial node count."
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum number of nodes for autoscaling."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of nodes for autoscaling."
  type        = number
  default     = 5
}

variable "acr_sku" {
  description = "SKU of Azure Container Registry."
  type        = string
  default     = "Basic"
}
variable "enable_auto_scaling" {
  description = "Enable or disable autoscaling for the user node pool."
  type        = bool
  default     = true
}

variable "sql_admin_username" {
  description = "Administrator username for Azure SQL Server."
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "Administrator password for Azure SQL Server"

}

variable "admin_group_object_id" {
  description = "Azure AD group object ID for AKS admins"
  type        = string
}

 
