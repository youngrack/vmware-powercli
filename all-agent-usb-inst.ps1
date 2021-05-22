$vc="172.16.100.20"
$vcuser="administrator@gii.local"
$vcpass="GIIvdi1!"

Connect-VIServer -Server $vc -user $vcuser -password $vcpass -ErrorAction ignore


$vms=get-vm "giivdi-*"
$script='Get-ItemProperty "HKLM:\Software\VMware, Inc.\Installer\Features_HorizonAgent"|select USB'

foreach( $vm in $vms){
write-host $vm

#Copy-VMGuestFile -Source C:\script\inst.bat -Destination c:\temp -vm $vm -LocalToGuest -GuestUser ".\supportadmin" -GuestPassword "VMware1!"
#Copy-VMGuestFile -Source C:\temp\VMware-Horizon-Agent-x86_64-2012-8.1.0-17352461.exe -Destination c:\temp -vm $vm -LocalToGuest -GuestUser ".\supportadmin" -GuestPassword "VMware1!"
#Invoke-VMScript -vm $vm -guestuser ".\supportadmin" -guestpassword "VMware1!" -scripttext "c:\temp\inst.bat"
Invoke-VMScript -vm $vm -guestuser ".\supportadmin" -guestpassword "VMware1!" -scripttext $script
}
