  terraform {
    required_version = ">= 1.5.0"
    required_providers {
      azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 3.111"
      }
    }
  }
  provider "azurerm" { 
    features {} 
    }

  # ---------- Resource Group ----------
  resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = var.location
  }

  # ---------- Networking ----------
  resource "azurerm_virtual_network" "vnet" {
    name                = var.vnet_name
    address_space       = var.vnet_address_space
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
  }

  resource "azurerm_subnet" "sub_aks" {
    name                 = "snet-aks"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = [var.subnet_aks]
  }

  resource "azurerm_subnet" "sub_priv" {
    name                                      = "snet-priv"
    resource_group_name                       = azurerm_resource_group.rg.name
    virtual_network_name                      = azurerm_virtual_network.vnet.name
    address_prefixes     = [var.subnet_private_endpoints]
    private_endpoint_network_policies         = "Disabled"
  }

  # ---------- ACR ----------
  resource "azurerm_container_registry" "acr" {
    name                = "${var.name}acr${substr(replace(uuid(),"-",""),0,6)}"
    resource_group_name = azurerm_resource_group.rg.name
    location            = var.location
    sku                 = "Basic"
    admin_enabled       = false
  }


  resource "azurerm_log_analytics_workspace" "law" {
    name                = "${var.name}-law"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = "PerGB2018"
    retention_in_days   = 30
  }


  # ---------- AKS Cluster ----------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.name}-aks"

  identity {
    type = "SystemAssigned"
  }

  # --- system node pool (default, fixed size) ---
  default_node_pool {
    name           = "system"
    vm_size        = "Standard_DS2_v2"
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.sub_aks.id

    node_labels = {
      "nodepool" = "system"
    }

    upgrade_settings {
      max_surge = "33%"
    }
  }

  #  Azure AD integration (new syntax)
  azure_active_directory_role_based_access_control {
  azure_rbac_enabled     = true
  admin_group_object_ids = [var.admin_group_object_id]
}


  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "calico"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  depends_on = [azurerm_virtual_network.vnet]
}

