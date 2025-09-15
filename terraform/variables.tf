variable "project_prefix" {
  description = "Project name prefix (e.g., webapp-demo)"
  type        = string
  default     = "webapp-demo"
}

variable "environment" {
  description = "Environment name (dev|stage|prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

# Networking inputs (for module-based layout)
variable "vnet_cidr" {
  description = "Virtual network address space"
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_app_integration_cidr" {
  description = "Subnet CIDR for App Service VNet integration"
  type        = string
  default     = "10.20.1.0/24"
}

variable "subnet_private_endpoints_cidr" {
  description = "Subnet CIDR for Private Endpoints"
  type        = string
  default     = "10.20.2.0/24"
}

variable "default_tags" {
  description = "Default resource tags"
  type        = map(string)
  default     = {}
}

locals {
  name_prefix = "${var.project_prefix}-${var.environment}"
}
