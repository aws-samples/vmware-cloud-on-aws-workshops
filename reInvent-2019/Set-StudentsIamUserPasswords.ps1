#requires -Version 5

<#
Use this script to set the students' IAM user passwords after applying the
Terraform template, which creates the IAM user accounts.
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

    # The IAM user password to set for all students.
    [Parameter(
        Mandatory = $true,
        Position = 1,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateLength(8, 64)]
    [String]
    $Password
)

for ($i = 1; $i -le $NumLabs; $i++) {
    $studentUserName = 'student{0:d3}' -f $i
    aws iam create-login-profile --user-name $studentUserName --password $Password --no-password-reset-required
}
