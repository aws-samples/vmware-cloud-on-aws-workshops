# VMware {code} Connect 2020

[Session 4238: Building hybrid solutions with VMware, AWS, & Terraform](https://vmwarecodeconnect.github.io/CodeConnect2020/Troy2/)

End-to-end demonstration of how to build and deploy a MySQL Server in vSphere and an AWS Storage Gateway VM + Amazon S3 bucket for storing backups using Terraform.

## Getting Started

### Prerequisites

1. [HashiCorp Terraform](https://www.terraform.io/downloads.html)
1. [VMware Cloud on AWS console](https://vmc.vmware.com/console/sddcs)
1. Configure input variables (terraform.tfvars, environment variables, et cetera)

### Deploy

1. [`terraform init`](https://www.terraform.io/docs/commands/init.html)
1. [`terraform plan`](https://www.terraform.io/docs/commands/plan.html)
1. [`terraform apply`](https://www.terraform.io/docs/commands/apply.html)

### Destroy

* [`terraform destroy`](https://www.terraform.io/docs/commands/destroy.html)

## Additional Resources

* [Getting started with HashiCorp Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)
* [HashiCorp Terraform source code](https://github.com/hashicorp/terraform)
* [VMware Cloud on AWS documentation](https://docs.vmware.com/en/VMware-Cloud-on-AWS/index.html)
