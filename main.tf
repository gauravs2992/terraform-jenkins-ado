terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "jenkins" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "jenkins" {
  name                = "${var.name_prefix}-vnet"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  tags                = var.tags
}

resource "azurerm_subnet" "jenkins" {
  name                 = "${var.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.jenkins.name
  virtual_network_name = azurerm_virtual_network.jenkins.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "jenkins" {
  name                = "${var.name_prefix}-nsg"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh-from-admin"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = var.admin_source_cidr
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.jenkins.name
  network_security_group_name = azurerm_network_security_group.jenkins.name
}

resource "azurerm_network_security_rule" "jenkins_web" {
  name                        = "allow-jenkins-from-admin"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = var.admin_source_cidr
  destination_port_range      = "8080"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.jenkins.name
  network_security_group_name = azurerm_network_security_group.jenkins.name
}

resource "azurerm_public_ip" "jenkins" {
  name                = "${var.name_prefix}-public-ip"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "jenkins" {
  name                = "${var.name_prefix}-nic"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jenkins.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins.id
  }
}

resource "azurerm_network_interface_security_group_association" "jenkins" {
  network_interface_id      = azurerm_network_interface.jenkins.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                            = "${var.name_prefix}-vm"
  computer_name                   = var.name_prefix
  resource_group_name             = azurerm_resource_group.jenkins.name
  location                        = azurerm_resource_group.jenkins.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.jenkins.id]
  custom_data                     = base64encode(file("${path.module}/cloud-init.yaml"))
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}