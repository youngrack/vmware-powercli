#pci change hosts poweroff script

# pcichange-host.csv
# >> locate,vmhost
# >> s,192.168.0.7

$vmhosts=import-csv pcichange-host.csv

Connect-VIServer -server vcenter-ip -user administrator@vsphere.local -password PASSWORD

function vm-poweroff
{
	Write-Host vm-poweroff : $hostip start
	Get-VMHost -name $hostip | get-vm | stop-vm -RunAsync -ErrorAction Ignore -Confirm:$false
	Write-Host vm-poweroff : $hostip start
}

function vmhost-poweroff
{
	Write-Host vmhost-poweroff : $hostip start
	Set-VMHost -State Maintenance -VMHost $hostip
	Stop-VMHost -VMHost $hostip -Force -RunAsync -ErrorAction Ignore -Confirm:$false
	Write-Host vmhost-poweroff : $hostip start
}

####### main start ########
# $sb seoul / pusan idc
$sp = Read-Host -Prompt 'input group seoul or pusan [s/p]?'

$changehosts = $vmhosts | Where {$_.locate -eq $sp}
if($c.length -ge 1)
{
	Write-Host host down start
	foreach($chghost in $changehosts)
	{
		$hostip = $chghost.vmhost
		vm-poweroff $hostip
	}
#### sleep 
	start-sleep -s 10
	foreach($chghost in $changehosts)
	{
		$hostip = $chghost.vmhost
		vmhost-poweroff $hostip
	}
	Write-Host host down end
	#Disconnect-VIServer * -Confirm:$false
}
else
{
	Write-Host pci change host none!!
	#Disconnect-VIServer * -Confirm:$false
	exit
}

