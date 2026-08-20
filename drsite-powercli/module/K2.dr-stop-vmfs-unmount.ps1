# DR Site with storage replication script
# K2. DR Snapshot VMFS unmount  
# Create by yrson
# First Date : 2024/11/12

$scriptName = $MyInvocation.MyCommand.Name
$platform=[environment]::OSVersion.platform
switch ( $platform )
{
    "Win32NT" { 
		$basepath="c:\temp3\drsite"
		$envfile="$basepath\module\dr-env.ps1"
		}
    "Unix" { 
		$basepath="/root/drsite"
		$envfile="$basepath/module/dr-env.ps1"
		}
}



#####################################################################
#####################################################################

# rescan all hba&vmfs...
function rescan_all_vmhosts($vcon){
	$allvmhosts=(get-vmhost|Where-Object{$_.ConnectionState -eq "Connected" -and $_.PowerState -eq "PoweredOn"}).name
	foreach($rhost in $allvmhosts){
		get-VMHostStorage -VMHost $rhost -RescanAllHba
		get-VMHostStorage -VMHost $rhost -RescanVmfs
	}
	#Start-Sleep -Seconds 10
	return 0
}

# snapshot vmfs mount status check 배열 $chkds (vmhost,dsname)
function check_ds_unmount_status($chkds){
	## check datastore mount status
	$retcnt=0
	$retdsn=@()

	foreach($dsinfo in $drvmfs){
		$dsn=$dsinfo.dsname
		$dshost=$dsinfo.HostName
		$ret=check_mount_datastore $dshost $dsn
		#write-host "chk mnt : $dshost $dsn $ret"
		
		$retcnt += $ret
	}

	
	write-host "dr datastore unmount status [ err count / total ds ]: [ $retcnt / $($chkds.count) ]"
	

	return $retcnt
}

function check_mount_datastore($cdshost,$cdsname)
{
	# rerutn mounted = 0 , no mount = 1
	if((get-datastore -vmhost $cdshost).name -contains $cdsname){
		$out=0
	}
	else{
		$out=1
	}
	return $out
}

function unmount_snapshot_datastore($drvmfs)
{
	$errcnt=0
	foreach($dsinfo in $drvmfs){
		$dsn=$dsinfo.dsname
		$dshost=$dsinfo.HostName
		#write-host "$dshost ---- $dsn"
		#데이터스토어가 있는지 확인
		$chkds=check_mount_datastore $dshost $dsn
		#write-host "chkds dshost dsn : $chkds/$dshost/$dsn"
		if($chkds -ne 1) { ## ds가 마운트되어있는 경우 unmount시작 
			$ds = Get-Datastore -Name $dsn
			$esx = Get-VMHost -Name $dshost

			$storSys = Get-View $esx.ExtensionData.ConfigManager.StorageSystem
			$storSys.UnmountVmfsVolume($ds.ExtensionData.Info.vmfs.uuid)
			write-host "ok : [ $dsn ] unmount dr datastore : success"
		}
		else { ## 마운트 안되어있는 경우
			$esxcli = get-esxcli -vmhost $dshost -v2
			#$label=@{volumelabel = $dsn}
	
			$dslist=$esxcli.storage.vmfs.snapshot.list.invoke() ### 해당 ds가 snapshot vmfs인지 확인
			if($dslist.volumename -contains $dsn) { ## snapshot vmfs 에 있으면
				write-host "ok : [ $dsn ] already unmount dr datastore : success"
			}
			else {
				write-host "check : [ $dsn ] dr datastore dr datastore info file check !!"
				$errcnt+=1
			}
		}
	}

	$ret3=rescan_all_vmhosts $retvc
	
	#check snapshot vmfs unmount status
	### 결과 반환
	if($errcnt -eq 0){
		write-host "ok : unmount dr datastore : success"
		$output=0
	}
	else {
		write-host "check : unmount dr datastore fail [ err cnt / total dr vms ] = [ $errcnt / $($drvmfs.count) ]"
		$output=1
	}
	return $output  # 0: 성공, 1: 실패
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
		$allsnapvmfs=import-csv $drdsinfo
	}
}



Start-Transcript -path $scriptLog -append
##conn vc
# 1. vc conn
$retvc=vc_connect

# 2. rescan all host
#$ret1=rescan_all_vmhosts $retvc

# 3. snapshot datastore query & unmount
$ret2=unmount_snapshot_datastore $allsnapvmfs

# 4. rescan all host
#$ret3=rescan_all_vmhosts $retvc

# 5. vc disconn
$ret=vc_disconnect $retvc

Stop-Transcript | out-null
exit $ret2