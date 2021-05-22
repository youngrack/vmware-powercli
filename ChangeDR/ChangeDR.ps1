<# 
    ChangeDR.ps1
    Created By: yrson@hanaict.co.kr
    Description: Change TEST to DR or DR to TEST
    Create Date : 2020. 05. 17.
    Version History
        0.1   -   Intial Release - 2020-05-17
#>

<# changedr.csv data structure
  Start order - 시작순서(ex db -> ap)
  HostName - VM Name
  ClusterName - VM Cluster Name
  Market - VM Market
  Type - DR/TEST
  Notes - VM Description
  DC - Virtual Data Center
  NormalCore - CPU Core Count in Normal Environment
  DRCore - CPU Cores Count in DR Environment
  NormalMemory - Memory GB in Normal Environment
  DRMemory - Memory GB in DR Environment
  Notes - Description
  ReservedRatio - Reserved Memory Percentage
#>

# Global Variables
$dt=get-date -format "yyyyMMdd-HHmm"
$workingpath = "c:\scripts\ChangeDR\"
$logfile = "$($workingpath)logs\ChangeDR-$($dt).txt"

$market = ""
$task = ""
$currentDC=""
$currentVC=""
$seoulVC="vcsa01.hanaict.dom"

$clusters = @()
$username=""
$password=""
$ciphertext=""
$vmconfigFile = "$($workingpath)ChangeDR.csv"
$vmconfigs = @()
$isContinue = "Y"




# Common Functions
function CreateConfigFile {
    $username = Read-Host " User Name "
    $ciphertext = Read-Host " User Password " -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ciphertext))
    Write-Host
 
    LogHistory "Check the Resource Configuration File Existence"

    if (Test-Path $vmconfigFile)
    { 
        Log "Configfile Existed"
        Write-Host""
		Stop-Transcript
        exit
    }
    else
    { 
        Log "Create ConfigFile"
    
        $connect=ConnectVC $currentVC $username $password
    
        $vms=get-vm|select name,numcpu,memorygb,notes
        $lines=@()
        foreach($vm in $vms){
            #sp,HostName,ClusterName,Market,Type,DC,NormalCore,DRCore,NormalMemory,DRMemory,NormalNIC,DRNIC,Notes,ReservedRatio
            $data=""|select so,HostName,ClusterName,Market,Type,DC,NormalCore,DRCore,NormalMemory,DRMemory,ReservedRatio,Notes
            $data.so=3
            $data.HostName=$vm.name
            $data.ClusterName=get-cluster -vm $vm.name
            $data.Market="TR System"
            $data.Type="$(if($vm.name.chars(7) -eq "d"){"DR"} else {"TEST"})"
            $data.DC=get-datacenter -vm $vm.name
            $data.NormalCore=$vm.numcpu
            $data.DRCore=$vm.numcpu
            $data.NormalMemory=$vm.memorygb
            $data.DRMemory=$vm.memorygb
            $data.ReservedRatio=100
            $data.Notes=$vm.notes
            $lines += $data
        }

        $csvfile="$($workingpath)ChangeDR.csv"
        
        $lines | export-csv -path $csvfile
		Stop-Transcript
        exit
    }

    

}
function CheckVMwarePSSnapin()
{
    Write-Host
    
    Log "Check VMware PowerCLI Plugin"
    #get-module|where{$_.name -eq "VMware.VimAutomation.Core"}
    if ($(get-module|where{$_.name -eq "VMware.VimAutomation.Core"}).length -eq 0)
    {
        Log "VMware PowerCLI Module Not Found. Please Check VMware Powercli Modules"
		Stop-Transcript
        exit
    }
    else {
        Log "Import Module VMware PowerCLI Modules"
        Get-Module -Name VMware* -ListAvailable | Import-Module  -ErrorAction SilentlyContinue
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false | Out-Null            
    }
}

function ConnectVC($pvcaddress, $pusername, $ppassword)
{
    if (($pusername -eq "") -and ($ppassword -eq ""))
    {
        if (Connect-VIServer -Server $pvcaddress -Protocol https -ErrorAction SilentlyContinue)
        {
            return 0
        }
        else
        {
            return -1
        }
    }
    else
    {
        if (Connect-VIServer -Server $pvcaddress -User $pusername -Password $ppassword -Protocol https -ErrorAction SilentlyContinue)
        {
            return 0
        }
        else
        {
            return -1
        }
    }
}

