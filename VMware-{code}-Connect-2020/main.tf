# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# VMware {code} Connect 2020
# Session: CODE4238 - Building hybrid solutions with VMware, AWS, & Terraform
# https://vmwarecodeconnect.github.io/CodeConnect2020/Troy2/
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# Configure the Terraform session
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.7.0"
    }

    null = {
      source = "hashicorp/null"
      version = "~> 2.1.2"
    }

    vsphere = {
      source = "hashicorp/vsphere"
      version = "~> 1.24.0"
    }
  }
  required_version = ">= 0.13"
}

# ---------------------------------------------------------------------------------------------------------------------
# Configure the Terraform providers
# ---------------------------------------------------------------------------------------------------------------------

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider aws {
  profile = var.aws_profile
  region = var.aws_region
}

# https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs
provider vsphere {
  vsphere_server = var.vsphere_server
  user = var.vsphere_user
  password = var.vsphere_password
  allow_unverified_ssl = false
}

# ---------------------------------------------------------------------------------------------------------------------
# Local variables
# ---------------------------------------------------------------------------------------------------------------------

locals {
  tags = {
    Terraform = "Managed by Terraform"
    Project = "VMware Code Connect 2020 - Session: CODE4238 - Building hybrid solutions with VMware + AWS + Terraform"
  }

  mysql_server_vm_cidr = "${vsphere_virtual_machine.mysql_server_vm.default_ip_address}/32"
  file_gateway_vm_cidr = "${vsphere_virtual_machine.file_gateway_vm.default_ip_address}/32"
}

# ---------------------------------------------------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------------------------------------------------

data vsphere_datacenter datacenter {
  name = var.datacenter_name
}

