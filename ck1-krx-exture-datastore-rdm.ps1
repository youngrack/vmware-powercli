#connect-viserver -server 10.145.106.151 -user pkcmsmrt -password 3_tjddj@Q
#connect-viserver -server 10.146.106.151 -user pkcmsmrt -password 3_tjddj@Q




$DATEDIR=get-date -format "yyyy-MM-dd"
if ( -not (test-path $DATEDIR)){New-Item $DATEDIR -type Directory|Out-Null}


$dst="as-is"

#$LOGadapter="$($DATEDIR)\host-adapter-info-$($DATEDIR)-$($dst).txt"
# #$LOGhostnmp="$($DATEDIR)\host-nmp-path-info-$($DATEDIR)-$($dst).txt"

$LOG1="$($DATEDIR)\datastore-naa-$($DATEDIR)-$($dst).txt"
$LOG2="$($DATEDIR)\vms-disk-info-$($DATEDIR)-$($dst).txt"
#$LOG3="$($DATEDIR)\datastore-naa-$($DATEDIR)-$($dst).txt"
#$LOG4="$($DATEDIR)\datastore-naa-$($DATEDIR)-$($dst).txt"

#if (test-path $LOGadapter){remove-Item -path $LOGadapter}

if (test-path $LOG1){remove-Item -path $LOG1}
if (test-path $LOG2){remove-Item -path $LOG2}
#if (test-path $LOG3){remove-Item -path $LOG3}
#if (test-path $LOG4){remove-Item -path $LOG4}

###############################################################
####호스트별 adapter, ww, device count, path count

#$esx=get-vmhost 10.145.106.41

#$lists=@()

#foreach($esx in (get-vmhost)){

#	$esxcli=get-esxcli -vmhost $esx
#	$hostnmppath=$esxcli.storage.nmp.path.list()|select device,RuntimeName,PathSelectionPolicyPathConfig|sort	
#	$LOGhostnmp="$($DATEDIR)\host-nmp-path-info-$esx-$($DATEDIR)-$($dst).txt"
#	if (test-path $LOGhostnmp){remove-Item -path $LOGhostnmp}
#	add-content $LOGhostnmp $hostnmppath

#	foreach($hba in (get-vmhosthba -vmhost $esx -type "FibreChannel")){
#		$target=((get-view $hba.vmhost).config.storagedevice.scsitopology.adapter|where {$_.adapter -eq $hba.key}).target
#		$luns=get-scsilun -hba $hba -luntype "disk" -erroraction silentlycontinue
#		$nrpaths=($target|%{$_.lun.count}|measure-object -sum).sum
#
#	
#		$hbalist=""|select esxname,hbaname,wwn,target,lunscount,nrpaths
#		$hbalist.esxname=$esx.name
#		$hbalist.hbaname=$hba.name
#		$hbalist.wwn="{0:X}" -f $hba.portworldwidename
#		$hbalist.target=$target.count
#		$hbalist.lunscount=($luns|Measure-Object).count
#		$hbalist.nrpaths=$nrpaths
#		$lists+=$hbalist
#	}
#}
# #$lists|format-table
#add-content $LOGadapter $lists

######################################
### LOG1
$dss=get-datastore|where {$_.type -eq "VMFS"}|sort
foreach($ds in $dss){
	$dsnaa2=$ds.extensiondata.info.vmfs.extent[0].diskname
	$dsnaa1=$ds.name
	$dsnaa="$dsnaa1,$dsnaa2"
add-content $LOG1 $dsnaa
#$dsnaa

}
####################################################################
## LOG2
$vmhosts=get-vmhost
#$vmhosts="10.145.106.11"

$lists=@()
foreach($vmhost in $vmhosts){
	$cl=get-vmhost $vmhost
	$cluname=$cl.Parent

	$vmlist=get-vm -location $vmhost
	
	foreach($vm in $vmlist)
		{
		$vmview=get-view -viewtype virtualmachine -filter @{"Name" = $vm.name}
		foreach($virtualscsicontroller in ($vmview.config.hardware.device|where {$_.deviceinfo.label -match "SCSI"}))
			{
			foreach($virtualdiskdevice in  ($vmview.config.hardware.device|where {$_.controllerkey -eq $virtualscsicontroller.key}))
				{
				$virtualdisk=""|select vm,vmhost,vmcluster,vmfolder,scsicontroller,diskname,scsi_id,diskfile,lunuuid,disksize
				$virtualdisk.vm=$vm
				$virtualdisk.vmhost=$vm.vmhost
				$virtualdisk.vmcluster=$cluname
				$virtualdisk.vmfolder=$vm.folder.name
				$virtualdisk.scsicontroller=$virtualscsicontroller.deviceinfo.label
				$virtualdisk.diskname=$virtualdiskdevice.deviceinfo.label
				$virtualdisk.scsi_id="$($virtualscsicontroller.busnumber),$($virtualdiskdevice.unitnumber)"
				$virtualdisk.diskfile=$virtualdiskdevice.backing.filename
				$virtualdisk.lunuuid=$virtualdiskdevice.backing.lunuuid
				$virtualdisk.disksize=$virtualdiskdevice.capacityInKB * 1KB / 1GB
				#$virtualdisk
				#add-content $LOG2 $virtualdisk
				$lists+=$virtualdisk
				}
			}
		}
	}
add-content $LOG2 $lists