function DisconnectVC($pvcaddress)
{
    Disconnect-VIServer -Server $pvcaddress -Force:$true -Confirm:$false
}

function Log($pmessage)
{
    Write-Host "  ... $pmessage" -ForegroundColor Gray
}

function LogHistory($pmessage, $ptype)
{
    $time = Get-Date
    
    switch ($ptype)
    {
        # ERROR
        -1 { Write-Host " [$time]" -NoNewLine; Write-Host " $pmessage" -ForegroundColor Red; }
        
        # SUCCESS
        0  { Write-Host " [$time]" -NoNewLine; Write-Host " $pmessage" -ForegroundColor Green; }

        # WARNING
        1  { Write-Host " [$time]" -NoNewLine; Write-Host " $pmessage" -ForegroundColor Yellow; }

        # NoNewLine
        9  { Write-Host " [$time]" -NoNewLine; Write-Host " $pmessage" -NoNewLine; }
                
        # NORMAL
        default { Write-Host " [$time] $pmessage" }
    }
}

function ShutdownVM($pcluster, $pcfg)
{
	$vms=$pcfg|where{$_.ClusterName -eq $pcluster}
    Foreach($vmname In $vms.HostName)
    {
        $message = ""
        $vm = get-vm $vmname
        if ($vm.PowerState -eq "PoweredOn")
        {
            #$vmView = $vm | Get-View -Property Guest.ToolsRunningStatus
            #if ($vmView.Guest.ToolsRunningStatus -eq "guestToolsRunning")

            if ($vm.Guest.State -eq "Running")
            {
                $message = " >> Try to Shutdown " + $vm.Name + " [" + $vm.Notes + "]"
                LogHistory $message 

                ###Shutdown-VMGuest -VM $vm -Confirm:$false -ErrorAction SilentlyContinue | Out-Null                
            }
            else
            {
                $message = " >> Try to Power Off " + $vm.Name + " [" + $vm.Notes + "]"
                LogHistory $message 
                            
                ###Stop-VM -VM $vm -Confirm:$false -RunAsync -ErrorAction SilentlyContinue | Out-Null
            }
        }
        else
        {
            $message = " >> " + $vm.Name + " [" + $vm.Notes + "] is Already Powered Off"
            LogHistory $message 
        }
    }

    return 0
}

function WaitToShutdownVM($pcluster, $maxwatiseconds, $pcfg)
{
    LogHistory ("Waiting for " + $maxwatiseconds + " Seconds Until all Virtual Machine is Powered Off")
    LogHistory " >> " 9

    $waitcnt = 1
    $needPowerOff = $false

	$vms=$pcfg|where{$_.ClusterName -eq $pcluster}

	while (1)
    {
		$pcnt=0
		Foreach($vmname In $vms.HostName)
		{
			if((get-vm $vmname).powerstate -eq "PoweredOn"){$pcnt+=1}
		}
		if($pcnt -eq 0) {break}
        Start-Sleep 1
        Write-Host "." -NoNewLine -ForeGroundColor Gray
        $waitcnt += 1    
        
        if ($waitcnt -gt $maxwatiseconds)
        {
            $needPowerOff = $true
            break
        }
    }
    Write-Host

   if ($needPowerOff)
    {
        #Foreach ($vm In (Get-VM -Location $pcluster | Where-Object { $_.PowerState -ne "PoweredOff" } | Sort-Object -Property Name))
		Foreach($vmname In $vms.HostName)
        {   
			$vm = get-vm $vmname
            # Check VM is still PowerOn
            if ($vm.PowerState -ne "PowerOff")
            {
                $message = " >> Try to Power Off " + $vm.Name + " [" + $vm.Notes + "]"
                LogHistory $message 
###                Stop-VM -VM $vm -Confirm:$false -RunAsync -ErrorAction SilentlyContinue | Out-Null    
            }        
        }
		LogHistory ("One more Waiting for " + $maxwatiseconds/2 + " Seconds Until all Virtual Machine is Powered Off")
		LogHistory " >> " 9
		
		$waitcnt = 1
		while (1)
		{
			$pcnt=0
			Foreach($vmname In $vms.HostName)
			{
				if((get-vm $vmname).powerstate -eq "PoweredOn"){$pcnt+=1}
			}
			if($pcnt -eq 0) {break}
			Start-Sleep 1
			Write-Host "." -NoNewLine -ForeGroundColor Gray
			$waitcnt += 1    
			
			if ($waitcnt -gt $maxwatiseconds/2)
			{
				Write-Host
                $message = " >> Try to VM Power Off Error "
                LogHistory $message
				Stop-Transcript
				exit
			}
		}

    }

    return 0
}

