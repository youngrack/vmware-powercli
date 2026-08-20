# drsite vmware

vmware 인프라 환경에서 powercli 를 이용하여 자동화 스크립트를 작성하였습니다.

Windows/Linux 실행 가능

# 리눅스 서버 powercli 설치

##### 리눅스서버에서 vmware powercli 사용하기 

## 1.1 powershell 설치

### 1.1.1 redhat계열 다운로드 및 설치
https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-1.cm.x86_64.rpm

sudo dnf install https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-1.rh.x86_64.rpm


## 1.2 vmware powercli-module 다운로드 및 설치

cd powercli-module
unzip VMware-PowerCLI-13.3.0-24145081.zip

mkdir -p /usr/local/share/powershell/Modules/

cp -rp VMware.* /usr/local/share/powershell/Modules


# 실행 방법

1. module 디렉토리의 dr-env.ps1 파일을 수정
- vSphere 접속 환경 설정(ip,계정,pw)

2. conf 디렉토리의 DR관련 정보 파일 수정
- dr-ds-info1.csv -> DR 데이터스토어 정보
- dr-vm-info1.csv -> DR VM 정보
* 파일 내용(예)

$ cat dr-ds-info1.csv
"HostName","dsname"
"n-esx1.vtstire.com","iscsi-cl1"

$ cat dr-vm-info1.csv
"HostName","vmname"
"n-esx1.vtstire.com","vm1"

3. 스크립트 실행
- module 디렉토리의 스크립트 파일 실행

3.1 DR 시작시
- 1.dr-start-vmfs-mount.ps1 (DR용 데이터스토어 마운트)
- 2.dr-start-vm-migration.ps1 (DR용 VM 등록 및 시작)

3.2 DR 종료시
- K1.dr-stop-unregister-vm.ps1 (DR용 VM 종료 및 등록해지)
- K2.dr-stop-vmfs-unmount.ps1 (DR용 데이터스토어 마운트 해제)
