#requires -Version 5

<#
Use this script to reset the workshop environment. It taints all VMs and IAM
user accounts, deletes all objects in the S3 buckets (except the common
directory and it's contents), reprovisions everything, and then sets the
console passwords of the IAM user accounts.
#>

param(
    # The number of lab network objects to provision.
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateRange(1, 199)]
    [UInt16]
    $NumLabs,

    # The AWS profile to use.
    [Parameter(
        Mandatory = $true,
        Position = 1,
        ValueFromPipelineByPropertyName = $true
    )]
    [String]
    $Profile,

    # The IAM user password to set for all students.
    [Parameter(
        Mandatory = $true,
        Position = 2,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateLength(8, 64)]
    [String]
    $Password
)

if ($null -eq (Get-Command -Name 'terraform' -ErrorAction 'SilentlyContinue')) {
    throw 'Cannot find terraform executable in $env:PATH'
}

$env:AWS_PROFILE = $Profile

for ($i = 0; $i -lt $NumLabs; $i++) {
    terraform taint "vsphere_virtual_machine.file_gateways[${i}]"
    terraform taint "vsphere_virtual_machine.workload_vms[${i}]"
    terraform taint "aws_iam_user.students[${i}]"
    terraform taint "aws_cloudwatch_log_group.workload_vms[${i}]"
    terraform taint "aws_cloudwatch_log_group.storage_gateway[${i}]"
}

aws storagegateway list-gateways |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'Gateways' |
    ForEach-Object  -Process {
        $arn = $_.GatewayARN
        aws storagegateway delete-gateway --gateway-arn "$arn"
    }

aws s3 ls |
    Where-Object -FilterScript { $_ -match 'vmc-lab-(?:analytics|monitoring|resiliency|security)-' } |
    ForEach-Object -Process {
        $bucketName = $_.Split(' ')[-1]
        aws s3 rm "s3://${bucketName}/" --recursive --exclude 'common/*'
    }

terraform apply -parallelism=20 -auto-approve

.\Set-StudentsIamUserPasswords.ps1 -NumLabs $NumLabs -Password $Password
