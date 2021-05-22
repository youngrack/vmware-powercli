### reset-userpasswd.csv
#userid
#yrson

if (Test-Path -Path reset-user-passwd.csv){
    $defpass="GIIvdi1!"
    $users=Import-Csv c:\script\reset-userpasswd.csv
    foreach ($user in $users){
        write-host $user

        #[기본 암호 설정] 값 GIIvdi1!
        Set-ADAccountPassword -Identity $user.userid -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$defpass" -Force)
        
        #[암호 사용 기간 제한 없음] 값 체크 해제
        Set-ADAccountControl $user -PasswordNeverExpires $false
        
        #[다음 로그온 시 사용자가 반드시 암호를 변경해야 함] 값 체크
        Set-ADUser -Identity $user -ChangePasswordAtLogon $True
    }
}
else {
    Write-Host " reset-user.csv file not exist!! check"
}
