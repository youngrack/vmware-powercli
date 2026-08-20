param(
    [string]$vcsrv,
    [switch]$credential
    )

<#
.SYNOPSIS
    create a vcenter monthly cpu/mem usage report to excel.
.DESCRIPTION
    create vmhost cpu/mem monthly data report to excel chart
    require file : vcenter.cred
.NOTES
    File Name      : new-vcenter-month report.ps1
    Author         : yrson
    Prerequisite   : PowerShell V2 over Vista and upper.
    Create Date    : 2020. 09. 07
    Version        : V0.2
    Copyright 2020 yrson all rights reserved.
.LINK
    http://www
.EXAMPLE
    new-vcenter-month report.ps1 [vcenter name]
     -> out file : vcenter-[yyyy-MM-dd].xlsx
#>
if(!$(Get-InstalledModule -name VMware.VimAutomation.Core)){
    Write-Warning " >> Check VMware powercli module install~~"
    Write-Host ""
    exit
}
else {
    import-module VMware.VimAutomation.Core
}

$defvcsrv='vcenter-ip'
$defvcuser='administrator@vsphere.local'
$defvcpass='PASSWORD'

$tdate = (get-date -Format 'yyyyMMdd')
$tt=get-date
$lyear=($tt).addmonths(-1).year
$lmonth=($tt).addmonths(-1).Month
$tyear=($tt).year
$tmonth=($tt).Month
$stdate = "$lmonth/01/$lyear" | Get-Date
$etdate = "$tmonth/01/$tyear" | Get-Date
$pwdloc=get-location
$outputfile="$pwdloc\report-$($lyear)$($lmonth)-$tdate.xlsx"
$credfile="$pwdloc\vc.cred"
$scriptName = $MyInvocation.MyCommand.Name

function new-cred
{
    Param([string]$srv)
    write-host " create credential function "
    write-host ""

    $crdvcsrv = Read-Host -Prompt "Input vCenter server name[ $srv ] "
    if($crdvcsrv -eq ""){ $crdvcsrv=$srv }
    $vcuser = Read-Host -Prompt "Input vCenter user[ $defvcuser ] "
    if($vcuser -eq ""){ $vcuser=$defvcuser }
    $vcpass = Read-Host -Prompt "Input users password[ $defvcpass ] "
    if($vcpass -eq ""){ $vcpass=$defvcpass }

    $result1=New-VICredentialStoreItem -host $crdvcsrv -user $vcuser -password $vcpass -file $credfile
    if($result1){
    write-host " $crdvcsrv server create credential : success"
    write-host " re run~~"
    write-host ""
    }
    exit
    

}

function vcconnect
{
    Param([string]$connvcsrv)
    # vcenter connect
    if (!(Test-Path $credfile)) {
        Write-Warning "$credfile File is not exist."
        write-host " >> create $credfile file.."
        write-host ""
        write-host " >>>> $scriptname [-s vcsrv ] -c"
        write-host ""
        new-cred $connvcsrv
        exit
    }
    $cred=Get-VICredentialStoreItem -host $connvcsrv -File $credfile -ErrorAction Ignore
    if (!($cred)) {
        Write-Warning " $connvcsrv host credential is not exist." 
        Write-host " >> check Srv name or create $credfile file"
        write-host ""
        write-host " >>>> $scriptname [-s vcsrv ] -c"
        write-host ""
        new-cred $connvcsrv
        exit
    }

    $vcconn = Connect-VIServer -server $connvcsrv -user $($cred.user) -password $($cred.password) -ErrorAction ignore
    if (!($vcconn)) {
        Write-Warning " $connvcsrv : vcenter not connect." 
        Write-host " >> check Srv name or username and passowrd !! "
        write-host "Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false"
        write-host ""
        exit
    }
    else {write-host " Connect $connvcsrv server : success"}
}
function outfilecheck
{
    ## out file check
    ###chk1 : file open check

    #$file = New-Object -TypeName System.IO.FileInfo -ArgumentList $outputfile
    #$ErrorActionPreference = "SilentlyContinue"
    #[System.IO.FileStream] $fs = $file.OpenWrite(); 
    #if (!$?) {
    #    write-warning "$outputfile is opened : close and re run script!!"
    #    write-host ""
    #    exit
    #}
    ###chk2 : file exist check
    $r=Test-Path $outputfile
    #write-host "check "+$r
    #Get-ChildItem -Path $pwd
    #write-host "Get-ChildItem -Path $($pwd)\* -Include report*"
    if ($r) {
        #write-host "Test-Path $outputfile"
        $dest="$outputfile.bak"
        #write-host "move $outputfile to $dest"
        #write-host "move-item -path $outputfile -Destination $dest -force:$true -confirm:$false"
        move-item -path $outputfile -Destination $dest -force:$true -confirm:$false
        write-host " >>  existed file is moved : $dest"
        write-host ""
    }
}