function ReadResouceConfigFile_cluster($pconfigfile, $pcluster)
{
    $vmconfigs = @()
    
    Foreach($vmconfig In (Import-CSV $pconfigfile))
    {
        if ($vmconfig.ClusterName -eq $pcluster)
        {
            $vmconfigs += $vmconfig
        }
    }

    return ($vmconfigs | Sort-Object)
}

function ReadResouceConfigFile($pconfigfile)
{
    $vmconfigs = Import-CSV $pconfigfile
    return ($vmconfigs | Sort-Object)
}


function ChangeResouce($pvmconfigs, $ptasktype)
{        
    # ptasktype 1:TEST->DR, 2:DR->TEST
    Foreach ($vmconfig In ($pvmconfigs | Sort-Object -Property Type,HostName))
    {   
        $currentSocket = 0
        $currentCorePerCPU = 0
        $currentMemoryGB = 0    
        $desiredSocket  = 0
        $desiredCorePerCPU = 0
        $desiredMemoryGB = 0
        $reservedRatio = 0
        $reservedMemoryGB = 0
        $istarget = $false
    
        if ($ptasktype -eq 1)
        {
            # Normal 2 DR
            if (($vmconfig.DRCore % 2) -eq 0)
            {
                $desiredSocket = 2
                $desiredCorePerCPU = ($vmconfig.DRCore / 2)
            }
            else
            {
                $desiredSocket = 1
                $desiredCorePerCPU = $vmconfig.DRCore
            }

            $desiredMemoryGB = $vmconfig.DRMemory
            
            $reservedRatio = $vmconfig.ReservedRatio
           
            if ($vmconfig.Type -eq "DR")
            {
                $istarget = $true
            }
        }
        else
        {
            # DR 2 Normal
            if (($vmconfig.NormalCore % 2) -eq 0)
            {
                $desiredSocket = 2
                $desiredCorePerCPU = ($vmconfig.NormalCore / 2)
            }
            else
            {
                $desiredSocket = 1
                $desiredCorePerCPU = $vmconfig.NormalCore
            }

            $desiredMemoryGB = $vmconfig.NormalMemory
            
            $reservedRatio = $vmconfig.ReservedRatio

            $istarget = $true
        }

        
        if ($istarget)
        {
            $vm = Get-VM -Name $vmconfig.HostName -Location $vmconfig.ClusterName 
            #$vmView = $vm | Get-View -Property Config.Hardware.NumCoresPerSocket
            $vmView = $vm | Get-View -Property Config.Hardware
            
            $currentSocket = $vmView.Config.Hardware.NumCPU
            $currentCorePerCPU= $vmView.Config.Hardware.NumCoresPerSocket
            $currentMemoryGB = $vm.MemoryGB
            $reservedMemoryGB = [Math]::Floor([decimal]($desiredMemoryGB /100 * $reservedRatio))

            $message = " >> Change " + $vm.Name + " [" + $vm.Notes + "] CPU " + ($currentSocket * $currentCorePerCPU) + "C -> " + ($desiredSocket * $desiredCorePerCPU) + "C, Memory " + $currentMemoryGB + "GB -> " + $desiredMemoryGB + "GB/" + $reservedMemoryGB + "GB"
            LogHistory $message 1
            
            if ((($currentSocket * $currentCorePerCPU) -ne ($desiredSocket * $desiredCorePerCPU)) -or ($currentMemoryGB -ne $desiredMemoryGB))
            {
                $vmconfigspec = New-Object -Type VMware.Vim.VirtualMachineConfigSpec -Property @{"NumCoresPerSocket" = $desiredCorePerCPU}
                Set-VM -VM $vm -NumCpu ($desiredSocket * $desiredCorePerCPU) -MemoryGB $desiredMemoryGB -Confirm:$false | Out-Null
                $vm.ExtensionData.ReconfigVM_Task($vmconfigspec) | Out-Null

                if ($desiredMemoryGB -ne $currentMemoryGB)
                {
                    $vm | Get-VMResourceConfiguration | Set-VMResourceConfiguration -MemReservationGB $reservedMemoryGB | Out-Null
                }
            }
           
             $message = " >> Try to Power On " + $vm.Name + " [" + $vm.Notes + "]"
             Start-VM -VM $vm -RunAsync | Out-Null
        }
    }
}

