# DR Site with storage replication script
# 0. DR environment setting
# Create by yrson
# First Date : 2024/11/12
#
## 참고
## Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false
## Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false |out-null
## sed 's/\$envpath=\"\/root\/drsite\/bin\/module\"/\$envpath=\"\/root\/drsite\/test\/test11\"/' 1.dr-start-vmfs-mount.ps1 >11


$version="V0.0.2"

### real vcenter info 
$vcsrv1="nutanixvc.vtstire.com"
$vcuser1="administrator@vsphere.local"
$vcpass1="Rktkdghk1!"

### dr vcenter info
$vcsrv2="nutanixvc.vtstire.com"
$vcuser2="administrator@vsphere.local"
$vcpass2="Rktkdghk1!"
	
$time=get-date -format "yyyyMMdd_HHmm"

switch ( $platform )
{
	"Win32NT" { 
		$drvminfo="$basepath\conf\dr-vm-info1.csv"       ### DR vm 정보
		$drdsinfo="$basepath\conf\dr-ds-info1.csv"       ### DR datastore 정보
		$scriptLog = "$basepath\log\$($scriptName)_$($time).log"
		}
	"Unix" { 
		$drvminfo="$basepath/conf/dr-vm-info1.csv"
		$drdsinfo="$basepath/conf/dr-ds-info1.csv"
		$scriptLog = "$basepath/log/$($scriptName)_$($time).log"
		}
}

function vc_connect(){
	$con=connect-viserver -server $vcsrv2 -user $vcuser2 -pass $vcpass2
	return $con
}

function vc_disconnect($vcon){
	$con=disconnect-viserver -server $vcon -confirm:$false
	return $con
}