###########################################################################
#####################           main              #########################
###########################################################################

if(!$($vcsrv)){$vcsrv=$defvcsrv}

# switch
if($credential){
    crt-cred $vcsrv
}

# call outputfile check
outfilecheck

# call vc connect function
vcconnect $vcsrv

# excel env 
$excel = New-Object -ComObject excel.application
$excel.visible = $true

# esxi usages(cpu/mem) data to excel
write-host ""
write-host "      >>>>>> last month esxi usages(cpu/mem) data collect and exec write...."
$hosts = Get-VMHost|Sort-Object name

$wb = $excel.Workbooks.Add()
$wscnt=1
for($i;$i -le $hosts.length;$i++){
    $null = $wb.worksheets.add()
}

foreach($vmhost in $hosts){
    $statcpu = Get-Stat -Entity ($vmHost) -start ($stdate) -Finish ($etdate) -MaxSamples 10000 -stat cpu.usage.average|Sort-Object timestamp
    $statmem = Get-Stat -Entity ($vmHost) -start ($stdate) -Finish ($etdate) -MaxSamples 10000 -stat mem.usage.average|Sort-Object timestamp

    $ws = $wb.worksheets.Item($wscnt)
    $ws.name = $vmhost.name
    $ws.Cells.Item(1,2) = "DATE"
    $ws.Cells.Item(1,3) = "CPU"
    $ws.Cells.Item(1,6) = "DATE"
    $ws.Cells.Item(1,7) = "MEM"

	foreach($i in 0..($statcpu.length - 1)){
        $ws.Cells.Item(($i+2),2) = [string]($statcpu[$i].timestamp).month+'-'+[string]($statcpu[$i].timestamp).day
        $ws.Cells.Item(($i+2),3) = $statcpu[$i].value
        $ws.Cells.Item(($i+2),6) = [string]($statcpu[$i].timestamp).month+'-'+[string]($statcpu[$i].timestamp).day
        $ws.Cells.Item(($i+2),7) = $statmem[$i].value
    }
    
    #cpu chart
    $Dataforcpuchart = $ws.Range("B1").CurrentRegion
    $cpuchart = $ws.Shapes.AddChart().Chart
    $cpuchart.chartType = 4
    $cpuchart.SetSourceData($Dataforcpuchart)
    $cpuchart.HasTitle = $true
    $cpuchart.ChartTitle.Text = $ws.name + " CPU(%)"
    $ws.shapes.item("Chart 1").top = 0
    $ws.shapes.item("Chart 1").left = 450
    $ws.shapes.item("Chart 1").width = 450
    $cpuchart.Axes(2).MaximumScale = 100
    
    #mem chart
    $DataformemChart = $ws.Range("F1").CurrentRegion
    $memchart = $ws.Shapes.AddChart().Chart
    $memchart.chartType = 4
    $memchart.SetSourceData($DataformemChart)
    $memchart.HasTitle = $true
    $memchart.ChartTitle.Text = $ws.name + " MEM(%)"
    $ws.shapes.item("Chart 2").top = 250
    $ws.shapes.item("Chart 2").left = 450
    $ws.shapes.item("Chart 2").width = 450
    $memchart.Axes(2).MaximumScale = 100

    $wscnt++
}

#$wb.Worksheets.Item("Sheet1").Delete()
## disconnect vcenter
disconnect-viserver -server $vcsrv -force -confirm:$false
#save & closing the file
$excel.DisplayAlerts = $False
$wb.SaveAs($outputfile)
$excel.Quit()
write-host ""
write-host " output file is : $outputfile"
write-host ""
