# DR Site with storage replication script
# 2. DR VM register & power-on
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

function check_vm_start($vmname)
{	
	$out=get-vm $vmname
 	$pwdstat=$out.PowerState
	
	$toolsrun=($out|get-view).guest.ToolsRunningStatus
	$output=1
	
	if($pwdstat -eq "PoweredOn" -and $toolsrun -eq "guestToolsRunning")
	{
		$output=0
	}
	# 0: 등록 성공, 1: 실패
	return $output
}

function check_vm_power($vmname)
{	
	$out=get-vm $vmname
 	$pwdstat=$out.PowerState
	
	$output=1
	
	if($pwdstat -eq "PoweredOn")
	{
		$output=0
	}
	# 0: power-on state, 1: power-off state
	return $output
}

function vm_register($drvmhost,$vmx)
{
	#write-host "function vm_reg : $drvmhost --- $vmx"
	$output=1
	$ds=$vmx.split(" ")[0].replace("[","").replace("]","")
	#$out=Get-VM -Datastore $ds | select Name,@{N='VMX';E={$_.ExtensionData.Summary.Config.VmPathName}}

	$dsout = Get-Datastore -Name $ds
	$out=New-PSDrive -Name TgtDS -Location $dsout -PSProvider VimDatastore -Root '\' | Out-Null
	$out1=(Get-ChildItem -Path TgtDS: -Filter *.vmx -Recurse).name
	$out=Remove-PSDrive -Name TgtDS


	#write-host "function vm_reg value ds --- out : $ds --- $out1 ( $($vmx.Split('/')[-1]) ) "
	if($out1 -contains $vmx.Split('/')[-1]) {
		#write-host " out1 -contins vms "
		$out2=new-vm -host $drvmhost -vmfilepath $vmx -location "dr-test" -runasync -ErrorAction Ignore
		#write-host "out1 => $out1"
		if($out2 -ne $null ) { $output=0 }
	}

	
	return $output # 0 : 등록, 1: 실패
}

function vm_nic_change($vmname,$apg,$bpg)
{
	$output=1
	#write-host "## function vm nic change : $vmname = apg : $apg - bpg : $bpg"
	$out=get-vm $vmname|Get-NetworkAdapter|Where-Object {$_.networkname -eq $apg}|Set-NetworkAdapter -NetworkName $bpg -startconnected:$true  -RunAsync -ErrorAction Ignore -confirm:$false
	if($out.count -ne 0) {
		$output=0
	}
	return $output # 0: 등록 성공, 1: 실패
}

function vm_on($vmname)
{
	$output=1
	$out=check_vm_power $vmname
	if($out -ne 0) {
		try {
			$out=start-vm $vmname -runasync -confirm:$false
			$output=0
		}
		catch {
			continue
		}
	}
	return $output # 0: 전원켜기 성공, 1: 실패
}

function dr_vm_add_start($drvms)
{
	# $drvms : dr용 vm 목록....
	#vm 등록전 있는지 확인 후 등록 요청	

	$output=0
	$actdrvms=@()

	$allvms=Get-vm ### vm 등록전 모든VM 정보 저장
	$allds=get-datastore

	$allpg = (get-vdportgroup).name  ### 분산 스위치용 pg 분산스위치 없으면 필요 없음
	
	### 1번 vm 등록
	foreach($drvm in $drvms)
	{
		#write-host "foreach #1 vm add start  [ $($drvm.name) ]"
		if($allvms.name -notcontains $drvm.name){   # vm이 등록 되어있는지 확인 후 없으면
			# 데이터스토어 유무 확인
			$drds=($drvm.vmpathname).split(" ")[0].replace("[","").replace("]","")

			if( $allds.name -contains $drds) # 데이터스토어가 있으면 vm등록하기
			{
				# vm 등록
				$fret1=vm_register $drvm.hostname $drvm.vmpathname
				#write-host " [ $($drvm.name) ] VM add - result : [ $fret1 ]!!"
				if($fret1 -ne 0 ) { 
					write-host "check : [ $($drvm.name) ] VM add error!! vmx file check !!!"
				} else { 
					write-host "ok : [ $($drvm.name) ] VM add success" 
					$actdrvms += $drvm 
					}
				$output += $fret1
			}
			else { 
			
				write-host "check : [ $($drvm.name) ] in datastore [ $drds ] or dr vm info file[ $drvminfo ] check!!"
				$output+=1
			}

		}
		else {
			write-host "ok : [ $($drvm.name) ] already add"
			$actdrvms += $drvm 
		}
	}
	
	if($actdrvms.count -ne 0) {
		### 2번 vm power-on ---수정할것
		start-sleep -second 5
		#$allvms=Get-vm ### vm등록 후 모든VM 정보 저장
		$allpg += (Get-VirtualPortGroup -vmhost $drvm.hostname -standard).name ###일반 스위치용
		foreach($drvm in $actdrvms)
		{
			$drvmstate=check_vm_power $drvm.name
			if( $drvmstate -eq 1 ) # 포트그룹이 있으면 vm등록하기
			{
					# vm nic change
					if($allpg -contains $drvm.TgtPortgroup -and $drvm.SrcPortgroup -ne $drvm.TgtPortgroup) {
						write-host "      change -> [ $($drvm.name) ] network change = $($drvm.SrcPortgroup) -> $($drvm.TgtPortgroup)"
						$fret2=vm_nic_change $drvm.name $drvm.SrcPortgroup $drvm.TgtPortgroup
					}
				
			}
		}
		### 3번 vm power-on ---수정할것
		foreach($drvm in $actdrvms)
		{
			$drvmstate=check_vm_power $drvm.name
			if( $drvmstate -eq 1 ) # 포트그룹이 있으면 vm등록하기
			{
				## VM이 있음..
				$fret3=vm_on $drvm.name ## 혹시 전원켜져있니?

				if($fret3 -ne 0 ) { 
					write-host " [ $($drvm.name) ] VM start error!! check vm !!!"
				} else { write-host "ok : [ $($drvm.name) ] VM power-on start success" }

				$output += $fret3
			}
		}
	}

	if($output -eq 0){
		write-host "ok : dr vm add & start : success"
	}
	else {
		write-host "check : dr vm add & start : fail(err cnt / total dr vms) = [ $output / $($drvms.count) ]"
	}
	#write-host "function dr vm add start --- end"
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

# 2. dr vm add & start
$ret1=dr_vm_add_start $alldrvm

# 3. vc disconn
$ret=vc_disconnect $retvc

Stop-Transcript | out-null
exit $ret1