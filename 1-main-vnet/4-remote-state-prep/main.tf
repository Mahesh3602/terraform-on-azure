#Terraform config
#################

terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 2.0"
    }
  }
}
#####################################################################

#variable
##########

variable "resource_group_name" {
    type = string
    default = "itma-state"
}

variable "location" {
    type = string
    default = "eastus"
}

variable "naming_prefix" {
  type = string
  default = "itma"
}

#########################################################

#Providers
##########
provider "azurerm" {
  features {}
}



#########################################################

#Resources

resource "random_integer" "sa_num" {
    min = 10000
    max = 99999
}

resource "azurerm_resource_group" "setup" {
    name = var.resource_group_name
    location = var.location
}

resource "azurerm_storage_account" "sa" {
    name = "${lower(var.naming_prefix)}${random_integer.sa_num.result}"
    resource_group_name = azurerm_resource_group.setup.name
    location = var.location
    account_tier = "Premium"
    account_replication_type =  "LRS"
}

resource "azurerm_storage_container" "ct" {
    name = "terraform-state"
    storage_account_name = azurerm_storage_account.sa.name
}

data "azurerm_storage_account_sas" "state" {
  connection_string = azurerm_storage_account.sa.primary_connection_string
  https_only = true
  
  resource_types {
    service = true
    container = true
    object = true
  }

  services {
    blob = true
    queue = false
    table = false
    file = false
  }
  
  start = timestamp()
  expiry = timeadd(timestamp(), "17520h")

  permissions {
    read = true
    write = true
    delete = true
    list = true
    add = true
    create = true
    update = true
    process = false

  }

}

##############################################################################

#Provisioners
##############

resource "local_file" "post-config" {
    depends_on = [azurerm_storage_container.ct]
    
   filename = "${path.module}/backend-config.txt"
   content = <<EOF
storage_account_name = "${azurerm_storage_account.sa.name}"
container_name = "terraform-state"
key = "terraform.tfstate"
sas_token = "${data.azurerm_storage_account_sas.state.sas}"
  EOF
}
######################################################################################

#outputs
########

output "storage_account_name" {
    value = azurerm_storage_account.sa.name
}

output "resource_group_name" {
    value = azurerm_resource_group.setup.name
}