data vsphere_resource_pool resource_pool {
  name = var.resource_pool_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data vsphere_datastore datastore {
  name = var.datastore_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data vsphere_virtual_machine ubuntu_server_vm_template {
  name = var.ubuntu_server_vm_template_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data vsphere_virtual_machine file_gateway_template {
  name = var.file_gateway_vm_template_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data vsphere_network network {
  name = var.network_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data aws_route_tables connected_vpc {
  vpc_id = var.vpc_id
}

data aws_storagegateway_local_disk file_gateway {
  disk_path = "/dev/sdb"
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
}

data aws_network_interface sgw_vpce {
  id = tolist(aws_vpc_endpoint.storage_gateway.network_interface_ids)[0]
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the VM tag categories and tags in vSphere
# ---------------------------------------------------------------------------------------------------------------------

resource vsphere_tag_category terraform {
  name = "Terraform"
  cardinality = "SINGLE"
  description = local.tags.Terraform
  associable_types = [
    "VirtualMachine",
  ]
}

resource vsphere_tag terraform {
  name = "Terraform"
  category_id = vsphere_tag_category.terraform.id
  description = local.tags.Terraform
}

resource vsphere_tag_category project {
  name = "Project"
  cardinality = "SINGLE"
  description = local.tags.Project
  associable_types = [
    "VirtualMachine",
  ]
}

resource vsphere_tag project {
  name = "Project"
  category_id = vsphere_tag_category.project.id
  description = local.tags.Project
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the VM folder in vSphere
# ---------------------------------------------------------------------------------------------------------------------

resource vsphere_folder workload {
  path = var.vm_folder_path
  type = "vm"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# ---------------------------------------------------------------------------------------------------------------------
# Clone the MySQL Server VM from VM template in vSphere
# ---------------------------------------------------------------------------------------------------------------------

resource vsphere_virtual_machine mysql_server_vm {
  name = var.mysql_server_vm_name
  guest_id = "ubuntu64Guest"

  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  datastore_id = data.vsphere_datastore.datastore.id
  folder = var.vm_folder_path

  num_cpus = 2
  memory = 4096

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label = "disk0"
    size = 25
    thin_provisioned = var.thin_provisioned
  }

  hardware_version = var.vm_version

  wait_for_guest_net_timeout = 15
  wait_for_guest_net_routable = true
  shutdown_wait_timeout = 1

  sync_time_with_host = false

  tags = [
    vsphere_tag.terraform.id,
    vsphere_tag.project.id,
  ]

  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_server_vm_template.id
    linked_clone = false

    customize {
      timeout = 15

      linux_options {
        host_name = var.mysql_server_vm_name
        domain = var.domain_name
        hw_clock_utc = true
        time_zone = "UTC"
      }

      network_interface {}
    }
  }

  depends_on = [
    vsphere_folder.workload,
  ]

  lifecycle {
    create_before_destroy = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Clone the AWS File Gateway VM from the VM template in vSphere
# ---------------------------------------------------------------------------------------------------------------------

resource vsphere_virtual_machine file_gateway_vm {
  name = var.file_gateway_name
  guest_id = data.vsphere_virtual_machine.file_gateway_template.guest_id

  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  datastore_id = data.vsphere_datastore.datastore.id
  folder = var.vm_folder_path

  # https://docs.aws.amazon.com/storagegateway/latest/userguide/Requirements.html#requirements-hardware
  num_cpus = 4
  memory = 16384

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  # https://docs.aws.amazon.com/storagegateway/latest/userguide/Requirements.html#requirements-hardware
  disk {
    label = "disk0"
    size = 80
    thin_provisioned = var.thin_provisioned
  }

  # https://docs.aws.amazon.com/storagegateway/latest/userguide/Requirements.html#requirements-storage
  disk {
    label = "disk1-cache"
    size = 150
    unit_number = 1
    thin_provisioned = var.thin_provisioned
  }

  hardware_version = var.vm_version

  wait_for_guest_net_timeout = 15
  wait_for_guest_net_routable = true
  shutdown_wait_timeout = 1

  # https://docs.aws.amazon.com/storagegateway/latest/userguide/configure-vmware.html#GettingStartedSyncVMTime-common
  sync_time_with_host = true

  annotation = data.vsphere_virtual_machine.file_gateway_template.annotation

  tags = [
    vsphere_tag.terraform.id,
    vsphere_tag.project.id,
  ]

  clone {
    template_uuid = data.vsphere_virtual_machine.file_gateway_template.id
    linked_clone = false
  }

  depends_on = [
    vsphere_folder.workload,
  ]

  lifecycle {
    create_before_destroy = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Register the AWS File Gateway instance and configure it for private connectivity
# ---------------------------------------------------------------------------------------------------------------------

resource aws_storagegateway_gateway file_gateway {
  gateway_ip_address = vsphere_virtual_machine.file_gateway_vm.default_ip_address
  gateway_name = var.file_gateway_name
  gateway_timezone = "GMT"
  gateway_type = "FILE_S3"
  gateway_vpc_endpoint = data.aws_network_interface.sgw_vpce.private_ip
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.file_gateway.arn

  tags = merge(
    { Name = var.file_gateway_name },
    local.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Register the AWS File Gateway VM's secondary virtual disk as the caching disk
# ---------------------------------------------------------------------------------------------------------------------

resource aws_storagegateway_cache file_gateway_cache_disk {
  disk_id = data.aws_storagegateway_local_disk.file_gateway.id
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the NFS file share for the AWS File Gateway instance
# ---------------------------------------------------------------------------------------------------------------------

resource aws_storagegateway_nfs_file_share nfs_file_share {
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
  location_arn = aws_s3_bucket.file_gateway.arn
  role_arn = aws_iam_role.storage_gateway_s3_bucket_access.arn
  client_list = [
    local.mysql_server_vm_cidr,
  ]

  default_storage_class = "S3_STANDARD"
  kms_encrypted = false
  read_only = false
  squash = "NoSquash"

  nfs_file_share_defaults {
    directory_mode = "0777"
    file_mode = "0666"
    group_id = 65534 # nfsnobody
    owner_id = 65534 # nfsnobody
  }

  tags = merge(
    { Name = var.file_gateway_name },
    local.tags,
  )

  depends_on = [
    aws_storagegateway_cache.file_gateway_cache_disk,
    aws_vpc_endpoint.s3,
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the AWS Identity and Access Management (IAM) role for granting the AWS File Gateway access to the Amazon S3
# bucket that backs the NFS file share
# ---------------------------------------------------------------------------------------------------------------------

resource aws_iam_role storage_gateway_s3_bucket_access {
  name_prefix = var.storage_gateway_role_name
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "storagegateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(
    { Name = var.storage_gateway_role_name },
    local.tags,
  )
}

resource aws_iam_role_policy storage_gateway_s3_bucket_access {
  name_prefix = var.storage_gateway_role_name
  role = aws_iam_role.storage_gateway_s3_bucket_access.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetAccelerateConfiguration",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:ListBucketMultipartUploads"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.file_gateway.arn}"
    },
    {
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:GetObjectVersion",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.file_gateway.arn}/*"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the VPC Gateway Endpoint for Amazon S3
# ---------------------------------------------------------------------------------------------------------------------

resource aws_vpc_endpoint s3 {
  vpc_id = var.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = tolist(data.aws_route_tables.connected_vpc.ids)

  tags = merge(
    { Name = var.s3_vpc_endpoint_name },
    local.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the VPC Interface Endpoint for AWS Storage Gateway
# ---------------------------------------------------------------------------------------------------------------------

resource aws_vpc_endpoint storage_gateway {
  vpc_id = var.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.storagegateway"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    var.vpc_subnet_id,
  ]

  security_group_ids = [
    aws_security_group.storage_gateway_vpc_endpoint.id,
  ]

  tags = merge(
    { Name = var.storage_gateway_vpc_endpoint_name },
    local.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the security group for the AWS Storage Gateway VPC Interface Endpoint
# ---------------------------------------------------------------------------------------------------------------------

# Port requirements:
# https://docs.aws.amazon.com/storagegateway/latest/userguide/gateway-private-link.html#create-vpc-endpoint
resource aws_security_group storage_gateway_vpc_endpoint {
  name_prefix = var.storage_gateway_vpc_endpoint_name
  description = "Storage Gateway VPC Endpoint security group"
  vpc_id = var.vpc_id

  tags = merge(
    { Name = var.storage_gateway_vpc_endpoint_name },
    local.tags,
  )
}

resource aws_security_group_rule allow_https {
  description = "HTTPS"
  security_group_id = aws_security_group.storage_gateway_vpc_endpoint.id
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = [
    local.file_gateway_vm_cidr,
  ]
}

resource aws_security_group_rule allow_1026-1028_tcp {
  security_group_id = aws_security_group.storage_gateway_vpc_endpoint.id
  type = "ingress"
  from_port = 1026
  to_port = 1028
  protocol = "tcp"
  cidr_blocks = [
    local.file_gateway_vm_cidr,
  ]
}

resource aws_security_group_rule allow_1031_tcp {
  security_group_id = aws_security_group.storage_gateway_vpc_endpoint.id
  type = "ingress"
  from_port = 1031
  to_port = 1031
  protocol = "tcp"
  cidr_blocks = [
    local.file_gateway_vm_cidr,
  ]
}

resource aws_security_group_rule allow_2222_tcp {
  security_group_id = aws_security_group.storage_gateway_vpc_endpoint.id
  type = "ingress"
  from_port = 2222
  to_port = 2222
  protocol = "tcp"
  cidr_blocks = [
    local.file_gateway_vm_cidr,
  ]
}

resource aws_security_group_rule allow_outbound {
  security_group_id = aws_security_group.storage_gateway_vpc_endpoint.id
  type = "egress"
  from_port = -1
  to_port = -1
  protocol = -1
  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Create an Amazon CloudWatch log group for the AWS File Gateway
# ---------------------------------------------------------------------------------------------------------------------

resource aws_cloudwatch_log_group file_gateway {
  name_prefix = "/aws/storagegateway/${var.file_gateway_name}"

  retention_in_days = 1

  tags = merge(
    { Name = var.file_gateway_name },
    local.tags,
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the Amazon S3 bucket for persistent storage for the AWS File Gateway
# ---------------------------------------------------------------------------------------------------------------------

resource aws_s3_bucket file_gateway {
  bucket_prefix = var.file_gateway_name

  acl = "private"

  force_destroy = var.force_destroy_s3_bucket

  tags = merge(
    { Name = var.file_gateway_name },
    local.tags,
  )
}

resource aws_s3_bucket_public_access_block file_gateway {
  bucket = aws_s3_bucket.file_gateway.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Mount the NFS file share in the MySQL Server VM's guest OS and generate a backup to demonstrate the I/O path
# ---------------------------------------------------------------------------------------------------------------------

resource null_resource nfs_client {
  triggers = {
    nfs_client_id = vsphere_virtual_machine.mysql_server_vm.id
  }

  connection {
    type = "ssh"
    user = var.mysql_server_vm_username
    password = var.mysql_server_vm_password
    host = vsphere_virtual_machine.mysql_server_vm.default_ip_address
  }

  provisioner remote-exec {
    inline = [
      "sudo mkdir --parents '${var.mysql_server_vm_nfs_file_share_mount_path}'",
      "echo '${vsphere_virtual_machine.file_gateway_vm.default_ip_address}:${aws_storagegateway_nfs_file_share.nfs_file_share.path} ${var.mysql_server_vm_nfs_file_share_mount_path} nfs4 auto,nolock,hard 0 0' | sudo tee --append /etc/fstab > /dev/null",
      "sudo mount --all",
      "sudo mysqldump --all-databases --result-file=\"${var.mysql_server_vm_nfs_file_share_mount_path}/${var.file_gateway_name}-$(date +%Y%m%dT%H%M%SZ).sql\"",
      "echo \"Successfully created the MySQL backup and stored it in the NFS file share. The MySQL backup is cached first on the AWS File Gateway VM in VMware Cloud on AWS, and then destaged to the Amazon S3 bucket.\"",
      "sudo ls '${var.mysql_server_vm_nfs_file_share_mount_path}'",
    ]
  }
}
