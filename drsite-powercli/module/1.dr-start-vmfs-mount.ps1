# DR Site with storage replication script
# 1. DR Snapshot VMFS mount  
# Create by yrson
# First Date : 2024/11/12

$scriptName = $MyInvocation.MyCommand.Name
$platform = [environment]::OSVersion.platform
switch ( $platform ) {
	"Win32NT" { 
		$basepath = "c:\temp3\drsite"
		$envfile = "$basepath\module\dr-env.ps1"
	}
	"Unix" { 
		$basepath = "/root/drsite"
		$envfile = "$basepath/module/dr-env.ps1"
	}
}



#####################################################################
#####################################################################

# rescan all hba&vmfs...
function rescan_all_vmhosts($vcon) {
	$allvmhosts = (get-vmhost | Where-Object { $_.ConnectionState -eq "Connected" -and $_.PowerState -eq "PoweredOn" }).name
	foreach ($rhost in $allvmhosts) {
		get-VMHostStorage -VMHost $rhost -RescanAllHba
		get-VMHostStorage -VMHost $rhost -RescanVmfs
	}
	#Start-Sleep -Seconds 10
	return 0
}

function check_mount_datastore($cdshost, $cdsname) {
	# rerutn mounted = 0 , no mount = 1
	if ((get-datastore -vmhost $cdshost).name -contains $cdsname) {
		$out = 0
	}
	else {
		$out = 1
	}
	return $out
}


function mount_snapshot_datastore($drvmfs) {
	$errcnt = 0

	foreach ($dsinfo in $drvmfs) {
		$dsn = $dsinfo.dsname
		$dshost = $dsinfo.HostName
		
		#데이터스토어가 있는지 확인
		$chkds = check_mount_datastore $dshost $dsn
		#Write-Host "check data store return: $chkds"
		#write-host "chkds dshost dsn : $chkds/$dshost/$dsn"
		if ($chkds -ne 0) {
			## ds가 마운트 안되어있을 경우 snapshot volume mount 시작 
			#$vmhost1=get-vmhost $dshost
			$esxcli = get-esxcli -vmhost $dshost -v2
				
			$output = $esxcli.storage.vmfs.snapshot.list.invoke() ### 해당 ds가 snapshot vmfs인지 확인
			#write-host $output.count
	
			if ($output.count -ne 0) {
				### snap vmfs 가 있으면... mount..
				$sret = ($output | Where-Object { $_.canmount -eq "true" -and $_.volumename -eq $dsn }).count
				if ($sret -eq 1) {
					try {
						$label = @{volumelabel = $dsn }
						$output1 = $esxcli.storage.vmfs.snapshot.mount.invoke($label)
						write-host "ok : snapshot datastore [ $dsn ] mount"
					}
					catch { 
						write-host "check : snapshot datastore [ $dsn ] mount error. check!!"
						$errcnt += 1
					}
				}
				elseif (($output | Where-Object { $_.canmount -ne "true" -or $_.volumename -ne $dsn }).count -eq 1) {
					write-host "check : snapshot datastore [ $dsn ] lun suspand/split check!!"
					$errcnt += 1
				}
			}
			else {
				## snap vmfs가 없음...
				write-host "check : snapshot datastore [ $dsn ] vmfs none exist check!!"
				$errcnt += 1
			}
		}
		else {
			## 이미 마운트 되어있음...
			write-host "ok : snapshot datastore [ $dsn ] already mounted !!"
		}
	}	

	if ($errcnt -eq 0) {
		write-host "ok : all dr datastore mount : success"

	}
	else {
		write-host "check : dr datastore [err cnt / total dr datastore] = [ $errcnt / $($drvmfs.count) ]"

	}

	return $errcnt
}



##############################################################
###################MAIN#######################################
##############################################################

## 0. dr env file exist check and dr datastore info import
##############################################################
if (!(Test-Path -path $envfile)) {
	write-host "dr env file not exist!!!"
	exit 1
}
else {
	# 설정 파일 import 
	. $envfile

	
	# dr ds 정보 파일 확인 / 파일이 없으면 exit
	if (!(Test-Path -path $drdsinfo)) {
		write-host "dr datastore config file not exist!!! check config file.."
		exit 1
	}
	else {
		# dr datastore 정보import
		$allsnapvmfs = import-csv $drdsinfo
	}
}



Start-Transcript -path $scriptLog -append
##conn vc
# 1. vc conn
$retvc = vc_connect

# 2. rescan all host
$ret1 = rescan_all_vmhosts $retvc

# 3. snapshot datastore query & mount
$ret2 = mount_snapshot_datastore $allsnapvmfs

# 4. rescan all host
$ret3 = rescan_all_vmhosts $retvc

# 5. vc disconn
$ret = vc_disconnect $retvc

Stop-Transcript | out-null

exit $ret2