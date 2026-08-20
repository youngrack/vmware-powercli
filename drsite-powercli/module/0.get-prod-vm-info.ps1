################################################
## prod-dr configuration vm create script
## 운영 site 복제 vm 정보 저장 및 dr nic portgroup 수정
## output : get-prod-vm-info.csv and modify csv file
################################################

#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false |out-null

# vcenter env file import
# ----vcenv.ps1----
# $vcsrv1="nutanixvc.vtstire.com"
# $vcuser1="administrator@vsphere.local"
# $vcpass1="Rktkdghk1!"
# $vcsrv2="nutanixvc.vtstire.com"
# $vcuser2="administrator@vsphere.local"
# $vcpass2="Rktkdghk1!"
# $fullpath="c:\temp3"
# $drmountvmhost="n-esx1.vtstire.com"
# $curvmfs="$fullpath\curvmfs.csv"
# $prodvminfo="$fullpath\get-prod-vm-info1.csv"
###############################################
if (!(Test-Path -path ./vcenv.ps1)) {
	write-host "vc env file not exist!!!"
	exit 1
}
else {
. ./vcenv.ps1
}


$con=connect-viserver -server $vcsrv1 -user $vcuser1 -pass $vcpass1

Get-VM |Where-Object {$_.name -notlike "vCLS*" -and $_.name -notlike "NTNX*"}|

Select @{N='HostName';E={$_.VMHost.Name}},Name,
    @{N='vmpathname';E={(get-view -viewtype VirtualMachine -filter @{Name=$_.name}).summary.config.vmpathname}},
    @{N='SrcPortgroup';E={(Get-NetworkAdapter -VM $_ -name "Network adapter 1").NetworkName }},
	@{N='TgtPortgroup';E={(Get-NetworkAdapter -VM $_ -name "Network adapter 1").NetworkName }}|export-csv -path $prodvminfo -NoTypeInformation -force

$discon=disconnect-viserver -server * -confirm:$false
