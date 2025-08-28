# terraform.tfvars

# Required values
sql_admin_password    = "Password123!" 
admin_group_object_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" #  AAD group Object ID

# Optional (override if needed)
name                 = "blogapp"
location             = "eastus"
resource_group_name  = "rg-blogapp"
vnet_name            = "vnet-blogapp"
vnet_address_space   = ["10.0.0.0/16"]
subnet_aks           = "10.0.1.0/24"
subnet_private_endpoints = "10.0.2.0/24"

node_size            = "Standard_DS2_v2"
node_count           = 2
node_min_count       = 2
node_max_count       = 5
acr_sku              = "Basic"

sql_admin_username   = "sqladminuser"