# ---------- User Node Pool (with Autoscaler) ----------
resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                  = "usernp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_DS2_v2"
  vnet_subnet_id        = azurerm_subnet.sub_aks.id

  enable_auto_scaling = var.enable_auto_scaling 
  min_count           = var.node_min_count
  max_count           = var.node_max_count

  node_labels = {
    "nodepool" = "user"
  }
}

  # Allow AKS kubelet to pull from ACR
  resource "azurerm_role_assignment" "aks_acr_pull" {
    scope                = azurerm_container_registry.acr.id
    role_definition_name = "AcrPull"
    principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  }

  # ---------- Storage Account (for media) ----------
  resource "azurerm_storage_account" "sa" {
    name                             = "${var.name}media${substr(replace(uuid(),"-",""),0,6)}"
    resource_group_name              = azurerm_resource_group.rg.name
    location                         = var.location
    account_tier                     = "Standard"
    account_replication_type         = "LRS"
    allow_nested_items_to_be_public  = false
    min_tls_version                  = "TLS1_2"
    network_rules { default_action = "Deny" }
  }

  # ---------- Key Vault ----------
  data "azurerm_client_config" "cur" {}
  resource "azurerm_key_vault" "kv" {
    name                        = "${var.name}-kv-${substr(replace(uuid(),"-",""),0,6)}"
    location                    = var.location
    resource_group_name         = azurerm_resource_group.rg.name
    tenant_id                   = data.azurerm_client_config.cur.tenant_id
    sku_name                    = "standard"
    purge_protection_enabled    = true
    soft_delete_retention_days  = 7
    network_acls {
      default_action = "Deny"
      bypass         = "AzureServices"
    }
  }
  # ---------- Azure SQL Server ----------
  resource "azurerm_mssql_server" "sql" {
    name                         = "${var.name}-sql-${substr(replace(uuid(),"-",""),0,6)}"
    resource_group_name          = azurerm_resource_group.rg.name
    location                     = var.location
    version                      = "12.0"
    administrator_login          = var.sql_admin_username
    administrator_login_password = var.sql_admin_password

    minimum_tls_version = "1.2"
  }

  # ---------- Azure SQL Database ----------
  resource "azurerm_mssql_database" "sqldb" {
    name           = "${var.name}-db"
    server_id      = azurerm_mssql_server.sql.id
    sku_name       = "GP_S_Gen5_2"   # General Purpose, Serverless, 2 vCores
    max_size_gb    = 5
    zone_redundant = false
  }

  # ---------- Private Endpoint for SQL ----------
  resource "azurerm_private_dns_zone" "sqlz" {
    name                = "privatelink.database.windows.net"
    resource_group_name = azurerm_resource_group.rg.name
  }

  resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
    name                  = "sql-link"
    resource_group_name   = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.sqlz.name
    virtual_network_id    = azurerm_virtual_network.vnet.id
  }

  resource "azurerm_private_endpoint" "pe_sql" {
    name                = "${var.name}-pe-sql"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id           = azurerm_subnet.sub_priv.id

    private_service_connection {
      name                           = "sql-conn"
      private_connection_resource_id = azurerm_mssql_server.sql.id
      is_manual_connection           = false
      subresource_names              = ["sqlServer"]
    }
    private_dns_zone_group {
      name                 = "pdz"
      private_dns_zone_ids = [azurerm_private_dns_zone.sqlz.id]
    }
  }


  # ---------- Private DNS Zones (for private endpoints) ----------
  resource "azurerm_private_dns_zone" "blob" {
    name                = "privatelink.blob.core.windows.net"
    resource_group_name = azurerm_resource_group.rg.name
  }
  resource "azurerm_private_dns_zone" "kvz" {
    name                = "privatelink.vaultcore.azure.net"
    resource_group_name = azurerm_resource_group.rg.name
  }

  resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
    name                  = "blob-link"
    resource_group_name   = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.blob.name
    virtual_network_id    = azurerm_virtual_network.vnet.id
  }
  resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
    name                  = "kv-link"
    resource_group_name   = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.kvz.name
    virtual_network_id    = azurerm_virtual_network.vnet.id
  }

  # ---------- Private Endpoints ----------
  resource "azurerm_private_endpoint" "pe_blob" {
    name                = "${var.name}-pe-blob"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id           = azurerm_subnet.sub_priv.id

    private_service_connection {
      name                           = "blob-conn"
      private_connection_resource_id = azurerm_storage_account.sa.id
      is_manual_connection           = false
      subresource_names              = ["blob"]
    }
    private_dns_zone_group {
      name                 = "pdz"
      private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
    }
  }

  resource "azurerm_private_endpoint" "pe_kv" {
    name                = "${var.name}-pe-kv"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id           = azurerm_subnet.sub_priv.id

    private_service_connection {
      name                           = "kv-conn"
      private_connection_resource_id = azurerm_key_vault.kv.id
      is_manual_connection           = false
      subresource_names              = ["vault"]
    }
    private_dns_zone_group {
      name                 = "pdz"
      private_dns_zone_ids = [azurerm_private_dns_zone.kvz.id]
    }
  }
  
  # ---------- Public IP for Ingress ----------
resource "azurerm_public_ip" "aks_ingress" {
  name                = "${var.name}-ingress-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---------- Public DNS Zone ----------
resource "azurerm_dns_zone" "dns" {
  name                = "example.com" # CHANGE to your domain
  resource_group_name = azurerm_resource_group.rg.name
}

# ---------- Role assignment (allow AKS to modify DNS zone) ----------
resource "azurerm_role_assignment" "aks_dns" {
  scope                = azurerm_dns_zone.dns.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}


  output "aks_name"        { value = azurerm_kubernetes_cluster.aks.name }
  output "acr_login"       { value = azurerm_container_registry.acr.login_server }
  output "kv_name"         { value = azurerm_key_vault.kv.name }
  output "storage_name"    { value = azurerm_storage_account.sa.name }
  # ---------- Outputs for Ingress ----------
output "ingress_public_ip" {
  description = "Public IP address for the NGINX ingress controller"
  value       = azurerm_public_ip.aks_ingress.ip_address
}

output "dns_zone_name" {
  description = "DNS zone name for ingress"
  value       = azurerm_dns_zone.dns.name
}
