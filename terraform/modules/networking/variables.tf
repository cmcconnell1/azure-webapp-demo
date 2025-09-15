variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "name_prefix"         { type = string }
variable "vnet_cidr"           { type = string }
variable "subnet_app_cidr"     { type = string }
variable "subnet_pe_cidr"      { type = string }
variable "tags"                { type = map(string) default = {} }

