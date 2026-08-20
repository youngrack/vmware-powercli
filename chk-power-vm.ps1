##############################################
#
# 목록의 vm의 전원 상태 확인 출력
# yrson / 2026.08.20
#
##############################################

param (
    [switch]$cred,
	[parameter(ValueFromRemainingArguments = $true)]
    $IgnoredArguments
)


### vcenter 주소

$vcsrv="vcenter-ip"

### vm 목록 파일
# c:\temp\vmlist.csv
# vmname
# vm1   <<<< vm이름
# vm2   <<<< vm이름

$vmlists="c:\temp\vmlist.csv"

$CredPath = "C:\temp\credentials"

if (!(Test-Path $CredPath)) {
	New-Item -ItemType Directory -Path $CredPath -Force | Out-Null
}
$CredFile="$CredPath\vcenter_cred.xml"

# vcenter 사용자 credential 파일 생성
function vc_setcred(){
	$Credential = Get-Credential
	$Credential | Export-Clixml -Path $CredFile
	exit 0
}

####Main####
#스크립트 
if ($cred) {
    vc_setcred
    exit
}

if (!(Test-Path $vmlists)) {
	write-host "check vmlist.csv file not found!!!"
	exit 1
}
else {
	# vm 목록 import
	$checkvms = (import-csv $vmlists).vmname
	

	# 파일 존재 여부 확인
	if (Test-Path $CredFile) {
		$Credential = Import-Clixml -Path $CredFile

		try {
			# vCenter 접속
			$ret_conn=Connect-VIServer -Server $vcsrv -Credential $Credential -ErrorAction Stop

			# VM 목록 가져오기
			$result_vm=Get-VM
			
			$result_vmon=$result_vm | Where-Object {$_.PowerState -eq "PoweredOn"}
			$result_vmoff=$result_vm | Where-Object {$_.PowerState -eq "PoweredOff"}
			
			#$result_vm
			$ret1=$result_vmoff | Where-Object {$_.name -in $checkvms}
			Write-Host "--vm off lists---"
			$ret1
			Write-Host "-----"
			Write-Host ""
			Write-Host ""
			$ret1=$result_vmon | Where-Object {$_.name -in $checkvms}
			Write-Host "--vm on lists---"
			$ret1
			Write-Host "----- "
			
		}
		catch {
			Write-host "vCenter 접속 실패: VC-ip / 자격증명 확인!!! "
			exit
		}
		finally {
			# 작업 완료 후 세션 종료
			if($ret_conn){
				$ret_conn=Disconnect-VIServer -Server * -Confirm:$false
			}
		}
	}
	else {
		Write-Error "자격 증명 파일이 존재하지 않습니다: $CredFile"
		#vc_setcred
	}
}
