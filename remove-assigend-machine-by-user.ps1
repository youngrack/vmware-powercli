## machine delete by username
## 사용자정보(csv)를 읽어 특정 Pool에 할당된 machine 삭제 shell
## horizon v8 build 2012 & vcenter 7

# remove-assigend-machine-by-user.csv
# username
# yrson

########################################
################ env ####################
import-module vmware.hv.helper


$vc="172.16.100.20"
$vcuser="administrator@gii.local"
$vcpass="GIIvdi1!"

$hv="172.16.100.44"
$hvuser="vdiadmin"
$hvpass="VMware1!"
$hvdomain="gii-vdi.local"

$csvfile="c:\script\remove-assigend-machine-by-user.csv"

$fcpoolname="giivdi"
########################################

########## server connect ##################
$vcconn=Connect-VIServer -Server $vc -user $vcuser -password $vcpass -ErrorAction ignore
if (!($vcconn)) {
	Write-Warning " vcenter server connect error!!." 
	exit
}
$hvconn=Connect-HVServer -Server $hv -User $hvuser -Password $hvpass -Domain $hvdomain -ErrorAction ignore
if (!($hvconn)) {
	Write-Warning " horizon connect server connect error!!." 
	exit
}
########################################

#### hv machine 삭제 및 vm삭제
function delmachine
{
	Param([string]$machinename)
	$ret=Remove-HVMachine -MachineNames $machinename -DeleteFromDisk -Confirm:$false -ErrorAction ignore
	start-sleep 30
	if($ret){
		write-host " $machinename : delete"
	}
}

$deleteusermachine=import-csv $csvfile

$desktops=Get-HVMachineSummary -PoolName $fcpoolname

$dellist = @()

foreach($deluser in $deleteusermachine){
	get-aduser -identity $($deluser.username) -Properties *|select samaccountname,displayname,mobilephone,emailaddress,Description
	$yn=read-host -prompt "Check user/description & delete assign machine (y/n)?"
	if( $yn -eq "y" ) {
		foreach($desktop in $desktops){
			$asdesk=$desktop.base.name
			$asuser=$($desktop.namesdata.usernames) -creplace "$($hvdomain)\\",""
			if($asuser -eq $deluser.username){
				$yn1=read-host -prompt "$asdesk / $asuser => delete (y or n)?"
				if( $yn1 -eq "y" ) {
					delmachine $asdesk
					$dellist += $asdesk
				}
			}
		}
	}
	else {
		write-host "$($deluser.username) : user not delete"
	}
}

if($dellist) {
	write-host "delete machines"
	write-host $dellist
}

$anykey=read-host -prompt "Press any key to exit"