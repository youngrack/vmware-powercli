# DR Site with storage replication script
# K1. DR VM power-off & unregister  
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

####################################################################
####################################################################

function check_vm_power($vmname)
{	
	$out=get-vm $vmname
 	$pwdstat=$out.PowerState
	
	$output=1
	
	if($pwdstat -eq "PoweredOn")
	{
		$output=0
	}
	# 0: 전원 on stat, 1: off stat
	return $output
}

function vm_unregister($vmname)
{
	$out=check_vm_power $vmname
	if( $out -eq 1 ){
		$out1=Remove-VM $vmname -RunAsync -Confirm:$false
		$output=0
	}
	else {
		$output=1
	}
	return $output # 0: 등록 성공, 1: 실패
}

function vm_off($vmname)
{
	#write-host " function : vm-off start"
	
	$retrycnt=3
	for ($i=1; $i -le $retrycnt; $i++)
	{
		#write-host "retry count : $i"
		$out=check_vm_power $vmname # 0: 전원 on status, 1: off status
		if($out -eq 0) { #power-on 인 경우 kill
			try {
				$out1=stop-vm $vmname -kill -runasync -confirm:$false
				write-host $out1
				start-sleep 5
				$output=0
			}
			catch {
				$output=1 ##vm 종료 안됨~~~
				#write-host " vm [ $vmname ] stop error check!!~~~~~"
				break
			}
		}
		else { # 이미 power-off인 경우 
			$output=0
			break
		}
	}

	return $output # 0: 전원off 성공, 1: 실패
}

function dr_vm_remove_stop($drvms)
{
	# $drvms : dr용 vm 목록....
	# vm 등록 전 있는지 확인 후 등록 요청	
	# "HostName","Name","vmpathname","SrcPortgroup","TgtPortgroup"
	# "n-esx1.vsphere.com","test-vm1","[iscsi-cl1] test-vm1/test-vm1.vmx","VM Network","dvs02-192.168.150.x"

	$output=0

	$allvms=Get-vm ### 모든VM 정보 저장
	$actdrvms=@()
	
	## 1. 전체 vm 종료
	foreach($drvm in $drvms)
	{
		#write-host " drvm.name : $($drvm.name) "
		if($allvms.name -contains $drvm.name){   # vm이 등록 되어있는지 확인 후 있으면
			$out=vm_off $drvm.Name
			write-host " vm power-off start : $($drvm.name) - [ $out ] "
			$actdrvms += $drvm
		}
		else { #vm 이 없으면.....작업할것 
				write-host "check : [ $($drvm.name) ] not exist. [ $drvminfo ] file check!!"
				$output+=1
		}
	}

	## 2. active dr(poweroffed) vm remove
	#$output=0
	foreach($drvm in $actdrvms)
	{
		$out=check_vm_power $drvm.Name    # 0: 전원 on stat, 1: off stat
		#write-host " before vm remove - vm check : $out"
		if( $out -eq 1 ) { #vm이 종료되면, vm unregister
			###
			$out1=vm_unregister $drvm.Name
			if( $out1 -ne 0 ) { # vm remove 결과 확인
				write-host "check : vm [ $($drvm.Name) ] remove(unregister) error check~~~~~"
				$out2=1
			}
			else { 
				write-host "ok : vm [ $($drvm.Name) ] remove(unregister) success"
				#$out2=0
			}
		}
		else { ## vm stop error
			write-host "check : vm [ $($drvm.Name) ] stop error check~~~~~"
			$out2=1
		}
		
		$output += $out2
	}
	
	### 결과 반환
	if($output -eq 0){
		write-host "ok : dr vm stop & remove : success"
	}
	else {
		write-host "check : dr vm stop & remove : fail(err cnt / total dr vms) = [ $output / $($drvms.count) ]"
	}
	return $output  # 0: 성공, 1: 실패
}



##############################################################
###################MAIN#######################################
##############################################################

## 0. dr env file exist check and dr vm info import
##############################################################
if (!(Test-Path -path $envfile)) {
	write-host "dr env file not exist!!!"
	exit 1
}
else {
	# 설정 파일 import 후 dr ds 정보 파일 확인 / 파일이 없으면 exit
	. $envfile
	
	# dr vm 정보파일 확인후 import
	if (!(Test-Path -path $drvminfo)) {
		write-host "dr vm config file not exist!!! check config file.."
		exit 1
	}
	else {
		# dr vm 정보 import
		$alldrvm=import-csv $drvminfo
	}
}

Start-Transcript -path $scriptLog -append

##conn vc
# 1. vc conn
$retvc=vc_connect

# 2. dr vm stop & remove
$ret1=dr_vm_remove_stop $alldrvm

# 3. vc disconn
$ret=vc_disconnect $retvc

Stop-Transcript | out-null
exit $ret1