##########################################################################################
##########################################################################################
###############################    Main Start    #########################################
##########################################################################################
##########################################################################################

## import module powercli
CheckVMwarePSSnapin

## log satart
Start-Transcript -path $logfile

## 
while (($isContinue -eq "Y") -or ($isContinue -eq "y"))
{
    Clear-Host

########### TR 시스템 구분
    Write-Host " "("=" * 100) -ForegroundColor DarkGray
    Write-Host (" "*27)"Change DR-2-TEST or TEST-2-DR" -ForegroundColor Yellow
    Write-Host " "("=" * 100) -ForegroundColor DarkGray
    Write-Host
    Write-Host " [A] TR시스템 DR `t<->`t 내부테스트"
    Write-Host " [Q] QUIT"
    Write-Host
    $market = Read-Host " Select Menu [A-Q] "
    Write-Host

    switch -RegEx ($market)
    {
        # 서울 센터 - TR 시스템 DR - 테스트
        "[a|A]" { 
            $currentDC = "Seoul DRC"
            $currentVC = $seoulVC
            #$clusters = "S-SV-PKF-RI"
            #$clusters = get-cluster 
        }
       
        "[c|C]" { 
            $currentDC = "Seoul DRC"
            $currentVC = $seoulVC
            #$clusters = "S-SV-PKF-RI"
            #$clusters = get-cluster 
            CreateConfigFile
            Stop-Transcript
            exit
        }

        "[q|Q]" {
            Write-Host
            Stop-Transcript
            return
        }

        default{
            Write-Host " You must select market ID in [A-Q]. Process is terminated." -ForegroundColor Red
            Write-Host
            return
        } 
    }


########## DR -> TEST or TEST -> DR 선택
    Write-Host " [1] DR 전환 (평상 시 -> DR)" -ForegroundColor Yellow
    Write-Host " [2] DR 복구 (DR   -> 평상 시)" -ForegroundColor Yellow
    Write-Host " [Q] QUIT"	
    Write-Host
    $task = Read-Host " Select Task Type [1-2,Q] "
    Write-Host

    switch -RegEx ($task)
    {
        "[1|2]" { }

        "[q|Q]" {
            Write-Host
            Stop-Transcript
            return
        }
        
        default{
            Write-Host " You must select task ID in [1-2]. Process is terminated." -ForegroundColor Red
            Write-Host
            return
        } 
    }

###### vcenter 계정/PW 입력
    $username = Read-Host " User Name "
    $ciphertext = Read-Host " User Password " -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ciphertext))
    Write-Host
    


    #Clear-Host
    Write-Host " "("=" * 100) -ForegroundColor DarkGray
    Write-Host (" "*27)"Change DR-2-TEST or TEST-2-DR - Task History " -ForegroundColor Yellow
    Write-Host " "("=" * 100) -ForegroundColor DarkGray
    Write-Host

    $starttime = Get-Date
    $endtime = $null
    $step1time = $null
    $step2time = $null
    $step3time = $null

    # Step-1 Read Configuration File
    LogHistory "Check the Resource Configuration File Existence"

	$logmessage = "Step-1 Read Configuration File Start "
    LogHistory $logmessage	

    if (Test-Path $vmconfigFile)
    { 
        Write-Host
        $vmconfigs = ReadResouceConfigFile $vmconfigFile
		
        LogHistory "Success" 0 
        Write-Host""
    }
    else
    { 
        LogHistory "Fail - File Not Found" -1
        Write-Host""
        return
    }

    LogHistory "Connect the $currentDC vCenter Server"

    If (0 -eq (ConnectVC $currentVC $username $password))
    { 
        LogHistory "Success" 0 
        Write-Host""
    }
    else
    { 
        LogHistory "Fail" -1
        Write-Host""
        return
    }
