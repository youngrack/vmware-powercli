
## csv import
$snapshotvms=import-csv snapshot-vms.csv

## connect vCenter server
$conn=connect-viserver -server 192.168.0.10 -user administrator@vsphere.local -pass VMware1!  ### 연결하는 vcenter에 맞게 수정

## 날짜 format
$datefmt = get-date -format "yyyyMMdd-HHmm"

foreach($vm in $snapshotvms){
	$vmname=$vm.name
	$scount=get-vm $vmname|get-snapshot|measure

	# snapshot count가 1이상이면 snapshot삭제
	if($scount.count -ge 1)
	{
		$ret1=get-vm $vmname|get-snapshot|remove-snapshot -confirm:$false
	}
	
	# vm snapshot 시작
	$ret2=new-snapshot -vm $vmname -name $vmname_$datefmt -memory:$false -confirm:$false
}

$disc=disconnect-viserver -server * -confirm:$false