# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_profile" {
  description = "The AWS profile name as set in the credentials file."
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
}

variable "vpc_id" {
  description = "The Amazon VPC ID."  
}

variable "vpc_subnet_id" {
  description = "The Amazon VPC subnet ID."
}

variable "vsphere_server" {
  description = "Specifies the IP address or the DNS name of the vSphere server to which you want to connect."
}

variable "vsphere_user" {
  description = "Specifies the user name you want to use for authenticating with the server."
}

variable "vsphere_password" {
  description = "Specifies the password you want to use for authenticating with the server."
}

variable "workload_vm_password" {
  description = "The password for the workload VM's admin user."
}

variable "workload_vm_template_name" {
  description = "The name of the VM template to clone for the workload VMs."
}

variable "file_gateway_vm_template_name" {
  description = "The name of the VM template to clone for the file gateway virtual appliances."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "num_labs" {
  description = "The number of lab environments to provision."
  default     = 10
}

variable "dns_servers" {
  description = "The list of DNS servers to configure for the lab VMs."
  type = "list"
  default = [
    "8.8.8.8",
    "8.8.4.4",
  ]
}

variable "domain_name" {
  description = "The domain name."
  default     = "aws.local"
}
