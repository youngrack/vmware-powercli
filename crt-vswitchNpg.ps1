#! /usr/bin/pwsh
Connect-VIServer -Server vcenter-ip -user administrator@vsphere.local -pass PASSWORD

$vmhostlist=@("esxi1","esxi2")

foreach($hname in $vmhostlist)
{
	$vmh=$hname

	$vswname="vSwitch4-virtual"
	$actnic="vmnic0"
	$stbynic="vmnic1"
	$pgname1="pg-abcd1"
	$pgname2="pg-abcd2"

	$vname = New-VirtualSwitch -vmhost $vmh -Name $vswname
#	$vname = New-VirtualSwitch -vmhost $vmh -Name $vswname -nic $actnic,$stbynic
#	$vs1=Get-VirtualSwitch -VMHost $vmh -Name $vswname | Get-NicTeamingPolicy 
#	$vs1 | Set-NicTeamingPolicy -MakeNicActive $actnic -MakeNicStandby $stbynic -FailbackEnabled $false

	New-VirtualPortGroup -VirtualSwitch $vname -Name $pgname1 -vlanid 11
	New-VirtualPortGroup -VirtualSwitch $vname -Name $pgname2 -vlanid 12
}
disconnect-viserver -server * -Confirm:$false
