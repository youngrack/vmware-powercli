$srv=connect-viserver -server vcsa01.hanaict.dom -user administrator@vsphere.local -password PASSWORD

$allhosts=@()
$allhostportgroups=@()
$allhostnicinfo=@()
$allhostdatastores=@()
$allvms=@()

function gethostinfo($vmhost)
{
	$data=""|select dcname,clustername,hostname,state,model,sn,socket,cores,proctype,memgb,vmk0ip,licensekey,version,build
	$ip=if($vmhost.state -eq 'Connect'){Get-VMHostNetworkAdapter -vmhost $vmhost -VMKernel -ErrorAction Ignore | where {$_.ManagementTrafficEnabled -eq 'True'} | select -first 1}
	$data.dcname=$dc.name
	$data.clustername=$vmhost.Parent.name
	$data.hostname=$vmhost.Name
	$data.state=$vmhost.State
	$data.model=$vmhost.ExtensionData.hardware.systeminfo.Model
	$data.sn=$vmhost.ExtensionData.hardware.systeminfo.SerialNumber
	$data.socket=$vmhost.ExtensionData.Hardware.CpuInfo.NumCpuPackages
	$data.cores=$vmhost.ExtensionData.Hardware.CpuInfo.NumCpuCores
	$data.proctype=$vmhost.ProcessorType
	$data.memgb=[math]::round($vmhost.MemoryTotalGB,0)
	$data.vmk0ip=$ip.ip
	$data.licensekey=$vmhost.LicenseKey
	$data.version=$vmhost.Version
	$data.build=$vmhost.Build
	return $data
	
}

function gethostportgroup($vmhost)
{
	$datapg=@()
	if($vmhost.state -eq 'Connect'){
		$vNicTab = @{}
		$vmhost.ExtensionData.Config.Network.Vnic | %{$vNicTab.Add($_.Portgroup,$_)}
		foreach($vsw in (Get-VirtualSwitch -VMHost $vmhost))
			{
			foreach($pg in (Get-VirtualPortGroup -VirtualSwitch $vsw))
				{
				$data=""|select dcname,clustername,hostname,state,vswname,vswactnic,vswstbnic,vswpgname,vswvlanid,vswdev,vswdevip
				$data.dcname=$dc.name
				$data.clustername=$vmhost.Parent.name
				$data.hostname=$vmhost.Name
				$data.state=$vmhost.State
				$data.vswname=$vsw.Name
				$actn=$vsw.ExtensionData.Spec.Policy.NicTeaming.NicOrder.ActiveNic
				$stbn=$vsw.ExtensionData.Spec.Policy.NicTeaming.NicOrder.StandbyNic
				$data.vswactnic=if($actn -ne $null) {[string]::Join(',',$actn)}else{' '}
				$data.vswstbnic=if($stbn -ne $null) {[string]::Join(',',$stbn)}else{' '}
				$data.vswpgname=$pg.Name
				$data.vswvlanid=$pg.VLanId
				$data.vswdev=if($vNicTab.ContainsKey($pg.Name)){$vNicTab[$pg.Name].Device}
				$data.vswdevip=if($vNicTab.ContainsKey($pg.Name)){$vNicTab[$pg.Name].Spec.Ip.IpAddress}
				$datapg+=$data
				}
			}
	}
	else {
		$data=""|select dcname,clustername,hostname,state,vswname,vswactnic,vswstbnic,vswpgname,vswvlanid,vswdev,vswdevip
		$data.dcname=$dc.name
		$data.clustername=$vmhost.Parent.name
		$data.hostname=$vmhost.Name
		$data.state=$vmhost.State
		$datapg+=$data
	}		
	return $datapg
}

