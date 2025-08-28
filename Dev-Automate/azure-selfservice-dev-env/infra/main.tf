
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "dev-rg"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "dev-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "dev-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "dev-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "dev-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "dev-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_log_analytics_workspace" "log" {
  name                = "dev-log"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# -------- Auto Shutdown ---------
resource "azurerm_dev_test_lab" "lab" {
  name                = "devlab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_dev_test_global_schedule" "auto_shutdown" {
  name                   = "shutdown-${azurerm_linux_virtual_machine.vm.name}"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  lab_name               = azurerm_dev_test_lab.lab.name
  lab_virtual_machine_id = azurerm_linux_virtual_machine.vm.id

  daily_recurrence_time = "2000" # 8:00 PM UTC shutdown
  time_zone_id          = "UTC"
  notification_settings {
    enabled = true
    email   = var.owner_email
  }
}

# -------- Budget Alert ---------
resource "azurerm_consumption_budget_resource_group" "monthly_budget" {
  name                = "dev-budget"
  resource_group_id = azurerm_resource_group.rg.id
  amount              = 50   # USD monthly budget
  time_grain          = "Monthly"

  time_period {
    start_date = "2025-08-01T00:00:00Z"
    end_date   = "2026-08-01T00:00:00Z"
  }

  notification {
    enabled   = true
    threshold = 80.0   # alert at 80% spend
    operator  = "GreaterThan"
    contact_emails = [
      var.owner_email
    ]
  }
}
