# create by yrson
# 2021.03.15
# horizon desktop reset powercli script
# version : 0.1

## 기본 변수
$tdate = (get-date -Format 'yyyyMMdd')
$tt=get-date
$pwdloc=get-location
#$outputfile="c:\script\reset-desktop-output-$($tdate).out"
$outputfile="c:\script\reset-desktop-output.out"

# reset 대상 vm 파일
$resetcsvfile = "c:\script\reset-desktop-giivdi.csv"

## 연결서버 및 vcenter 서버정보
$cssrv = '172.16.100.44' #Horizon Connection Server
$csdomain = 'gii-vdi.local' #Horizon Domain
$csuser = "vdiadmin" # Horizon user
$cspass="VMware1!" # 암호저장

$vcsrv = '172.16.100.20' #vCenter Server
$vcuser = "administrator@gii.local" # vCenter user
$vcpass="GIIvdi1!" # 암호저장


function vcconnect
{
    Param([string]$connvcsrv)
    # vcenter connect
    $vcconn = Connect-VIServer -server $connvcsrv -user $vcuser -password $vcpass -ErrorAction ignore
    if (!($vcconn)) {
        Write-Warning " $connvcsrv : vcenter not connect." 
        Write-host " >> check Srv name or username and passowrd !! "
        write-host "Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false"
        write-host ""
        exit
    }
    else {write-host " Connect $connvcsrv server : success"}
}

function hvconnect
{
    Param([string]$connhvsrv)
    # horizon connect server connect
    $hvconn = Connect-HVServer -server $connhvsrv -user $csuser -domain $csdomain -password $cspass -ErrorAction ignore
    if (!($hvconn)) {
        Write-Warning " $connhvsrv : horizon connect server not connect." 
        Write-host " >> check Srv name or username and passowrd !! "
        write-host "Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false"
        write-host ""
        exit
    }
    else {write-host " Connect $connhvsrv server : success"}
}

#################### main start ##################

# powercli module check
if(!$(Get-InstalledModule -name VMware.VimAutomation.Core)){
    Write-Warning " >> Check VMware powercli module install~~"
    Write-Host ""
    exit
}
else {
    import-module VMware.VimAutomation.Core
}

# vcenter connect
vcconnect $vcsrv
# horizon connect
#hvconnect $cssrv


$tt | out-file -filepath $outputfile -append # 날짜 > output 파일에 저장

$resetcsvs=import-csv $resetcsvfile

foreach($resetvm in $resetcsvs)
{
   if( $(get-vm $resetvm.vmname).powerstate -eq "PoweredOn" ) 
    {
        $resetlists+=${resetvm}.vmname
        $result=(get-vm $resetvm.vmname|get-view).guest.toolsstatus
#        if( $result -eq "toolsOK") 
#        {
#            "$($resetvm.vmname) is guest restart!!" | out-file -filepath $outputfile -append
#            $rst=restart-vmguest -vm $resetvm.vmname -confirm:$false -ErrorAction Ignore
#        }
#        else 
#        {
            "$($resetvm.vmname) is power reset!!" | out-file -filepath $outputfile -append
            $rst=restart-vm -vm $resetvm.vmname -confirm:$false -ErrorAction Ignore
#        }
          
    }
}
