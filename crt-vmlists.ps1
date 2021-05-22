#! /usr/bin/pwsh
### vmlists.csv

#vmname,vmhost1,vcpu,vmem,size,netpg1,netpg2,datastore1,datastore2
#test5,esxi247.hanaict.local,2,4,40,int-vlan3-192.168.3.x,int-vlan3-192.168.3.x,iscsi-Datastore,iscsi-Datastore
#test6,esxi247.hanaict.local,2,4,40,int-vlan3-192.168.3.x,int-vlan3-192.168.3.x,iscsi-Datastore,iscsi-Datastore

Connect-VIServer -Server 192.168.2.11 -user administrator@vsphere.local -pass VMware1!

$vmlists=import-csv vmlists.csv
foreach ($vm in $vmlists)
{
        $vmname = $vm.vmname
        $vmhost1 = $vm.vmhost1
        $vcpu = $vm.vcpu
        $vmem = $vm.vmem
        $disksize = $vm.size
        $netpg1 = $vm.netpg1
        $netpg2 = $vm.netpg2
        $datastore1=$vm.datastore1
        $datastore2=$vm.datastore1

        new-vm -Name $vmname -VMHost $vmhost1 -datastore $datastore1  -numcpu $vcpu -memorygb $vmem -diskgb $disksize -networkname $netpg1 -cd -DiskStorageFormat thin -GuestId rhel8_64guest
        New-HardDisk -vm $vmname -CapacityGB $disksize -StorageFormat thin -datastore $datastore2

        $vm = Get-VM $vmname | New-HardDisk -CapacityGB 1 -StorageFormat EagerZeroedThick| New-ScsiController -Type ParaVirtual -BusSharingMode Physical
        $vm = Get-VM $vmname | New-HardDisk -CapacityGB 1 -StorageFormat EagerZeroedThick| New-ScsiController -Type ParaVirtual -BusSharingMode Physical
        $vm = Get-VM $vmname | New-HardDisk -CapacityGB 1 -StorageFormat EagerZeroedThick| New-ScsiController -Type ParaVirtual -BusSharingMode Physical

        New-NetworkAdapter -vm $vmname -networkname $netpg2
}
disconnect-viserver -server 192.168.2.11 -Confirm:$false
