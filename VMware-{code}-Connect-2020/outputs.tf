output vsphere_server {
  description = "The IP address or the DNS name of the vSphere server where the VMs were deployed."
  value = var.vsphere_server
}

output vsphere_datacenter_name {
  description = "The name of the vSphere datacenter where the VMs were deployed."
  value = var.datacenter_name
}

output vsphere_resource_pool_name {
  description = "The name of the vSphere resource pool where the VMs were deployed."
  value = var.resource_pool_name
}

output vsphere_datastore_name {
  description = "The name of the datastore where the VMs' virtual disks were deployed."
  value = var.datastore_name
}

output vsphere_network_name {
  description = "The name of the network segment or port group to which the VMs' vNICs were connected."
  value = var.network_name
}

output vsphere_vm_folder_path {
  description = "The VM folder path to use."
  value = var.vm_folder_path
}

output vsphere_mysql_server_vm_template {
  description = "The name of the Ubuntu Server VM template that was cloned for the MySQL Server VM."
  value = var.ubuntu_server_vm_template_name
}

output vsphere_mysql_server_vm_name {
  description = "The name of the MySQL Server VM."
  value = var.mysql_server_vm_name
}

output vsphere_mysql_server_vm_moid {
  description = "The managed object reference ID of the MySQL Server VM."
  value = vsphere_virtual_machine.mysql_server_vm.moid
}

output vsphere_mysql_server_vm_default_ip_address {
  description = "The IP address selected by Terraform to be used with any provisioners configured on this resource. Whenever possible, this is the first IPv4 address that is reachable through the default gateway configured on the machine, then the first reachable IPv6 address, and then the first general discovered address if neither exist. If VMware tools is not running on the virtual machine, or if the VM is powered off, this value will be blank."
  value = vsphere_virtual_machine.mysql_server_vm.default_ip_address
}

output vsphere_mysql_server_vm_nfs_file_share_mount_path {
  value = var.mysql_server_vm_nfs_file_share_mount_path
}

output file_gateway_name {
  description = "The name to use for the AWS File Gateway VM and the name prefix for the AWS resources."
  value = var.file_gateway_name
}

output file_gateway_vm_moid {
  description = "The managed object reference ID of the AWS File Gateway VM."
  value = vsphere_virtual_machine.file_gateway_vm.moid
}

output file_gateway_vm_default_ip_address {
  description = "The IP address selected by Terraform to be used with any provisioners configured on this resource. Whenever possible, this is the first IPv4 address that is reachable through the default gateway configured on the machine, then the first reachable IPv6 address, and then the first general discovered address if neither exist. If VMware tools is not running on the virtual machine, or if the VM is powered off, this value will be blank."
  value = vsphere_virtual_machine.file_gateway_vm.default_ip_address
}

output file_gateway_arn {
  description = "The Amazon Resource Name (ARN) of the AWS File Gateway instance."
  value = aws_storagegateway_gateway.file_gateway.arn
}

output file_gateway_nfs_export {
  description = "The NFS server file share export used by the NFS client to identify the mount point."
  value = "${vsphere_virtual_machine.file_gateway_vm.default_ip_address}:${aws_storagegateway_nfs_file_share.nfs_file_share.path}"
}

output file_gateway_nfs_file_share_arn {
  description = "The Amazon Resource Name (ARN) of the NFS File Share."
  value = aws_storagegateway_gateway.file_gateway.arn
}

output s3_vpc_endpoint_arn {
  description = "The Amazon Resource Name (ARN) of the Amazon S3 VPC gateway endpoint."
  value = aws_vpc_endpoint.s3.arn
}

output s3_file_gateway_bucket_arn {
  description = "The Amazon Resource Name (ARN) of the Amazon S3 bucket backing the AWS Storage Gateway."
  value = aws_s3_bucket.file_gateway.arn
}

output s3_file_gateway_bucket_regional_domain_name {
  description = "The region-specific domain name for the Amazon S3 bucket."
  value = aws_s3_bucket.file_gateway.arn
}

output storage_gateway_vpc_endpoint_arn {
  description = "The Amazon Resource Name (ARN) of the AWS Storage Gateway VPC interface endpoint."
  value = aws_vpc_endpoint.storage_gateway.arn
}

output storage_gateway_vpc_endpoint_dns_names {
  description = "The DNS names assigned to the AWS Storage Gateway VPC interface endpoint."
  value = aws_vpc_endpoint.storage_gateway.dns_entry.*.dns_name
}

output storage_gateway_vpc_endpoint_security_group_name {
  description = "The name of the security group used by the AWS Storage Gateway VPC interface endpoint."
  value = aws_security_group.storage_gateway_vpc_endpoint.name
}

output storage_gateway_vpc_endpoint_security_group_arn {
  description = "The Amazon Resource Name (ARN) of the security group used by the AWS Storage Gateway VPC interface endpoint."
  value = aws_security_group.storage_gateway_vpc_endpoint.arn
}

output file_gateway_cloudwatch_log_group_arn {
  description = "The Amazon Resource Name (ARN) specifying the Amazon CloudWatch log group."
  value = aws_cloudwatch_log_group.file_gateway.arn
}

output force_destroy_s3_bucket {
  description = "If enabled, all objects (including any locked objects) will be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable."
  value = var.force_destroy_s3_bucket
}
