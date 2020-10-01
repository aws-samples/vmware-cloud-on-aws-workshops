# ---------------------------------------------------------------------------------------------------------------------
# Required parameters
# These variables do not have default values.
# ---------------------------------------------------------------------------------------------------------------------

variable aws_profile {
  description = "The AWS profile name as set in the credentials file."
}

variable aws_region {
  description = "The AWS region in which all resources will be created"
}

variable vpc_id {
  description = "The Amazon VPC ID."
}

variable vpc_subnet_id {
  description = "The Amazon VPC subnet ID."
}

variable vsphere_server {
  description = "Specifies the IP address or the DNS name of the vSphere server to which you want to connect."
}

variable vsphere_user {
  description = "Specifies the user name you want to use for authenticating with the server."
}

variable vsphere_password {
  description = "Specifies the password you want to use for authenticating with the server."
}

variable ubuntu_server_vm_template_name {
  description = "The name of the Ubuntu Server VM template to clone for the MySQL Server VM."
}

variable file_gateway_vm_template_name {
  description = "The name of the AWS File Gateway VM template to clone for the virtual appliance VM."
}

variable mysql_server_vm_username {
  description = "The username to use to authenticate to the MySQL Server VM over SSH. This user account must have sudo permissions."
}

variable mysql_server_vm_password {
  description = "The plaintext password to use to authenticate to the MySQL Server VM over SSH."
}

# ---------------------------------------------------------------------------------------------------------------------
# Optional parameters
# These variables have defaults, but can be overridden.
# ---------------------------------------------------------------------------------------------------------------------

variable datacenter_name {
  description = "The name of the vSphere datacenter to which the VMs will be deployed."
  default = "SDDC-Datacenter"
}

variable resource_pool_name {
  description = "The name of the vSphere resource pool to which the VMs will be deployed."
  default = "Compute-ResourcePool"
}

variable datastore_name {
  description = "The name of the vSAN/VMFS/NFS datastore to which the VMs' virtual disks will be deployed."
  default = "WorkloadDatastore"
}

variable network_name {
  description = "The name of the network segment or port group to which the VMs' vNICs will be connected."
  default = "sddc-cgw-network-1"
}

variable vm_folder_path {
  description = "The VM folder path to use."
  default = "Workloads/VMware {code} Connect 2020"
}

variable mysql_server_vm_name {
  description = "The name to use for the MySQL Server VM."
  default = "mysql-server"
}

variable file_gateway_name {
  description = "The name to use for the AWS File Gateway VM and the name prefix for the AWS resources."
  default = "file-gateway"
}

variable vm_version {
  # https://kb.vmware.com/s/article/2007240
  description = "The VM virtual hardware version."
  default = 17
}

variable thin_provisioned {
  description = "Thin provision virtual disks."
  default = true
}

variable domain_name {
  description = "The domain name."
  default = "localdomain"
}

variable storage_gateway_role_name {
  description = "The name to use for the Storage Gateway IAM role for permissions to access the S3 bucket."
  default = "AWSStorageGatewayS3BucketAccess"
}

variable s3_vpc_endpoint_name {
  description = "The name for the S3 VPC Gateway Endpoint for private communication with S3."
  default = "s3-vpce"
}

variable storage_gateway_vpc_endpoint_name {
  description = "The name for the Storage Gateway VPC Interface Endpoint for private communication with Storage Gateway."
  default = "sgw-vpce"
}

variable mysql_server_vm_nfs_file_share_mount_path {
  description = "The directory in the workload VM's guest operating system where the AWS File Gateway VM's NFS file share will be mounted."
  default = "/mnt"
}

variable force_destroy_s3_bucket {
  description = "If enabled, all objects (including any locked objects) will be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable. Only enable this for demonstration purposes."
  default = false
}
