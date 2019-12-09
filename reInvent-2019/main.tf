# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY VMWARE CLOUD ON AWS LABS FOR LEARNING ABOUT INTEGRATION WITH AWS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  version = "~> 2.34"
  profile = "${var.aws_profile}"
  region  = "${var.aws_region}"
}

# ------------------------------------------------------------------------------
# CONFIGURE OUR VSPHERE CONNECTION
# ------------------------------------------------------------------------------

provider "vsphere" {
  version = "~> 1.13"

  vsphere_server = "${var.vsphere_server}"
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"

  # Do not permit self-signed certificates
  allow_unverified_ssl = false
}

# ---------------------------------------------------------------------------------------------------------------------
# LOCALS
# ---------------------------------------------------------------------------------------------------------------------

locals {
  lab_prefix = "student"

  cidr_block = "10.200.0.0/16"

  students_per_glue_bucket = 30
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM USER ACCOUNT FOR EACH STUDENT
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_user" "students" {
  count = "${var.num_labs}"

  name = "student${format("%03d", count.index + 1)}"

  force_destroy = true

  tags = {
    Name = "student${format("%03d", count.index + 1)}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM GROUP FOR THE WORKSHOP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_group" "workshop" {
  name = "workshop"
  path = "/students/"
}

resource "aws_iam_group_membership" "workshop" {
  name  = "workshop"
  users = "${aws_iam_user.students.*.name}"
  group = "${aws_iam_group.workshop.name}"
}

resource "aws_iam_group_policy" "workshop_deny_all_outside_workshop_region" {
  name  = "DenyAllOutsideWorkshopRegion"
  group = "${aws_iam_group.workshop.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "NotAction": [
        "cloudfront:*",
        "iam:*",
        "route53:*",
        "support:*",
        "budgets:*",
        "globalaccelerator:*",
        "importexport:*",
        "organizations:*",
        "waf:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "${var.aws_region}"
          ]
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "workshop_s3_read_only_access" {
  name  = "AmazonS3ReadOnlyAccess"
  group = "${aws_iam_group.workshop.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Describe*",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": ["${aws_s3_bucket.vmc_workshop.arn}"]
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM GROUP FOR THE SECURITY MODULE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_group" "security" {
  name = "security"
  path = "/students/"
}

resource "aws_iam_group_membership" "security" {
  name  = "security"
  users = "${aws_iam_user.students.*.name}"
  group = "${aws_iam_group.security.name}"
}

resource "aws_iam_group_policy_attachment" "security_acm_read_only" {
  group = "${aws_iam_group.security.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCertificateManagerReadOnly"
}

resource "aws_iam_group_policy_attachment" "security_elb_full_access" {
  group = "${aws_iam_group.security.name}"
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_group_policy_attachment" "security_aws_waf_full_access" {
  group = "${aws_iam_group.security.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSWAFFullAccess"
}

resource "aws_iam_group_policy" "security_s3_read_only_access" {
  name  = "AmazonS3ReadOnlyAccess"
  group = "${aws_iam_group.security.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Describe*",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": ["${aws_s3_bucket.vmc_lab_security.arn}"]
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "security_iam_certificate_read_only" {
  name  = "AWSIAMCertificateReadOnly"
  group = "${aws_iam_group.security.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetServerCertificate",
        "iam:ListServerCertificates"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM GROUP FOR THE MONITORING MODULE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_group" "monitoring" {
  name = "monitoring"
  path = "/students/"
}

resource "aws_iam_group_membership" "monitoring" {
  name  = "monitoring"
  users = "${aws_iam_user.students.*.name}"
  group = "${aws_iam_group.monitoring.name}"
}

resource "aws_iam_group_policy" "monitoring_s3_read_only_access" {
  name  = "AmazonS3ReadOnlyAccess"
  group = "${aws_iam_group.monitoring.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Describe*",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": ["${aws_s3_bucket.vmc_lab_monitoring.arn}"]
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "cloudwatch_full_access" {
  name  = "CloudWatchFullAccess"
  group = "${aws_iam_group.monitoring.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:Describe*",
        "cloudwatch:*",
        "logs:*",
        "sns:*"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": [
            "${var.aws_region}"
          ]
        }
      }
    },
    {
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/events.amazonaws.com/AWSServiceRoleForCloudWatchEvents*",
      "Condition": {
        "StringLike": {
          "iam:AWSServiceName": "events.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM GROUP FOR THE RESILIENCY MODULE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_group" "resiliency" {
  name = "resiliency"
  path = "/students/"
}

resource "aws_iam_group_membership" "resiliency" {
  name  = "resiliency"
  users = "${aws_iam_user.students.*.name}"
  group = "${aws_iam_group.resiliency.name}"
}

resource "aws_iam_group_policy" "resiliency_s3_read_only_access" {
  name  = "AmazonS3ReadOnlyAccess"
  group = "${aws_iam_group.resiliency.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Describe*",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": ["${aws_s3_bucket.vmc_lab_resiliency.arn}"]
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "resiliency_storage_gateway_full_access" {
  name  = "AWSStorageGatewayFullAccess"
  group = "${aws_iam_group.resiliency.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "storagegateway:*",
      "Resource": [
        "arn:aws:storagegateway:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*",
        "arn:aws:storagegateway:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*/",
        "arn:aws:storagegateway:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*/*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSnapshots",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "${aws_iam_role.storage_gateway_s3_bucket_access.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "resiliency_vpc_read_only_access" {
  name  = "AmazonVPCReadOnlyAccess"
  group = "${aws_iam_group.resiliency.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeClassicLinkInstances",
        "ec2:DescribeCustomerGateways",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeEgressOnlyInternetGateways",
        "ec2:DescribeFlowLogs",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeMovingAddresses",
        "ec2:DescribeNatGateways",
        "ec2:DescribeNetworkAcls",
        "ec2:DescribeNetworkInterfaceAttribute",
        "ec2:DescribeNetworkInterfacePermissions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribePrefixLists",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroupReferences",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeStaleSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeVpcClassicLink",
        "ec2:DescribeVpcClassicLinkDnsSupport",
        "ec2:DescribeVpcEndpoints",
        "ec2:DescribeVpcEndpointConnectionNotifications",
        "ec2:DescribeVpcEndpointConnections",
        "ec2:DescribeVpcEndpointServiceConfigurations",
        "ec2:DescribeVpcEndpointServicePermissions",
        "ec2:DescribeVpcEndpointServices",
        "ec2:DescribeVpcPeeringConnections",
        "ec2:DescribeVpcs",
        "ec2:DescribeVpnConnections",
        "ec2:DescribeVpnGateways"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": [
            "${var.aws_region}"
          ]
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "resiliency_iam_read_only_access" {
  name  = "AWSIAMReadOnlyAccess"
  group = "${aws_iam_group.resiliency.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:Get*",
        "iam:List*",
        "iam:Simulate*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM GROUP FOR THE ANALYTICS MODULE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_group" "analytics" {
  name = "analytics"
  path = "/students/"
}

resource "aws_iam_group_membership" "analytics" {
  name  = "analytics"
  users = "${aws_iam_user.students.*.name}"
  group = "${aws_iam_group.analytics.name}"
}

resource "aws_iam_group_policy_attachment" "analytics_amazon_redshift_query_editor" {
  group      = "${aws_iam_group.analytics.id}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftQueryEditor"
}

resource "aws_iam_group_policy_attachment" "analytics_aws_glue_console_full_access" {
  group      = "${aws_iam_group.analytics.id}"
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_iam_group_policy" "analytics_s3_read_only_access" {
  name  = "AmazonS3ReadOnlyAccess"
  group = "${aws_iam_group.analytics.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Describe*",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.vmc_lab_analytics.arn}",
        "${join(", ", data.aws_s3_bucket.glue_buckets.*.arn)}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_group_policy" "analytics_iam_passrole_to_glue" {
  name  = "AWSIamPassRoleToGlue"
  group = "${aws_iam_group.analytics.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vmcanalytics*",
      "Condition": {
          "StringLike": {
            "iam:PassedToService": [
              "glue.amazonaws.com"
            ]
          }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "vmcanalytics" {
  count = "${var.num_labs}"

  name = "vmcanalytics${format("%03d", count.index + 1)}"
  description = "Allows Glue to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "analytics_amazon_s3_full_access" {
  count = "${var.num_labs}"

  role       = "${element(aws_iam_role.vmcanalytics.*.name, count.index)}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "analytics_aws_glue_service_role" {
  count = "${var.num_labs}"

  role       = "${element(aws_iam_role.vmcanalytics.*.name, count.index)}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LABS TAG CATEGORY AND LAB ID TAG
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_tag_category" "labs" {
  name        = "labs"
  cardinality = "SINGLE"
  description = "Managed by Terraform"

  associable_types = ["VirtualMachine"]
}

resource "vsphere_tag" "labs" {
  count = "${var.num_labs}"

  name        = "${local.lab_prefix}${format("%03d", count.index + 1)}"
  category_id = "${vsphere_tag_category.labs.id}"
  description = "Lab ${count.index + 1}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A TERRAFORM TAG CATEGORY AND TAG
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_tag_category" "terraform" {
  name        = "terraform"
  cardinality = "SINGLE"
  description = "Managed by Terraform"

  associable_types = ["VirtualMachine"]
}

resource "vsphere_tag" "terraform" {
  name        = "terraform"
  category_id = "${vsphere_tag_category.terraform.id}"
  description = "Managed by Terraform"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A VM FOLDER FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_folder" "labs" {
  count = "${var.num_labs}"

  path          = "Workloads/${local.lab_prefix}${format("%03d", count.index + 1)}"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A RESOURCE POOL FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_resource_pool" "labs" {
  count = "${var.num_labs}"

  name                    = "${local.lab_prefix}${format("%03d", count.index + 1)}"
  parent_resource_pool_id = "${data.vsphere_resource_pool.compute.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A WORKLOAD VM FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_virtual_machine" "workload_vms" {
  count = "${var.num_labs}"

  name     = "${local.lab_prefix}${format("%03d", count.index + 1)}-workload-vm"
  guest_id = "amazonlinux2_64Guest"

  resource_pool_id = "${element(vsphere_resource_pool.labs.*.id, count.index)}"
  datastore_id     = "${data.vsphere_datastore.workload.id}"
  folder           = "Workloads/${local.lab_prefix}${format("%03d", count.index + 1)}"

  num_cpus = 2
  memory   = 4096

  network_interface {
    network_id = "${data.vsphere_network.student_network.id}"
  }

  disk {
    label = "disk0"
    size  = 25
  }

  wait_for_guest_net_timeout  = 15
  wait_for_guest_net_routable = true
  shutdown_wait_timeout       = 1

  sync_time_with_host = false

  annotation = "Lab ${count.index + 1}: Amazon Linux 2 Workload VM\nUsername: vmc-user\nPassword: ${var.workload_vm_password}"

  tags = [
    "${element(vsphere_tag.labs.*.id, count.index)}",
    "${vsphere_tag.terraform.id}",
  ]

  clone {
    template_uuid = "${data.vsphere_virtual_machine.amazon_linux_2_template.id}"
    linked_clone  = false

    customize {
      timeout = 15

      linux_options {
        host_name    = "${local.lab_prefix}${format("%03d", count.index + 1)}-workload-vm"
        domain       = "${var.domain_name}"
        hw_clock_utc = true
        time_zone    = "UTC"
      }

      network_interface {
        ipv4_address = "10.200.${count.index + 1}.10"
        ipv4_netmask = "16"
      }

      ipv4_gateway = "10.200.0.1"

      dns_server_list = "${var.dns_servers}"
      dns_suffix_list = ["${var.domain_name}"]
    }
  }

  depends_on = ["vsphere_folder.labs"]

  lifecycle {
    create_before_destroy = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A FILE GATEWAY FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "vsphere_virtual_machine" "file_gateways" {
  count = "${var.num_labs}"

  name     = "${local.lab_prefix}${format("%03d", count.index + 1)}-file-gateway"
  guest_id = "otherGuest64"

  resource_pool_id = "${element(vsphere_resource_pool.labs.*.id, count.index)}"
  datastore_id     = "${data.vsphere_datastore.workload.id}"
  folder           = "Workloads/${local.lab_prefix}${format("%03d", count.index + 1)}"

  num_cpus = 4
  memory   = 16384

  network_interface {
    network_id = "${data.vsphere_network.student_network.id}"
  }

  disk {
    label = "disk0"
    size  = 80
  }

  disk {
    label       = "disk1"
    size        = 150
    unit_number = 1
  }

  wait_for_guest_net_timeout  = 15
  wait_for_guest_net_routable = true
  shutdown_wait_timeout       = 1

  sync_time_with_host = true

  annotation = "Lab ${count.index + 1}: AWS File Gateway\nUsername: admin\nPassword: password"

  tags = [
    "${element(vsphere_tag.labs.*.id, count.index)}",
    "${vsphere_tag.terraform.id}",
  ]

  clone {
    template_uuid = "${data.vsphere_virtual_machine.file_gateway_template.id}"
    linked_clone  = false
  }

  depends_on = ["vsphere_folder.labs"]

  lifecycle {
    create_before_destroy = false
  }
}

# Storage Gateway VPC Endpoints are not yet supported
# https://github.com/terraform-providers/terraform-provider-aws/issues/9920
# Build from pull request
# resource "aws_storagegateway_gateway" "file_gateways" {
#   count = "${var.num_labs}"

#   gateway_ip_address   = "${element(vsphere_virtual_machine.file_gateways.*.default_ip_address, count.index)}"
#   gateway_name         = "${local.lab_prefix}${format("%03d", count.index + 1)}-file-gateway"
#   gateway_timezone     = "GMT"
#   gateway_type         = "FILE_S3"
#   gateway_vpc_endpoint = "${element(aws_vpc_endpoint.storage_gateway.dns_entry.*.dns_name, 0)}"
# }

# resource "aws_storagegateway_cache" "file_gateways" {
#   count = "${var.num_labs}"

#   disk_id     = "${element(data.aws_storagegateway_local_disk.file_gateways.*.id, count.index)}"
#   gateway_arn = "${element(aws_storagegateway_gateway.file_gateways.*.arn, count.index)}"
# }

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NFS FILE SHARE FOR EACH FILE GATEWAY FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

# resource "aws_storagegateway_nfs_file_share" "nfs_file_shares" {
#   count = "${var.num_labs}"

#   gateway_arn  = "${element(aws_storagegateway_gateway.file_gateways.*.arn, count.index)}"
#   location_arn = "${aws_s3_bucket.vmc_lab_resiliency.arn}"
#   role_arn     = "${aws_iam_role.storage_gateway_s3_bucket_access.arn}"
#   client_list  = ["${element(vsphere_virtual_machine.workload_vms.*.default_ip_address, count.index)}/32"]

#   default_storage_class = "S3_STANDARD"
#   kms_encrypted         = false
#   read_only             = false
#   squash                = "RootSquash"

#   nfs_file_share_defaults {
#     directory_mode = "0777"
#     file_mode      = "0666"
#     group_id       = 65534 # nfsnobody
#     owner_id       = 65534 # nfsnobody
#   }

#   depends_on = ["aws_storagegateway_cache.file_gateways"]
# }

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE FOR STORAGE GATEWAY FILE SHARE S3 BUCKET ACCESS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "storage_gateway_s3_bucket_access" {
  name = "AWSStorageGatewayS3BucketAccess"
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

  tags = {
    Name = "AWSStorageGatewayS3BucketAccess"
  }
}

resource "aws_iam_role_policy" "storage_gateway_s3_bucket_access" {
  name = "AWSStorageGatewayS3BucketAccess"
  role = "${aws_iam_role.storage_gateway_s3_bucket_access.id}"

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
      "Resource": "${aws_s3_bucket.vmc_lab_resiliency.arn}"
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
      "Resource": "${aws_s3_bucket.vmc_lab_resiliency.arn}/*"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE STORAGE GATEWAY VPC ENDPOINT
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "storage_gateway" {
  vpc_id            = "${var.vpc_id}"
  service_name      = "com.amazonaws.${var.aws_region}.storagegateway"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "${aws_security_group.storage_gateway_vpc_endpoint.id}",
  ]

  private_dns_enabled = true

  tags = {
    Name = "sgw-vpce"
  }
}

resource "aws_vpc_endpoint_subnet_association" "storage_gateway" {
  vpc_endpoint_id = "${aws_vpc_endpoint.storage_gateway.id}"
  subnet_id       = "${var.vpc_subnet_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE STORAGE GATEWAY VPC ENDPOINT SECURITY GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "storage_gateway_vpc_endpoint" {
  name        = "sgw-vpce"
  description = "Storage Gateway VPC Endpoint security group"
  vpc_id      = "${var.vpc_id}"

  tags = {
    Name = "sgw-vpce"
  }
}

resource "aws_security_group_rule" "allow_https" {
  description       = "HTTPS"
  security_group_id = "${aws_security_group.storage_gateway_vpc_endpoint.id}"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["${local.cidr_block}"]
}

resource "aws_security_group_rule" "allow_1026-1028_tcp" {
  security_group_id = "${aws_security_group.storage_gateway_vpc_endpoint.id}"
  type              = "ingress"
  from_port         = 1026
  to_port           = 1028
  protocol          = "tcp"
  cidr_blocks       = ["${local.cidr_block}"]
}

resource "aws_security_group_rule" "allow_1031_tcp" {
  security_group_id = "${aws_security_group.storage_gateway_vpc_endpoint.id}"
  type              = "ingress"
  from_port         = 1031
  to_port           = 1031
  protocol          = "tcp"
  cidr_blocks       = ["${local.cidr_block}"]
}

resource "aws_security_group_rule" "allow_2222_tcp" {
  security_group_id = "${aws_security_group.storage_gateway_vpc_endpoint.id}"
  type              = "ingress"
  from_port         = 2222
  to_port           = 2222
  protocol          = "tcp"
  cidr_blocks       = ["${local.cidr_block}"]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  description       = "Allow all"
  security_group_id = "${aws_security_group.storage_gateway_vpc_endpoint.id}"
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A WORKLOAD VM CLOUDWATCH AGENT CLOUDWATCH LOG GROUP FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "workload_vms" {
  count = "${var.num_labs}"

  name = "${element(vsphere_virtual_machine.workload_vms.*.name, count.index)}.${var.domain_name}"

  retention_in_days = 1
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A STORAGE GATEWAY CLOUDWATCH LOG GROUP FOR EACH LAB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "storage_gateway" {
  count = "${var.num_labs}"

  name = "/aws/storagegateway/${local.lab_prefix}${format("%03d", count.index + 1)}"

  retention_in_days = 1
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SHARED WORKSHOP STUDENT S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_workshop" {
  bucket_prefix = "vmc-workshop-"

  acl = "private"

  tags = {
    Name = "vmc-workshop"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_workshop" {
  bucket = "${aws_s3_bucket.vmc_workshop.id}"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_object" "vmc_workshop_common" {
  bucket = "${aws_s3_bucket.vmc_workshop.id}"
  key    = "common/"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE WORKSHOP ADMIN S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_workshop_admin" {
  bucket_prefix = "vmc-workshop-admin-"

  acl = "private"

  tags = {
    Name = "vmc-workshop-admin"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_workshop_admin" {
  bucket = "${aws_s3_bucket.vmc_workshop_admin.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "vmc_workshop_admin_images" {
  bucket = "${aws_s3_bucket.vmc_workshop.id}"
  key    = "images/"
}

resource "aws_s3_bucket_object" "vmc_workshop_admin_software" {
  bucket = "${aws_s3_bucket.vmc_workshop.id}"
  key    = "software/"
}

resource "aws_s3_bucket_object" "vmc_workshop_admin_data" {
  bucket = "${aws_s3_bucket.vmc_workshop.id}"
  key    = "data/"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY MODULE S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_lab_security" {
  bucket_prefix = "vmc-lab-security-"

  acl = "private"

  tags = {
    Name = "vmc-lab-security"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_lab_security" {
  bucket = "${aws_s3_bucket.vmc_lab_security.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "vmc_lab_security_common" {
  bucket = "${aws_s3_bucket.vmc_lab_security.id}"
  key    = "common/"
}

resource "aws_s3_bucket_object" "vmc_lab_security_students" {
  count = "${var.num_labs}"

  bucket = "${aws_s3_bucket.vmc_lab_security.id}"
  key    = "student${format("%03d", count.index + 1)}/"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE MONITORING MODULE S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_lab_monitoring" {
  bucket_prefix = "vmc-lab-monitoring-"

  acl = "private"

  tags = {
    Name = "vmc-lab-monitoring"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_lab_monitoring" {
  bucket = "${aws_s3_bucket.vmc_lab_monitoring.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "vmc_lab_monitoring_common" {
  bucket = "${aws_s3_bucket.vmc_lab_monitoring.id}"
  key    = "common/"
}

resource "aws_s3_bucket_object" "vmc_lab_monitoring_students" {
  count = "${var.num_labs}"

  bucket = "${aws_s3_bucket.vmc_lab_monitoring.id}"
  key    = "student${format("%03d", count.index + 1)}/"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE RESILIENCY MODULE S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_lab_resiliency" {
  bucket_prefix = "vmc-lab-resiliency-"

  acl = "private"

  tags = {
    Name = "vmc-lab-resiliency"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_lab_resiliency" {
  bucket = "${aws_s3_bucket.vmc_lab_resiliency.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "vmc_lab_resiliency_common" {
  bucket = "${aws_s3_bucket.vmc_lab_resiliency.id}"
  key    = "common/"
}

resource "aws_s3_bucket_object" "vmc_lab_resiliency_students" {
  count = "${var.num_labs}"

  bucket = "${aws_s3_bucket.vmc_lab_resiliency.id}"
  key    = "student${format("%03d", count.index + 1)}/"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ANALYTICS MODULE S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "vmc_lab_analytics" {
  bucket_prefix = "vmc-lab-analytics-"

  acl = "private"

  tags = {
    Name = "vmc-lab-analytics"
  }
}

resource "aws_s3_bucket_public_access_block" "vmc_lab_analytics" {
  bucket = "${aws_s3_bucket.vmc_lab_analytics.id}"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "vmc_lab_analytics_common" {
  bucket = "${aws_s3_bucket.vmc_lab_analytics.id}"
  key    = "common/"
}

resource "aws_s3_bucket_object" "vmc_lab_analytics_students" {
  count = "${var.num_labs}"

  bucket = "${aws_s3_bucket.vmc_lab_analytics.id}"
  key    = "student${format("%03d", count.index + 1)}/"
}

resource "aws_s3_bucket_object" "glue_key" {
  count = "${var.num_labs}"

  bucket = "${element(data.aws_s3_bucket.glue_buckets.*.id, floor(count.index / local.students_per_glue_bucket))}"
  key    = "student${format("%03d", count.index + 1)}/"
}

resource "aws_s3_bucket_object" "glue_key_exception" {
  count = "${var.num_labs == 160 ? 10 : 0}"

  bucket = "${data.aws_s3_bucket.glue_buckets.4.id}"
  key    = "student${format("%03d", count.index + 151)}/"
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# data "aws_storagegateway_local_disk" "file_gateways" {
#   count = "${var.num_labs}"

#   disk_path   = "/dev/sdb"
#   gateway_arn = "${element(aws_storagegateway_gateway.file_gateways.*.arn, count.index)}"
# }

data "aws_s3_bucket" "glue_buckets" {
  count = "${ceil(var.num_labs / local.students_per_glue_bucket)}"

  bucket = "vmc-lab-analytics-db${count.index + 1}"
}

data "vsphere_datacenter" "dc" {
  name = "SDDC-Datacenter"
}

data "vsphere_resource_pool" "compute" {
  name          = "Compute-ResourcePool"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "workload" {
  name          = "WorkloadDatastore"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "amazon_linux_2_template" {
  name          = "${var.workload_vm_template_name}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "file_gateway_template" {
  name          = "${var.file_gateway_vm_template_name}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "student_network" {
  name          = "student-network"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}