function gethostnicinfo($vmhost)
{
	$datanic=@()
	if($vmhost.state -eq 'Connect'){
		$esxcli=Get-EsxCli -vmhost $vmhost
		
		$pcilists = @{}
		$esxcli.hardware.pci.list() | where {$_.VMkernelName -like 'vm*' } | %{$pcilists.add($_.VMkernelName,$_)}
		$hbas=Get-VMHostHba -type FibreChannel -vmhost $vmhost|where {$_.states -eq "online"}
		
		foreach($nic in $nics)
		{
			$data=""|select dcname,clustername,hostname,state,devname,linkstate,mac,module,version,devdescribe
			$data.dcname=$dc.name
			$data.clustername=$vmhost.Parent.name
			$data.hostname=$vmhost.Name
			$data.state=$vmhost.State
			$data.devname=$nic.name
			$data.linkstate=if($nic.BitRatePerSec -ne 0)
				{$duplex=if($nic.FullDuplex -eq "True"){'-Full'} else {'-Half'}
				[string]$nic.BitRatePerSec + $duplex} 
				else {'Down'}
			$data.mac=$nic.mac
			$data.module=if($pcilists.ContainsKey($nic.Name)){$pcilists[$nic.Name].ModuleName}
			$data1=$esxcli.system.module.get($data.module)
			$data.version=$data1.Version
			$data.devdescribe=if($pcilists.ContainsKey($nic.Name)){$pcilists[$nic.Name].DeviceName}
			$datanic+=$data
		}
	}
	else {
		$data=""|select dcname,clustername,hostname,state,devname,linkstate,mac,module,version,devdescribe
		$data.dcname=$dc.name
		$data.clustername=$vmhost.Parent.name
		$data.hostname=$vmhost.Name
		$data.state=$vmhost.State
		$datanic+=$data
	}		
	return $datanic
}

function gethosthbainfo($vmhost)
{
	$datahba=@()
	if($vmhost.state -eq 'Connect'){
		$esxcli=Get-EsxCli -vmhost $vmhost
		
		$pcilists = @{}
		$esxcli.hardware.pci.list() | where {$_.VMkernelName -like 'vm*' } | %{$pcilists.add($_.VMkernelName,$_)}
		$hbas=Get-VMHostHba -type FibreChannel -vmhost $vmhost|where {$_.states -eq "online"}
		
		foreach($nic in $nics)
		{
			$data=""|select dcname,clustername,hostname,state,devname,linkstate,mac,module,version,devdescribe
			$data.dcname=$dc.name
			$data.clustername=$vmhost.Parent.name
			$data.hostname=$vmhost.Name
			$data.state=$vmhost.State
			$data.devname=$nic.name
			$data.linkstate=if($nic.BitRatePerSec -ne 0)
				{$duplex=if($nic.FullDuplex -eq "True"){'-Full'} else {'-Half'}
				[string]$nic.BitRatePerSec + $duplex} 
				else {'Down'}
			$data.mac=$nic.mac
			$data.module=if($pcilists.ContainsKey($nic.Name)){$pcilists[$nic.Name].ModuleName}
			$data1=$esxcli.system.module.get($data.module)
			$data.version=$data1.Version
			$data.devdescribe=if($pcilists.ContainsKey($nic.Name)){$pcilists[$nic.Name].DeviceName}
			$datanic+=$data
		}
	}
	else {
		$data=""|select dcname,clustername,hostname,state,devname,linkstate,mac,module,version,devdescribe
		$data.dcname=$dc.name
		$data.clustername=$vmhost.Parent.name
		$data.hostname=$vmhost.Name
		$data.state=$vmhost.State
		$datanic+=$data
	}		
	return $datanic
}

$datacenters=Get-Datacenter
foreach ($dc in $datacenters)
{
	$vmhosts=get-vmhost -location $dc
	foreach ( $vmhost in $vmhosts )
	{
		$allhosts+=gethostinfo $vmhost
		#$allhostportgroups+=gethostportgroup $vmhost
		#$allhostnicinfo+=gethostnicinfo $vmhost
	}

}
$allhosts
#$allportgroups
#$allhostnicinfo
