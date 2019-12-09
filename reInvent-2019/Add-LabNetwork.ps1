#requires -Version 6
# https://github.com/vmware/PowerCLI-Example-Scripts/blob/master/Modules/VMware.VMC.NSXT
#requires -Module VMware.VMC.NSXT

param(
    # The number of lab network objects to provision.
    [Parameter(
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateRange(1, 199)]
    [UInt16]
    $NumLabs = 199
)

$name = 'student-network'
$networkPrefix = '10.200'
$network = "${networkPrefix}.0.0"
$cidr = '16'
$dhcpStart = "${networkPrefix}.200.0"
$dhcpEnd = "${networkPrefix}.255.250"
$studentRange = "${networkPrefix}.1.0-${dhcpEnd}"
$groupNameTemplate = 'student{0:d3}-{1}'
$workloadVmGroupNameSuffix = 'workload-vm'
$studentNetworkGroupNameSuffix = 'network'
$studentRangeGroupName = "${name}-lab-range"
$startingSequenceNumber = 1000
$sequenceNumber = $startingSequenceNumber

#----------------------------------------------------------------------------------------------------------------------
# Create lab network segment
#----------------------------------------------------------------------------------------------------------------------

$splat = @{
    Name       = $name
    Gateway    = "${gateway}/${cidr}"
    DHCP       = $true
    DHCPRange  = "${dhcpStart}-${dhcpEnd}"
    DomainName = 'aws.local'
}
New-NSXTSegment @splat

#----------------------------------------------------------------------------------------------------------------------
# Create Compute Gateway groups
#----------------------------------------------------------------------------------------------------------------------

$splat = @{
    Name        = $name
    GatewayType = 'CGW'
    IPAddress   = "${network}/${cidr}"
}
New-NSXTGroup @splat

$splat = @{
    Name        = $studentRangeGroupName
    GatewayType = 'CGW'
    IPAddress   = "${studentRange}"
}
New-NSXTGroup @splat

for ($i = 1; $i -le $NumLabs; $i++) {
    $workloadVmGroupName = $groupNameTemplate -f $i, $workloadVmGroupNameSuffix
    $studentNetworkGroupName = $groupNameTemplate -f $i, $studentNetworkGroupNameSuffix

    $splat = @{
        Name        = $workloadVmGroupName
        GatewayType = 'CGW'
        IPAddress   = "${networkPrefix}.${i}.10"
    }
    New-NSXTGroup @splat

    $splat = @{
        Name        = $labNetworkGroupName
        GatewayType = 'CGW'
        IPAddress   = "${networkPrefix}.${i}.0/24"
    }
    New-NSXTGroup @splat
}

#----------------------------------------------------------------------------------------------------------------------
# Create Compute Gateway firewall rules
#----------------------------------------------------------------------------------------------------------------------

$splat = @{
    Name             = "${name} > internet"
    GatewayType      = 'CGW'
    SourceGroup      = $name
    DestinationGroup = 'Any'
    Service          = 'Any'
    Action           = 'ALLOW'
    SequenceNumber   = $sequenceNumber++
    InfraScope       = 'Internet Interface'
}
New-NSXTFirewall @splat

$splat = @{
    Name                  = "${name} > VPC"
    GatewayType           = 'CGW'
    SourceGroup           = $name
    DestinationInfraGroup = 'Connected VPC Prefixes'
    Service               = 'Any'
    Action                = 'ALLOW'
    SequenceNumber        = $sequenceNumber++
    InfraScope            = 'VPC Interface'
}
New-NSXTFirewall @splat

$splat = @{
    Name                  = "${name} > S3"
    GatewayType           = 'CGW'
    SourceGroup           = $name
    DestinationInfraGroup = 'S3 Prefixes'
    Service               = 'HTTP', 'HTTPS'
    Action                = 'ALLOW'
    SequenceNumber        = $sequenceNumber++
    InfraScope            = 'VPC Interface'
}
New-NSXTFirewall @splat

$splat = @{
    Name             = "VPC > ${name}"
    GatewayType      = 'CGW'
    SourceInfraGroup = 'Connected VPC Prefixes'
    DestinationGroup = $name
    Service          = 'Any'
    Action           = 'ALLOW'
    SequenceNumber   = $sequenceNumber++
    InfraScope       = 'VPC Interface'
}
New-NSXTFirewall @splat

#----------------------------------------------------------------------------------------------------------------------
# Create distributed firewall section
#----------------------------------------------------------------------------------------------------------------------

$splat = @{
    Name     = $name
    Category = 'Application'
}
New-NSXTDistFirewallSection @splat

#----------------------------------------------------------------------------------------------------------------------
# Create distributed firewall rules
#----------------------------------------------------------------------------------------------------------------------

$sequenceNumber = $startingSequenceNumber

for ($i = 1; $i -le $NumLabs; $i++) {
    $workloadVmGroupName = $groupNameTemplate -f $i, $workloadVmGroupNameSuffix
    $studentNetworkGroupName = $groupNameTemplate -f $i, $studentNetworkGroupNameSuffix

    $splat = @{
        Name             = "${workloadVmGroupName} > $studentNetworkGroupName"
        Section          = $name
        SequenceNumber   = $sequenceNumber++
        SourceGroup      = $workloadVmGroupName
        DestinationGroup = $studentNetworkGroupName
        Service          = 'Any'
        Action           = 'ALLOW'
    }
    New-NSXTDistFirewall @splat
}

$splat = @{
    Name             = 'quarantine'
    Section          = $name
    SequenceNumber   = $sequenceNumber++
    SourceGroup      = $studentRangeGroupName
    DestinationGroup = $studentRangeGroupName
    Service          = 'Any'
    Action           = 'DROP'
}
New-NSXTDistFirewall @splat
