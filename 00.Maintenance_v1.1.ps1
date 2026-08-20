import-module VMware.VimAutomation.Core

#$cred=Get-VICredentialStoreItem -host vcenter-ip -File C:\scripts\vmware\vcenter.cred
#$vcconn = Connect-VIServer -server vcenter-ip -user $cred.user -password $cred.password

$allhosts = @()
$hosts = Get-VMHost
$tdate = (get-date -Format 'yyyy-MM-dd')

$tt=get-date
$tyear=($tt).addyears(-1).year
$tmonth=($tt).addmonths(-1).Month
$tday=[DateTime]::DaysInMonth($tyear, $tmonth)

$stdate = "$tmonth/01/$tyear" | Get-Date
$etdate = "$tmonth/$tday/$tyear" | Get-Date

#00_Usage Computing
foreach($vmHost in $hosts){
    $hoststat = "" | Select HostName, DiskMax, DiskAvg, MemMax, MemAvg, CPUMax, CPUAvg
    $hoststat.HostName = $vmHost.name
    $statcpu = Get-Stat -Entity ($vmHost) -start $stdate -Finish ($etdate) -MaxSamples 10000 -stat cpu.usage.average
    $statmem = Get-Stat -Entity ($vmHost) -start $stdate -Finish ($etdate) -MaxSamples 10000 -stat mem.usage.average
    $statdisk = Get-Stat -Entity ($vmHost) -start $stdate -Finish ($etdate) -MaxSamples 10000 -stat disk.usage.average
    $cpu = $statcpu | Measure-Object -Property value -Average -Maximum
    $mem = $statmem | Measure-Object -Property value -Average -Maximum
    $disk = $statdisk | Measure-Object -Property value -Average -Maximum
    $hoststat.CPUMax = [math]::Round($cpu.Maximum,2)
    $hoststat.CPUAvg = [math]::Round($cpu.Average,2)
    $hoststat.MemMax = [math]::Round($mem.Maximum,2)
    $hoststat.MemAvg = [math]::Round($mem.Average,2)
    $hoststat.DIskMax = [math]::Round($disk.Maximum,2)
    $hoststat.DiskAvg = [math]::Round($disk.Average,2)
    $allhosts += $hoststat
}
$allhosts | Select HostName, CPUMax, CPUAvg, MemMax, MemAvg, DiskMax, DiskAvg | sort-object HostName | Export-Csv "00_Useage_Compute_$tdate.csv" -noTypeinformation

#01_Usage datastores
$datastores = Get-datastore | Get-view 
$datas = $datastores | select -expandproperty summary | select name, 
    @{N=”Capacity”; E={[math]::round($_.Capacity/1GB,2)}}, 
    @{N=”FreeSpace”;E={[math]::round($_.FreeSpace/1GB,2)}}, 
    @{N=”UsagePercent”; E={[math]::round(($_.Capacity – $_.FreeSpace) / $_.Capacity * 100,2)}}
$allDatastores += $datas
$allDatastores | Select Name, Capacity, FreeSpace, UsagePercent | sort-object Name | Export-Csv "01_Usage_Datastore_$tdate.csv" -noTypeinformation

#02_Service_Status
Get-VMHost | Sort-Object Name | Get-VMHostService | Select-Object -Property VMHost, Key, Policy, Running | Export-Csv "02_Service_Status_$tdate.csv" -noTypeinformation

#03_Cluster_Information
$Result = @()
$clusters = Get-Cluster | Sort-Object Name
Foreach($cluster in $clusters){
    $clusterName = $cluster.Name    
    $esxi = $cluster | Get-VMHost
    $vms = $cluster | Get-VM
    $datastores = $cluster | Get-Datastore | Where Type -eq "VMFS" 
    $VMCount = 0 + $vms.Count
    $rows = "" | Select clusterName, TotalCpuClock, TotalvCPU, TotalvMem, TotalvDisk, hostCount, datastoreCount, VMCount
    $rows.clusterName = $clusterName
    $rows.TotalCpuClock = [math]::round(($esxi.CpuTotalMhz | Measure-Object -Sum).Sum / 1000, 2)
    $rows.TotalvCPU = ($esxi.NumCpu | Measure-Object -Sum).Sum
    $rows.TotalvMem = [math]::round(($esxi.MemoryTotalGB | Measure-Object -Sum).Sum, 2)
    $rows.TotalvDisk = [math]::round(($datastores.CapacityGB | Measure-Object -Sum).Sum / 1000, 2)
    $rows.hostCount = $esxi.Count
    $rows.datastoreCount = $datastores.Count
    $rows.VMCount = $VMCount
    $Result += $rows
}
$Result | Export-Csv "03_Cluster_Info_$tdate.csv" -noTypeinformation