#	connect-viserver -server vcsa01.hanaict.dom -user administrator@vsphere.local -password VMware1!
	
	$clusters = get-cluster 
    $step1time = Get-Date


    # Step-2 Shutdown VM
	$logmessage = "Step-2 Shutdown VM Start "
    LogHistory $logmessage	
 
    for ($i=0; $i -lt $clusters.Length; $i++)
    {
        $logmessage = "Shutdown Virtual Machine "
        LogHistory $logmessage

        if (0 -eq (ShutdownVM $clusters[$i] $vmconfigs))
        {
            LogHistory "Success" 0 
            Write-Host""
        }
        else
        {
            LogHistory "Fail" -1
            Write-Host""
            return
        }
    }

    for ($i=0; $i -lt $clusters.Length; $i++)
    {
        $logmessage = "Wait to shutting-down Virtual Machine " + $clusters[$i].name
        LogHistory $logmessage	

        if (0 -eq (WaitToShutdownVM $clusters[$i].name 10 $vmconfigs))
        {
            LogHistory "Success" 0 
            Write-Host""
        }
        else
        {
            LogHistory "Fail" -1
            Write-Host""
            return
        }
    }
        
    $step2time = Get-Date

 
    # Step-3 Change Resource
	$logmessage = "Step-3 Change Resource Start "
    LogHistory $logmessage	

    if ($task -eq 1)
    {
        #LogHistory "Change the Resource Configuration for DR"
        LogHistory "Change the Resource Configuration for DR and PowerOn"
    }
    else
    {
        #LogHistory "Change the notpResource Configuration for Non-DR"
        LogHistory "Change the Resource Configuration for Non-DR and PowerOn"
    }

    ChangeResouce $vmconfigs $task
    LogHistory "Success" 0 
    Write-Host

    $step3time = Get-Date




    # Step-5 Disconnect vCenter Server
    LogHistory "Disconnect the $currentDC vCenter Server"
    DisconnectVC $currentVC
    LogHistory "Success" 0 
    Write-Host""

    $endtime = Get-Date


    # Report
    Write-Host""
    Write-Host " Start   Time : " $starttime
    Write-Host " End     Time : " $endtime

    $runtime = $endtime - $starttime
    $runtimestr = [string]::format("{0} 시간 {1} 분 {2}.{3} 초", $runtime.Hours, $runtime.Minutes, $runtime.Seconds, $runtime.Milliseconds)
    Write-Host " Elapsed Time :  " -NoNewLine
    Write-Host $runtimestr -ForegroundColor Yellow

    $runtime = $step1time - $starttime
    $runtimestr = [string]::format("{0} 시간 {1} 분 {2}.{3} 초", $runtime.Hours, $runtime.Minutes, $runtime.Seconds, $runtime.Milliseconds)
    Write-Host "   Step-1 (Connect vCenter Server) Elapsed Time :  " -NoNewLine
    Write-Host $runtimestr -ForegroundColor Yellow

    $runtime = $step2time - $starttime
    $runtimestr = [string]::format("{0} 시간 {1} 분 {2}.{3} 초", $runtime.Hours, $runtime.Minutes, $runtime.Seconds, $runtime.Milliseconds)
    Write-Host "   Step-2 (Shutdown Target VM) Elapsed Time :  " -NoNewLine
    Write-Host $runtimestr -ForegroundColor Yellow

    $runtime = $step3time - $starttime
    $runtimestr = [string]::format("{0} 시간 {1} 분 {2}.{3} 초", $runtime.Hours, $runtime.Minutes, $runtime.Seconds, $runtime.Milliseconds)
    Write-Host "   Step-3 (Change Resouce Configuration and Power On) Elapsed Time :  " -NoNewLine
    Write-Host $runtimestr -ForegroundColor Yellow

    Write-Host
    
    $isContinue = Read-Host " Continue [Y|N] "
}

Stop-Transcript